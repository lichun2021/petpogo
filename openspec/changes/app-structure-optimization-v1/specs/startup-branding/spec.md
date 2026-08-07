## Purpose

启动页品牌名与 Logo 的统一更换，将旧品牌名替换为"宠联芯"并同步更新视觉资源。

## ADDED Requirements

### Requirement: 品牌名更换

启动页品牌名 SHALL 由 `萌宠智伴` 改为 `宠联芯`。

#### Scenario: 品牌名显示

WHEN 启动页渲染品牌名
THEN SHALL 显示"宠联芯"
AND SHALL 不显示"萌宠智伴"

### Requirement: Logo 同步更换

Logo 图标 SHALL 与品牌名一起更换，不保留旧 Logo 进入过渡期。

#### Scenario: Logo 更新

WHEN 启动页渲染
THEN SHALL 显示新 Logo 资源
AND SHALL 不显示旧 Logo
