## Why

社区页有"好友 / 发现"两个 Tab，但当前两个 Tab 共用同一个 `feedController`，显示的内容完全一样——"好友"Tab 的过滤从未真正实现。

核心难点在于**数据源分离**：好友关系是腾讯 IM SDK 的（客户端 `getFriendList()` 可拿），而帖子内容在业务后端（`t_post`）。"好友动态流"本质上是 `帖子 ∩ 好友` 的交集，问题是这个交集在哪里计算。

客户端本地过滤（拉全站帖子再筛好友）在**分页**上不可行：好友帖子在全站占比稀疏，客户端过滤后一屏可能只剩 2 条，要凑满得偷偷翻几十页，流量和体验都会崩。因此过滤必须在后端做，但后端不知道谁是谁的好友。

## What Changes

**定调**：好友 = IM 好友，腾讯 IM 是好友关系的唯一真相源。业务后端不维护独立好友表（避免两份关系数据的一致性问题）。

**方案（B：请求携带好友列表）**：
- 客户端进入"好友"Tab 时，`getFriendList()` 拿到好友 `userId` 数组（IM SDK 本地缓存，含增量同步），追加当前用户自己的 id，作为参数传给后端。
- 后端用 `WHERE user_id IN (friendIds)` 分页过滤，返回结构与现有发现流一致。
- 后端保持无状态，不接腾讯 IM 服务端 SDK，不碰好友数据同步。

**接口层**：
- 新增 `POST /sdkapi/post/feed/friends`（好友流，好友 id 走 body）。
- 现有 `GET /sdkapi/post/feed`（发现流）保持不动。

**前端层**：
- 拆分 controller：发现流与好友流各自独立分页/刷新状态（当前是共用一个 controller）。
- 进入"好友"Tab 拿一次好友列表，翻页复用同一份。
- 好友为空时显示引导文案（"还没有好友，去发现页认识新朋友吧"）。
- 分类标签（猫/狗/其他）在好友流同样生效（后端接 `tag` 参数）。

**约束细节**：
- 好友 id 数组含调用者自己 → 用户能在"好友"Tab 看到自己发的帖子（符合朋友圈/关注流习惯）。
- 空 `friendIds` → 后端直接返空，禁止执行 `IN ()`（非法 SQL）。
- 好友规模预估 ≤ 100，`IN` 查询与 POST body 传参均无压力。

## Capabilities

### New Capabilities
- `community-friend-feed`: 社区"好友"Tab 的好友动态流——好友关系来自 IM SDK（客户端），内容过滤在业务后端（`user_id IN friendIds` 分页），含分类标签联动、空好友引导、自己帖子可见。

### Modified Capabilities
- 无（`community-category` 已归属另一 change，本 change 只新增好友流能力，不改发现流行为）。

## Impact

### 后端（业务后端 petpogo-server）
- 新增接口 `POST /sdkapi/post/feed/friends`（参照现有 `server/routes/sdkapi/post/feed.get.ts` 改写为 POST + `IN` 过滤 + 空数组短路）。
- 响应结构复用现有 feed（含 Redis 点赞/浏览计数后处理）。

### 前端（petpogo_app）
- `lib/features/community/controller/feed_controller.dart`：拆为发现流 / 好友流两套 controller（或一套带 tab 参数 + 独立分页状态）。
- `lib/features/community/data/post_repository.dart`：新增 `fetchFriendFeed({friendIds, page, size, tag})` 方法。
- `lib/features/community/community_page.dart`：两个 Tab 各 watch 各的 controller；进入好友 Tab 时经 IM 拿好友列表；空好友引导。
- 好友列表获取复用 `im_repository.dart` 的 `fetchFriendList()`（已存在，`contacts_page` 在用）。

### 不在本次范围
- 发现流（GET /post/feed）行为不变。
- 好友关系的其它用途（私信、加好友流程）不变。
- 好友数量超过 ~1000 的极端场景（本产品预估 ≤ 100，不做优化）。
