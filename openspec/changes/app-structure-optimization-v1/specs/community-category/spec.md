## Purpose

社区页与发布动态页的分类联动，让社区页的分类标签筛选真正生效，并修正社交关系命名。

## ADDED Requirements

### Requirement: 社区页搜索框占位

社区页顶部 SHALL 新增搜索框占位，点击 SHALL 提示"搜索功能即将上线"。本轮 SHALL 不实现真实搜索。

#### Scenario: 搜索框占位显示

WHEN 社区页渲染
THEN 顶部 SHALL 显示搜索框占位

#### Scenario: 点击提示

WHEN 用户点击搜索框
THEN App SHALL 提示"搜索功能即将上线"
AND SHALL 不进入真实搜索流程

### Requirement: Tab 改名

社区页 Tab "关注" SHALL 改名为"好友"，以准确反映双向好友关系。

#### Scenario: 好友 Tab

WHEN 社区页 Tab 渲染
THEN SHALL 显示"好友"而非"关注"

### Requirement: 发帖分类选项

发布动态页 SHALL 新增分类选项（猫/狗/其他），发帖时 SHALL 将所选分类作为 `category` 值传给后端。

#### Scenario: 分类选择

WHEN 用户在发布动态页发帖
THEN SHALL 能选择猫/狗/其他分类
AND 提交时 SHALL 传 `category` 值

### Requirement: 分类筛选联动

社区页分类标签筛选 SHALL 与发布动态页分类选项联动生效。帖子带分类数据后，社区页按分类过滤 SHALL 真正工作。两端 MUST 同步开发，单独上线任一端无效果。

#### Scenario: 联动生效

WHEN 发布动态页已上线分类选项且社区页已上线分类筛选
THEN 社区页点击某分类标签 SHALL 过滤出对应分类的帖子

#### Scenario: 单端上线无效

WHEN 仅发布动态页上线分类选项而社区页筛选未上线
THEN 社区页分类标签 SHALL 无法过滤
AND 反之亦然
