## Purpose

我的页右上角铃铛的跳转修复，将"通知中心即将上线"占位弹框替换为直接跳转消息页。

## ADDED Requirements

### Requirement: 铃铛跳转消息页

我的页右上角铃铛点击 SHALL 直接跳转到消息页，SHALL NOT 弹出"通知中心即将上线"提示框。

#### Scenario: 点击跳转

WHEN 用户在我的页点击右上角铃铛
THEN App SHALL 跳转到消息页
AND SHALL 不显示"通知中心即将上线"弹框

### Requirement: 铃铛保留

铃铛入口 SHALL 保留（不删除），其核心价值是顶部角标提醒，移动端通知入口为行业标准。

#### Scenario: 铃铛存在

WHEN 我的页渲染
THEN 右上角 SHALL 显示铃铛图标
AND 铃铛 SHALL 保留未读角标能力
