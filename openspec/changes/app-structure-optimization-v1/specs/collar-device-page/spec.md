## Purpose

当前项圈（设备详情）页的结构精简，下线依赖已砍硬件的功能，收敛设备信息展示。

## ADDED Requirements

### Requirement: 设备信息卡补全

设备信息卡 SHALL 显示设备名称、状态、电量、设备码四项，且设备码 MUST 有"设备码"文字标签。"10天前"等最后同步时间文案 SHALL 被移除。

#### Scenario: 电量显示

WHEN 设备信息卡渲染
THEN SHALL 显示电量百分比与电池图标

#### Scenario: 设备码标签

WHEN 设备信息卡渲染设备码
THEN 该项 SHALL 带"设备码"文字标签
AND SHALL 不显示无标签的裸设备码

#### Scenario: 去除同步时间

WHEN 设备信息卡渲染
THEN SHALL 不显示"10天前"等最后同步时间文案

### Requirement: 安全概览精简

今日安全概览 SHALL 仅保留"预警提醒"与"越界提醒"两个计数。"宠物行为活跃，安心守护"装饰文案与"实时动态"模块 SHALL 被移除。

#### Scenario: 保留两个计数

WHEN 安全概览渲染
THEN SHALL 显示"预警提醒"与"越界提醒"两个计数
AND SHALL 不显示"宠物行为活跃，安心守护"文案
AND SHALL 不显示"实时动态"模块

### Requirement: 安全场景改为安全设置入口

原"居家场景/外出场景"双卡片 SHALL 被替换为单一的"安全设置"入口，副标题为"设定安全范围，开启虚拟围栏警告"。点击 SHALL 跳转到安全设置页。

#### Scenario: 单入口替代双场景

WHEN 项圈页渲染安全场景区域
THEN SHALL 显示单一"安全设置"入口卡
AND SHALL 不显示"居家场景"与"外出场景"卡片

#### Scenario: 跳转安全设置

WHEN 用户点击"安全设置"入口
THEN App SHALL 跳转到安全设置页

### Requirement: 删除互动模块

互动模块（亮灯/响铃/查看位置/即时轨迹）SHALL 被整模块删除，不再呈现。

#### Scenario: 互动模块不渲染

WHEN 项圈页渲染
THEN SHALL 不显示亮灯、响铃、查看位置、即时轨迹任何入口

### Requirement: 删除安全设置模块

原设备详情页内的"安全设置"模块（历史轨迹/立即寻找）SHALL 被整模块删除。立即寻找由地图导航功能替代，历史轨迹本轮不保留。

#### Scenario: 安全设置模块不渲染

WHEN 项圈页渲染
THEN SHALL 不显示历史轨迹、立即寻找任何入口
