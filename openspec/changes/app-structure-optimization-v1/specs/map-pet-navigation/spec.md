## Purpose

地图定位页的寻宠导航功能，通过系统已安装的地图 App 将用户导航至宠物当前 GPS 位置。

## ADDED Requirements

### Requirement: 寻宠导航按钮

地图定位页底部操作区 SHALL 新增"🧭 寻宠导航"按钮，与"刷新定位"并列。

#### Scenario: 按钮存在

WHEN 地图定位页渲染且宠物位置已就绪
THEN 底部操作区 SHALL 显示"寻宠导航"按钮

### Requirement: 唤起系统地图 App

点击"寻宠导航"SHALL 通过 url_launcher 唤起系统已安装的地图 App，以宠物当前 GPS 位置为终点发起导航。优先级 SHALL 为：高德 → 百度 → Google Maps → 系统/Apple Maps，全部失败时 SHALL 提示"未找到地图 App"。

#### Scenario: 高德优先

WHEN 用户点击"寻宠导航"且设备已安装高德
THEN App SHALL 唤起高德 App 以宠物位置为终点导航

#### Scenario: 降级系统地图

WHEN 设备未安装高德、百度、Google Maps
THEN App SHALL 唤起系统/Apple Maps 以宠物位置为终点

#### Scenario: 无地图 App

WHEN 设备未安装任何支持的地图 App
THEN App SHALL 提示"未找到地图 App"
AND SHALL 不崩溃

### Requirement: 坐标系适配

唤起高德/百度 SHALL 使用 GCJ02 坐标，唤起 Apple Maps/Google Maps SHALL 使用 WGS84 坐标。两套坐标 MUST 都从现有数据获取，不新增反向转换。

#### Scenario: 高德用 GCJ02

WHEN 唤起高德 App
THEN 传入的终点坐标 SHALL 为 GCJ02 坐标系

#### Scenario: Apple Maps 用 WGS84

WHEN 唤起 Apple/Google Maps
THEN 传入的终点坐标 SHALL 为 WGS84 坐标系

### Requirement: 无定位时禁用

当宠物位置未就绪（无 GPS 坐标）时，"寻宠导航"按钮 SHALL 禁用或点击时提示无定位。

#### Scenario: 无定位禁用

WHEN 宠物位置未就绪
THEN "寻宠导航"按钮 SHALL 不可用
AND SHALL 提示用户等待定位
