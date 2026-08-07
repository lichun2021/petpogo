## Purpose

AI 功能（声音分析、图片分析、AI健康顾问）的积分消耗提示规范，让用户在入口处明示消耗。

## ADDED Requirements

### Requirement: 三处积分提示标注

系统 SHALL 在三处标注积分消耗提示：① 声音分析卡片标题末尾；② 图片分析卡片标题末尾；③ AI健康顾问选宠弹窗副标题末尾。提示格式 SHALL 为"（X积分/次）"或"（X积分/次提问）"。

#### Scenario: 声音分析标注

WHEN 首页 AI 解析区声音分析卡片标题渲染
THEN 标题末尾 SHALL 紧跟"（X积分/次）"提示

#### Scenario: 图片分析标注

WHEN 首页 AI 解析区图片分析卡片标题渲染
THEN 标题末尾 SHALL 紧跟"（X积分/次）"提示

#### Scenario: 健康顾问弹窗标注

WHEN AI健康顾问选宠弹窗副标题渲染
THEN 副标题末尾 SHALL 紧跟"（X积分/次提问）"提示

### Requirement: 积分值数据来源

积分值 X SHALL 由业务后端接口（ApiClient）返回，前端 SHALL NOT 写死。提示文案 SHALL 在 X 就绪后填充。

#### Scenario: X 由接口返回

WHEN 积分提示渲染
THEN X 值 SHALL 来自 ApiClient 接口返回
AND SHALL 不为前端硬编码常量

### Requirement: 提示样式

积分提示 SHALL 使用橙色（#FF9500）、11px 字号，紧跟功能标题文字末尾。

#### Scenario: 样式一致

WHEN 任意积分提示渲染
THEN 其字色 SHALL 为橙色 #FF9500
AND 字号 SHALL 为 11px

### Requirement: 结果页不显示积分

操作结果页 SHALL NOT 显示积分消耗（入口处已告知，结果页保持简洁）。积分不足提示由后台处理，前端无需额外开发。

#### Scenario: 结果页无积分

WHEN 用户完成一次 AI 分析后查看结果页
THEN 结果页 SHALL 不显示积分消耗提示
