## Purpose

社区"好友"Tab 的好友动态流。好友关系来自腾讯 IM SDK（客户端 `getFriendList()`），帖子内容在业务后端。过滤在后端完成（`user_id IN friendIds` 分页），客户端负责提供好友列表。解决当前"好友"Tab 与"发现"Tab 内容相同、好友过滤未实现的问题。

## ADDED Requirements

### Requirement: 好友流接口

系统 SHALL 提供 `POST /sdkapi/post/feed/friends` 接口返回好友动态流。好友 `userId` 列表 SHALL 通过请求 body 传递（非 URL 参数）。接口 SHALL 走现有 /sdkapi 签名中间件（`x-timestamp` / `x-signature` / `x-nonce`）。

#### Scenario: 请求格式

WHEN 客户端请求好友流
THEN 请求方法 SHALL 为 POST
AND 请求 body SHALL 为 JSON：`{ friendIds: string[], page: int, size: int, tag?: string }`
AND `friendIds` SHALL 为好友 user_id 数组

#### Scenario: 响应结构与发现流一致

WHEN 好友流返回帖子列表
THEN 响应结构 SHALL 与 `GET /sdkapi/post/feed` 完全一致
AND 每条帖子 SHALL 含 id/content/media_type/media_urls/video_url/cover_url/duration/location/tag/like_count/comment_count/view_count/created_at/user_id/nickname/user_avatar
AND like_count/view_count SHALL 从 Redis 取实时计数
AND 顶层 SHALL 含 `page` 与 `size`

### Requirement: 好友过滤与排序

后端 SHALL 用 `WHERE user_id IN (friendIds)` 过滤帖子，并 SHALL 保留发现流相同的可见性过滤与排序。

#### Scenario: 过滤条件

WHEN 后端查询好友流
THEN SHALL 过滤 `deleted=0 AND status=1 AND visibility=1`
AND SHALL 增加 `user_id IN (friendIds)`
AND SHALL 按 `created_at DESC` 排序
AND SHALL 用 LIMIT/OFFSET 分页

#### Scenario: 分页正确性

WHEN 好友帖子在全站占比稀疏
THEN 每页 SHALL 返回最多 `size` 条好友帖子（不受非好友帖子干扰）
AND 翻页 SHALL 能连续取到更早的好友帖子

### Requirement: 空好友列表短路

当 `friendIds` 为空数组时，后端 SHALL 直接返回空列表，SHALL NOT 执行 `IN ()`（非法 SQL）。

#### Scenario: 无好友

WHEN 请求 body 的 `friendIds` 为 `[]`
THEN 后端 SHALL 直接返回 `{ list: [], page, size }`
AND SHALL NOT 查询数据库

#### Scenario: 前端空好友引导

WHEN 好友流返回空列表且用户无好友
THEN 客户端 SHALL 显示引导文案（如"还没有好友，去发现页认识新朋友吧"）
AND SHALL NOT 显示加载失败错误

### Requirement: 分类标签联动

好友流 SHALL 支持分类标签过滤。当请求带 `tag` 时，后端 SHALL 在好友过滤基础上叠加分类过滤。

#### Scenario: 带分类的好友流

WHEN 请求带 `tag` 为 `cat`/`dog`/`other`
THEN 后端 SHALL 在 `user_id IN (friendIds)` 基础上叠加 `AND tag = ?`

#### Scenario: 无效或缺失分类

WHEN 请求的 `tag` 不是 cat/dog/other，或未传
THEN 后端 SHALL 忽略分类过滤，返回该好友范围内全部分类的帖子

#### Scenario: 好友 Tab 内切换分类

WHEN 用户在"好友"Tab 切换分类标签
THEN 好友流 SHALL 按所选分类重新过滤

### Requirement: 好友列表来源与自身可见

客户端 SHALL 从腾讯 IM SDK `getFriendList()` 获取好友 userId，并 SHALL 将当前用户自己的 userId 追加进 `friendIds`。

#### Scenario: 好友列表来自 IM

WHEN 客户端进入"好友"Tab
THEN SHALL 通过 IM SDK 获取好友列表
AND SHALL 从好友信息中取 userId 组成 `friendIds`

#### Scenario: 自己的帖子可见

WHEN 构建 `friendIds`
THEN 客户端 SHALL 追加当前用户自己的 userId
AND 用户 SHALL 能在"好友"Tab 看到自己发布的帖子

#### Scenario: 翻页复用好友列表

WHEN 用户在"好友"Tab 翻页
THEN 客户端 SHALL 复用进入 Tab 时获取的同一份 `friendIds`
AND SHALL NOT 每次翻页都重新请求好友列表

### Requirement: 好友流与发现流独立

社区页"好友"Tab 与"发现"Tab SHALL 使用各自独立的分页与刷新状态。发现流行为 SHALL 保持不变。

#### Scenario: 两个 Tab 独立分页

WHEN 用户在两个 Tab 间切换
THEN 每个 Tab SHALL 保持各自的帖子列表、页码、刷新状态
AND SHALL NOT 共用同一份 feed 状态

#### Scenario: 发现流不变

WHEN 发现流（GET /sdkapi/post/feed）被调用
THEN 其请求方式、参数、行为 SHALL 与本 change 前一致
