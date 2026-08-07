## Purpose

全局措辞统一与文案修复，规避 AI 功能的过度承诺与医疗责任风险，修正单位错别与品牌名。

## ADDED Requirements

### Requirement: AI 文案情绪化表述

AI 功能文案 SHALL 统一为"情绪"表述：`听懂宠物语言` SHALL 改为 `听懂宠物的情绪`；`读懂宠物表情` SHALL 改为 `看懂宠物的情绪`。AI 角色名"宠小伊"SHALL 保留不变。

#### Scenario: 听懂宠物语言替换

WHEN 全局搜索 `听懂宠物语言`
THEN 所有出现 SHALL 被替换为 `听懂宠物的情绪`

#### Scenario: 读懂宠物表情替换

WHEN 全局搜索 `读懂宠物表情`
THEN 所有出现 SHALL 被替换为 `看懂宠物的情绪`

#### Scenario: 角色名保留

WHEN 文案替换完成
THEN "宠小伊"SHALL 保留使用，不受影响

### Requirement: 问诊改健康顾问

`宠物问诊` 与 `问诊` SHALL 改为 `AI健康顾问` 与 `健康顾问`，以避免医疗诊断措辞的责任风险。

#### Scenario: 问诊替换

WHEN 全局搜索 `宠物问诊` 或 `问诊`
THEN SHALL 被替换为 `AI健康顾问` 或 `健康顾问`

### Requirement: 签到单位修复

签到页连续签到奖励区块的 4 处单位错误 SHALL 修正：`+10周/+30周/+80周/+200周` SHALL 改为 `+10积分/+30积分/+80积分/+200积分`。

#### Scenario: 单位修复

WHEN 签到页连续签到奖励区块渲染
THEN 4 处奖励 SHALL 显示"积分"单位
AND SHALL 不显示"周"单位
