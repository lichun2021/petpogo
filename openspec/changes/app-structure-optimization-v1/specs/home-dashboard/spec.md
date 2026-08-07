## Purpose

首页整体结构与模块编排，呈现账号信息、宠物状态、签到、AI 解析与已连接设备，作为用户主入口仪表盘。

## ADDED Requirements

### Requirement: 账号展示位

首页顶部 SHALL 呈现账号展示位，包含头像+昵称、通知铃铛、在线设备数、积分四项独立热区，且 SHALL 不包含"你好"问候语。四个热区 MUST 互不重叠以避免误触。

#### Scenario: 四热区独立

WHEN 用户在首页顶部账号展示位
THEN SHALL 分别显示头像+昵称、🔔通知、在线设备数、积分四项
AND 每项 SHALL 各自独立可点击且热区互不重叠

#### Scenario: 去除问候语

WHEN 首页渲染账号展示位
THEN SHALL 不显示"你好，$displayName"问候语文案

#### Scenario: 热区跳转

WHEN 用户点击账号展示位的 🔔通知
THEN App SHALL 跳转到消息页
WHEN 用户点击在线设备数
THEN App SHALL 跳转到我的设备页
WHEN 用户点击积分
THEN App SHALL 跳转到积分明细页
WHEN 用户点击头像+昵称
THEN App SHALL 跳转到我的页

### Requirement: 首页铃铛入口

首页 SHALL 提供通知铃铛入口，点击 SHALL 跳转到消息页。该铃铛与我的页铃铛 SHALL 共享统一未读来源。

#### Scenario: 首页新增铃铛

WHEN 首页渲染
THEN 顶部 SHALL 显示铃铛图标
WHEN 用户点击首页铃铛
THEN App SHALL 跳转到消息页

### Requirement: 我的宠物区块

首页 SHALL 呈现"我的宠物"区块，以头像横滑形式展示用户的宠物，每张卡 MUST 显示头像+名字+纯文字状态（在线/离线/围栏内/越界/低电），且 SHALL 提供"添加"卡片。

#### Scenario: 横滑宠物卡

WHEN 用户在首页且已绑定至少一只宠物
THEN "我的宠物"区块 SHALL 以横向滑动形式展示宠物卡
AND 每张卡 SHALL 显示头像、名字、纯文字状态
AND 状态 SHALL 不使用图标角标

#### Scenario: 添加卡片

WHEN "我的宠物"区块渲染
THEN 末尾 SHALL 显示"+"添加卡片

#### Scenario: 点击宠物卡跳转

WHEN 用户点击某只宠物的卡片
THEN App SHALL 跳转到该宠物的设备详情页（优先项圈）

### Requirement: 宠物状态数据源

宠物状态中的在线/离线 SHALL 来自 `DeviceModel.isOnline`。围栏内/越界与低电 SHALL 来自 PeerApi 实时状态接口。当 PeerApi 接口未就绪时，围栏/低电状态 SHALL 显示占位（如"-"或"未知"），且 SHALL 不显示错误的"在围栏内"。

#### Scenario: 在线离线已就绪

WHEN 渲染宠物状态
THEN 在线/离线 SHALL 依据 `DeviceModel.isOnline` 显示

#### Scenario: 围栏低电接口未就绪

WHEN PeerApi 围栏状态或电量接口尚未就绪
THEN "我的宠物"区块的围栏/低电状态 SHALL 显示占位
AND SHALL 不显示与真实状态不符的信息

#### Scenario: 围栏低电接口就绪

WHEN PeerApi 围栏状态与电量接口就绪
THEN "我的宠物"区块 SHALL 接入并显示"围栏内/越界"与低电状态

### Requirement: 健康数据入口

"我的宠物"区块标题旁 SHALL 提供"健康数据 ›"入口。当健康报告页未就绪时，点击 SHALL 给出"即将上线"提示或预留跳转。

#### Scenario: 入口存在

WHEN "我的宠物"区块渲染
THEN 标题旁 SHALL 显示"健康数据 ›"入口

#### Scenario: 报告页未就绪

WHEN 健康报告页依赖的项圈行为分析模型未就绪
THEN 点击"健康数据 ›"SHALL 不导致崩溃
AND SHALL 给出"即将上线"类提示或预留跳转

### Requirement: 首页签到卡片

首页 SHALL 呈现签到卡片，显示"已连续签到 N 天"，点击 SHALL 跳转到签到页（`/check-in`）。签到卡片 SHALL 内嵌页面正常布局，非悬浮。

#### Scenario: 显示连续签到

WHEN 用户在首页
THEN SHALL 显示签到卡片，含"已连续签到 N 天"文案
WHEN 用户点击签到卡片
THEN App SHALL 跳转到签到页

### Requirement: AI 解析区结构

首页 SHALL 呈现 AI 解析区，含三张卡片：声音分析、图片分析、AI健康顾问。原 3 个重复快捷按钮（问诊/声音/图片）SHALL 被删除。

#### Scenario: 删除重复快捷按钮

WHEN 首页渲染
THEN SHALL 不显示与 AI 解析区重复的 3 个快捷按钮（问诊/声音/图片）

#### Scenario: AI 健康顾问卡片

WHEN AI 解析区渲染
THEN SHALL 包含第三张"AI健康顾问"卡片，含宠小伊 IP 形象与"问问宠小伊"按钮
AND 整卡 SHALL 可点击跳转到问诊页

#### Scenario: 卡片措辞

WHEN 渲染 AI 解析区卡片标题
THEN 声音分析 SHALL 显示"听懂宠物的情绪"
AND 图片分析 SHALL 显示"看懂宠物的情绪"
AND 健康顾问 SHALL 显示"AI健康顾问"（原"宠物问诊"）

### Requirement: 已连接设备区块保留

首页 SHALL 保留已连接设备区块，展示项圈/机器人卡片，位置与逻辑维持现状。

#### Scenario: 设备区块不变

WHEN 首页渲染已连接设备区块
THEN 其展示方式与跳转逻辑 SHALL 维持现状
