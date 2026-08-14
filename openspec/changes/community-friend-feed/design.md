## Context

社区页两个 Tab（好友/发现）当前共用一个 `feedController`（`community_page.dart` 的 `_buildFeedGrid(_scrollCtrl0)` 和 `_buildFeedGrid(_scrollCtrl1)` watch 同一个 provider），内容完全相同。

数据源分离是核心约束：
- 好友关系 → 腾讯 IM SDK。客户端 `TencentImSDKPlugin.v2TIMManager.getFriendshipManager().getFriendList()` 返回 `List<V2TimFriendInfo>`，每个的 `userID` 即业务 user_id（merchantId，如 `44162677806080`）。`contacts_page.dart` 与 `im_repository.fetchFriendList()` 已在用。
- 帖子内容 → 业务后端 `t_post`。`GET /sdkapi/post/feed`（`feed.get.ts`）已实现发现流，含 tag 过滤 + Redis 计数后处理。
- Join key 一致：IM `userID` == `t_post.user_id` == `t_user.id`。

## Goals / Non-Goals

**Goals**
- "好友"Tab 只显示好友（含自己）的帖子，分页正确。
- 分类标签在好友流同样生效。
- 后端保持无状态，不接 IM 服务端 SDK。

**Non-Goals**
- 不在业务后端维护独立好友关系表（IM 是唯一真相源）。
- 不改发现流行为。
- 不优化好友数 > 1000 的极端场景（本产品 ≤ 100）。

## Decisions

### 决策 1：交集在后端算，好友列表由客户端 body 携带（方案 B）

客户端本地过滤（拉全站再筛）会因好友帖子稀疏而破坏分页体验，故过滤必须在后端。IM 是好友真相源、客户端能拿，于是把 friendIds 随请求带给后端，后端 `IN` 过滤。

**备选（已否决）**：
- *客户端过滤*：分页稀疏问题，一屏可能剩 2 条，翻几十页才凑满 → 否决。
- *后端反查腾讯 IM REST*：后端要接 IM 服务端 SDK、每次 feed 多一次腾讯调用、有频控 → 否决，破坏"后端不碰 IM"的边界。
- *后端同步好友关系表*：与"IM=唯一真相源"的定调冲突，引入双写一致性问题 → 否决。

### 决策 2：新开接口而非改造现有 feed

发现流 `GET /post/feed` 语义正确（可缓存、无副作用），好友流因带 body 用 POST。混在一个接口会把发现流也拖成 POST 并加 tab 分支。故新增 `POST /post/feed/friends`，发现流零改动。

### 决策 3：friendIds 含自己

参照朋友圈/关注流，用户应能在"好友"Tab 看到自己的帖子。客户端在 friendIds 里追加自己的 userId，后端无需特殊处理。

### 决策 4：翻页复用好友列表

进入 Tab 拿一次 friendIds 存内存，翻页复用。翻页途中新增好友的边缘情况可忽略（下次刷新生效），换取翻页零额外 IM 调用。

## 接口标准（交付后端）

### `POST /sdkapi/post/feed/friends`

**Header**
```
Authorization: Bearer <jwt>
x-timestamp / x-signature / x-nonce   （走现有签名中间件）
Content-Type: application/json
```

