## Purpose

承接设备/宠物异常事件（越界/离线/低电）从产生到用户感知的全链路：业务后端落库 + 极光推送 + App 列表展示与已读管理。前端不直接调 PeerApi 拿事件历史。

## ADDED Requirements

### Requirement: 系统通知列表页存在性与入口

系统 SHALL 提供一个独立的"系统通知列表页"，承接所有设备/宠物异常通知。该页 MUST 可从消息页"系统通知"卡片进入，且首页铃铛、我的页铃铛 SHALL 都能透出该入口（经消息页跳转）。

#### Scenario: 从消息页进入

WHEN 用户在消息页点击"系统通知"卡片
THEN App SHALL 跳转到系统通知列表页

#### Scenario: 从铃铛透出

WHEN 用户在首页或我的页点击铃铛
THEN App SHALL 跳转到消息页
AND 消息页 SHALL 显示"系统通知"卡片作为透出入口

### Requirement: 通知类型与展示

系统通知列表 SHALL 支持三类事件：越界告警（红色系）、设备离线（橙色系）、低电提醒（黄色系）。每条通知 MUST 包含：事件图标、事件类型、处理状态（未处理/已处理）、描述文字、关联宠物名、发生时间。

#### Scenario: 通知字段完整

WHEN 列表渲染任意一条通知
THEN 该条 SHALL 显示图标、类型名、状态标签、描述、宠物名、时间六项信息

#### Scenario: 类型色彩区分

WHEN 渲染越界告警
THEN 图标背景与状态标签 SHALL 使用红色系
AND 设备离线 SHALL 使用橙色系
AND 低电提醒 SHALL 使用黄色系

### Requirement: 日期分组与排序

通知列表 SHALL 按日期降序分组（今天/昨天/具体日期），组内按时间倒序排列，最新在前。

#### Scenario: 跨日分组

WHEN 存在今天、昨天、更早日期的通知
THEN 列表 SHALL 按"今天 → 昨天 → 具体日期"顺序分组
AND 每组内 SHALL 按时间倒序排列

### Requirement: 已读未读状态

每条通知 SHALL 有"未处理"或"已处理"状态。未处理通知 SHALL 有视觉标识（左侧橙色竖条 + 右上角圆点 + 暖色背景）。用户点击某条通知跳转设备详情页后，该条 SHALL 自动标记为已处理。

#### Scenario: 未处理视觉标识

WHEN 一条通知处于未处理状态
THEN 该行 SHALL 显示左侧橙色竖条、右上角橙色圆点、暖色背景

#### Scenario: 点击后标记已读

WHEN 用户点击一条未处理通知
THEN App SHALL 跳转到对应宠物的设备详情页
AND 该条通知 SHALL 被标记为已处理

### Requirement: 全部已读操作

页面顶部 SHALL 提供"全部已读"操作。当存在未处理通知时显示，全部已处理后隐藏。

#### Scenario: 有未读时显示

WHEN 存在任意未处理通知
THEN 顶部 SHALL 显示"全部已读"操作
WHEN 用户点击"全部已读"
THEN 所有未处理通知 SHALL 被标记为已处理
AND "全部已读"操作 SHALL 隐藏

### Requirement: 空状态

当无任何通知时，页面 SHALL 显示"一切正常"空状态，不展示空列表。

#### Scenario: 无通知

WHEN 用户进入页面且无任何通知记录
THEN 页面 SHALL 显示"🛡️ 一切正常"空状态而非空列表

### Requirement: 数据源分流

系统通知列表的历史数据 SHALL 来自业务后端接口，NOT 直接调 PeerApi。当前端未接通后端接口时，SHALL 以 mock 数据或空状态呈现，且不阻塞其他页面功能。

#### Scenario: 后端接口就绪

WHEN 业务后端设备事件查询接口可用
THEN App SHALL 通过该接口拉取分页历史
AND 支持按类型过滤、按日期分页

#### Scenario: 后端接口未就绪

WHEN 业务后端设备事件查询接口尚未就绪
THEN 系统通知列表页 SHALL 仍可访问
AND SHALL 显示空状态或 mock 占位
AND 其他页面功能 SHALL 不受影响

### Requirement: 实时推送触达

设备事件发生时，用户 SHALL 通过极光推送收到通知（不依赖 App 在前台）。推送 extras MUST 携带 `type` 与 `device_mac`，App 点击通知 SHALL 跳转到对应设备详情页。

#### Scenario: 锁屏收到推送

WHEN 设备事件发生且用户 App 不在前台
THEN 用户手机 SHALL 收到极光推送通知

#### Scenario: 点击推送跳转

WHEN 用户点击设备事件推送通知
THEN App SHALL 解析 extras 中的 `device_mac`
AND SHALL 跳转到对应设备详情页

### Requirement: 推送 type 扩展

`push_service.dart` 的通知跳转逻辑 SHALL 识别 `fence_alert`、`device_offline`、`low_battery` 三种 type。当 `device_mac` 存在时优先跳设备详情页。

#### Scenario: 带 device_mac 的设备事件

WHEN 推送 extras 含 `device_mac` 且非空
THEN App SHALL 跳转到该设备的详情页（无论 type 为何）

#### Scenario: 不走腾讯 IM

WHEN 设计或实现设备事件通知
THEN 事件通知 SHALL 不经腾讯 IM 通道
AND `message_page.dart` 中对 `fence_alert` 的 IM 解析 SHALL 被视为历史借用，不作为事件通知扩展依据
