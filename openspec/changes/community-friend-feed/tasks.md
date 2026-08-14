# Tasks: community-friend-feed

## 后端（业务后端 petpogo-server）

- [ ] 1.1 新增 `server/routes/sdkapi/post/feed/friends.post.ts`（参照 `feed.get.ts` 改为 POST）
- [ ] 1.2 从 body 读取 `friendIds` / `page` / `size` / `tag`
- [ ] 1.3 空 `friendIds` 短路：直接返回 `{ list: [], page, size }`，不查库
- [ ] 1.4 SQL：`user_id IN (friendIds)` + `deleted=0 AND status=1 AND visibility=1` + tag 可选过滤 + `created_at DESC` + LIMIT/OFFSET
- [ ] 1.5 复用 Redis 点赞/浏览计数后处理，响应结构与 GET /post/feed 对齐
- [ ] 1.6 确认走签名中间件（x-timestamp/x-signature/x-nonce）

## 前端 — 数据层

- [ ] 2.1 `post_repository.dart` 新增 `fetchFriendFeed({friendIds, page, size, tag})` → POST /sdkapi/post/feed/friends，复用 `PostModel.fromJson`
- [ ] 2.2 确认 `im_repository.fetchFriendList()` 返回可取 userID（已存在，验证字段）

## 前端 — 状态层

- [ ] 3.1 拆分 controller：新增 `friendFeedController`（独立分页/刷新状态），或改造为发现流/好友流两实例
- [ ] 3.2 好友流 controller 持有内存 friendIds，加载时用作请求参数
- [ ] 3.3 发现流 controller 保持不变（GET /feed）

## 前端 — 视图层

- [ ] 4.1 `community_page.dart` 两个 Tab 各 watch 各自 controller（不再共用）
- [ ] 4.2 进入"好友"Tab 首次：`fetchFriendList()` → 取 userID 组 friendIds → 追加自己 userId → 存内存 → 触发好友流加载
- [ ] 4.3 翻页复用内存 friendIds（不重复拉 IM）
- [ ] 4.4 好友为空（friendIds 仅含自己且返空）→ 显示引导文案，不显示加载失败
- [ ] 4.5 分类标签切换时好友流按 tag 重新请求（好友流也接 tag）
- [ ] 4.6 处理 IM 未登录完成时的加载态（等待就绪 / 重试，见 design Open Question）

## 联调与验证

- [ ] 5.1 后端接口就绪后前后端联调（好友流返回正确、分页连续、tag 生效、空好友返空）
- [ ] 5.2 验证自己的帖子在"好友"Tab 可见
- [ ] 5.3 验证"发现"Tab 行为未变
- [ ] 5.4 `flutter analyze` 通过
