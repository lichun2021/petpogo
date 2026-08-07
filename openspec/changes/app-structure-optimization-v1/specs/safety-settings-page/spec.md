## Purpose

安全设置页的结构精简，移除未开发功能与场景切换，聚焦电子围栏与警报通知两项核心设置。

## ADDED Requirements

### Requirement: 页面改名

页面标题 SHALL 由"安全场景设置"改为"安全设置"。

#### Scenario: 标题文案

WHEN 安全设置页渲染
THEN 顶部标题 SHALL 显示"安全设置"

### Requirement: 删除场景切换 Tab

居家/外出的场景切换 Tab SHALL 被整行删除，不再区分场景。

#### Scenario: 无场景 Tab

WHEN 安全设置页渲染
THEN SHALL 不显示"居家场景/外出场景"切换 Tab

### Requirement: 设置步骤精简

设置步骤 SHALL 仅保留"位置信息与电子围栏（+60分）"与"设置警报通知（+40分）"两项。"绑定宠物摄像头（即将上线）"条目 SHALL 被删除。

#### Scenario: 保留两项设置

WHEN 设置步骤渲染
THEN SHALL 显示"位置信息与电子围栏"与"设置警报通知"两项
AND SHALL 不显示"绑定宠物摄像头"

### Requirement: 删除 WiFi 安全提示

底部 WiFi 安全提示 SHALL 被整块删除（WiFi 热点定位功能尚未开发）。

#### Scenario: 无 WiFi 提示

WHEN 安全设置页渲染
THEN SHALL 不显示 WiFi 安全提示卡片

### Requirement: 安全评分卡保留

当前安全评分卡 SHALL 维持现状不动。

#### Scenario: 评分卡不变

WHEN 安全评分卡渲染
THEN 其结构与展示 SHALL 维持现状