**Request Body**
```jsonc
{
  "friendIds": ["1215113377705000960", "44162677806080"],
                          // 好友 user_id 数组，含调用者自己；≤ ~100 个；空数组 [] 合法
  "page": 1,              // 页码，从 1 开始，默认 1
  "size": 20,             // 每页条数，默认 20，建议上限 50
  "tag": "dog"            // 可选：cat/dog/other，其余值或不传 = 全部
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| friendIds | string[] | 是 | 好友 user_id 数组，含自己；空数组合法 |
| page | int | 否 | 默认 1 |
| size | int | 否 | 默认 20，上限 50 |
| tag | string | 否 | cat/dog/other，其余当"全部" |

**Response（与 GET /post/feed 一致）**
```jsonc
{
  "list": [
    {
      "id": "16",
      "content": "清晨先喝口带着阳光味道的水…",
      "media_type": "image",
      "media_urls": ["https://.../a.jpg"],
      "video_url": null,
      "cover_url": null,
      "duration": null,
      "location": null,
      "tag": "dog",
      "like_count": 0,
      "comment_count": 0,
      "view_count": 0,
      "created_at": "2026-08-14 12:55:41",
      "user_id": "44162677806080",
      "nickname": "春哥",
      "user_avatar": "https://.../avatar.jpg"
    }
  ],
  "page": 1,
  "size": 20
}
```

**friendIds 为空**
```jsonc
{ "list": [], "page": 1, "size": 20 }
```

**查询逻辑（参照 feed.get.ts）**
```sql
-- friendIds 为空 → 直接 return { list: [], page, size }，不查库

SELECT p.id, p.content, p.media_type, p.media_urls, p.video_url, p.cover_url,
       p.duration, p.location, p.tag, p.like_count, p.comment_count,
       p.view_count, p.created_at, p.user_id,
       COALESCE(u.nickname, '宠友') AS nickname,
       u.avatar AS user_avatar
FROM t_post p
LEFT JOIN t_user u ON p.user_id = u.id
WHERE p.deleted = 0 AND p.status = 1 AND p.visibility = 1
  AND p.user_id IN (?, ?, ...)          -- friendIds 展开
  AND (? IS NULL OR p.tag = ?)           -- tag：cat/dog/other，空则不加
ORDER BY p.created_at DESC
LIMIT ? OFFSET ?
```
点赞/浏览计数从 Redis 取（与现有 feed 相同后处理）。

**后端约束清单**
```
1. 空 friendIds → 直接返回 { list: [] }，禁止 IN ()
2. tag 只认 cat/dog/other，其余忽略（返全部）
3. 响应结构与 GET /post/feed 完全一致（前端复用解析）
4. 排序 created_at DESC
5. 保留 deleted=0 / status=1 / visibility=1
6. friendIds 含调用者自己 → 自己帖子出现，符合预期
7. user_id IN 直接匹配，不做去重/特殊处理
```

## 前端改造

- `post_repository.dart`：新增 `fetchFriendFeed({List<String> friendIds, int page, int size, String? tag})` → POST /sdkapi/post/feed/friends，解析复用 PostModel.fromJson。
- `feed_controller.dart`：拆出 `friendFeedController`（独立分页/刷新状态），或改造为按 tab 参数区分的两实例。发现流 controller 保持 GET /feed。
- `community_page.dart`：
  - 两个 Tab 各 watch 各自 controller。
  - 进入"好友"Tab 首次：`im_repository.fetchFriendList()` → 取 userID 组 friendIds → 追加自己 userId → 存内存 → 触发 friendFeedController 加载。
  - 翻页复用内存中的 friendIds。
  - friendIds 仅含自己且返空 → 显示引导文案。
  - tag 切换时好友流按 tag 重新请求。

## Risks / Trade-offs

- [好友列表与后端过滤存在时间差] → 翻页途中新增好友本页不生效。缓解：下次进 Tab/下拉刷新时 friendIds 重新获取，可接受。
- [好友数逼近上限时 IN 列表变大] → ≤ 100 时 IN 查询与 body 传参均无压力；若未来远超预估，再评估分页游标或后端同步方案。
- [friendIds 由客户端提供，可被伪造] → 用户理论上可传任意 id 看到"非好友"帖子。但帖子本就是 visibility=1 的公开内容，好友流只是"视图过滤"而非"权限控制"，不构成越权。若未来有私密帖子，需服务端校验好友关系（届时才需后端接 IM）。

## Open Questions

- "好友"Tab 首次进入时若 IM 尚未登录完成（UserSig 未就绪），好友列表拉取会失败——是否需要等待 IM 登录态就绪再加载，还是显示重试。（前端实现细节，不影响接口契约，实现时确定。）
