# PetPogo 硬件接口对接参考文档

> 基于 `00_ShowDoc_宠物API完整文档.md` 整理  
> 更新时间：2026-04-23  
> 版本：V1.0

---

## 一、接入规则

| 项目 | 说明 |
|------|------|
| 网关前缀 | `/uclgwapp/` |
| 认证方式 | URL 参数拼接：`?access_token={token}` |
| 请求方式 | HTTP POST，Content-Type: application/json |
| 设备唯一标识 | `mac`（设备 IMEI 号，15位数字） |
| 公共参数 | `streamNo`（流水号）、`langType`（zh-CN / en-US）、`loginCustomerId`（用户ID） |

**通用响应格式**：
```json
{
  "code": 0,        // 0=成功，非0=失败
  "tip": "响应成功",
  "info": {},       // 单条数据（与 list 二选一）
  "list": []        // 列表数据
}
```

---

## 二、核心接口清单

### 2.1 设备信息聚合查询 ⭐⭐⭐ 最重要

**接口**：`POST /uclgwapp/pet/device/list`  
**用途**：首页设备卡片数据来源，一次请求返回：在线状态 + 位置 + 电量 + 围栏 + 宠物信息

**请求体**：
```json
{
  "loginCustomerId": "619eec5a91fe743dbb39ccbe",
  "streamNo": "APP2024032108043065401",
  "imeiList": ["353682680074836"],
  "scene": "ITEM",
  "queryPosition": "1",
  "queryPet": "1",
  "queryProperty": "1",
  "queryFence": "1",
  "lang": "zh-CN"
}
```

**响应结构**：
```json
{
  "code": 0,
  "info": [{
    "imei": "353682680074836",
    "onlineStatus": true,
    "connectStatus": true,
    "positionResponse": {
      "code": 0,
      "info": {
        "address": "广东省深圳市南山区高新南九道",
        "wsg84Latitude": "22.527556362302512",
        "wsg84Longitude": "113.9341350610332",
        "gcj02Latitude": "22.52452537250629",
        "gcj02Longitude": "113.93900136337268",
        "type": "wifi",
        "time": 1714025191125
      }
    },
    "propertyResponse": {
      "code": 0,
      "info": {
        "1": "56",
        "2": "1",
        "3": "113.934...,22.527...,done,wifi,normal,,",
        "6": "4",
        "9": "120"
      }
    },
    "fenceResponse": {
      "code": 0,
      "list": [{
        "fenceId": 1037645549974077440,
        "fenceName": "家",
        "radius": "100",
        "safe": 1,
        "wsg84Latitude": "22.52742351543659",
        "wsg84Longitude": "113.9342097495608",
        "warnStayAwaySafe": 0
      }]
    },
    "petResponse": {
      "code": 0,
      "info": {
        "petName": "豆包",
        "breed": "dog",
        "avatar": "https://..."
      }
    }
  }],
  "tip": "响应成功"
}
```

**`propertyResponse.info` 属性编号对照**：

| 编号 | 含义 | 示例值 |
|------|------|--------|
| `"1"` | 电池电量 (%) | `"56"` |
| `"2"` | 充电状态 (1=充电中) | `"1"` |
| `"3"` | 位置原始串 | `"经度,纬度,done,wifi,normal,,"` |
| `"4"` | 网络类型 | `"1"` |
| `"5"` | 开机状态 | `"1"` |
| `"6"` | 信号强度 | `"4"` |
| `"7"` | GPS 状态 | `"1"` |
| `"9"` | 位置上报周期（秒） | `"120"` |
| `"10"` | 睡眠模式 | `"0"` |
| `"11"` | 勿扰模式相关 | `"1"` |
| `"13"` | SIM 卡信息 | `"T10_074802,12345678"` |
| `"17"` | 固件版本 | `"2"` |
| `"18"` | 最后操作结果 | `"136@success"` |
| `"19"` | 开关机时间戳 | `"1,1713859974"` |

---

### 2.2 实时位置查询 ⭐⭐⭐

**接口**：`POST /uclgwapp/pet/position`

```json
// 请求
{
  "loginCustomerId": "619eec5a91fe743dbb39ccbe",
  "mac": "353682680378096",
  "streamNo": "APP2024032108043065401",
  "lang": "zh-CN"
}

// 响应
{
  "code": 0,
  "info": {
    "wsg84Latitude": "40.244924",
    "wsg84Longitude": "-111.674390",
    "gcj02Latitude": "40.244924",
    "gcj02Longitude": "-111.67439",
    "bd09Latitude": "40.25117315506434",
    "bd09Longitude": "-111.66781530199299",
    "address": "835, North 900 West Street...",
    "type": "gps",
    "subType": "houseWifi_in",
    "time": 1753148251236,
    "reportTime": 1753148251236,
    "locationInChina": 0
  }
}
```

**定位类型 `type`**：
- `gps` → 卫星定位（精度最高）
- `wifi` → WiFi 定位（室内场景）
- `celltower` → 基站定位（精度最低）

**`subType` 说明**：
- `houseWifi_in` → 设备在信任 WiFi 内（宠物在家）
- `houseWifi_out` → 设备不在信任 WiFi 内
- `houseWifi_none` → 未配置信任 WiFi

---

### 2.3 历史轨迹查询 ⭐⭐

**接口**：`POST /uclgwapp/user/device/device/position/get`

```json
// 请求
{
  "loginCustomerId": "619eec5a91fe743dbb39ccbe",
  "mac": "353682680378096",
  "streamNo": "APP2024032108043065401",
  "pageSize": "200",
  "startTime": "1747951200263",
  "endTime": "1748037599263"
}

// 响应
{
  "code": 0,
  "info": {
    "data": [{
      "wsg84Latitude": "51.435482",
      "wsg84Longitude": "-0.882287",
      "reportTime": 1747993524340,
      "locationInChina": 0,
      "mac": "357950340055982"
    }],
    "count": 1
  }
}
```

---

### 2.4 设备属性查询与控制 ⭐⭐⭐

**查询属性**：`POST /uclgwapp/pet/deviceAttr/list`  
**修改属性**：`POST /uclgwapp/pet/deviceAttr/update`

**属性编码（`codeList`）**：

| 属性编码 | 含义 | 值格式 |
|---------|------|--------|
| `MODE_DND` | 勿扰模式 | `"0,1,1,1,1,1"` — 6位 (总开关,渴,饿,出去玩,宠人,宠宠)，0=正常，1=勿扰 |
| `SOUND_PETPET` | 宠宠声纹文件地址 | URL 字符串 |
| `SOUND_PETAPP` | 宠人声纹文件地址 | URL 字符串 |
| `VOICE_PARAM` | 录音参数 | `"开关,总时长(分钟),起始时间戳(秒)"` |

```json
// 查询属性
{
  "mac": "353682680080346",
  "loginCustomerId": "654850de35d5a921ef9ead42",
  "streamNo": "1234561111111111111",
  "langType": "zh-CN",
  "codeList": ["MODE_DND", "SOUND_PETPET", "SOUND_PETAPP", "VOICE_PARAM"]
}

// 修改属性（开启勿扰模式）
{
  "mac": "357950340001119",
  "loginCustomerId": "654850de35d5a921ef9ead42",
  "streamNo": "xxx",
  "langType": "zh-CN",
  "attrList": [
    { "code": "MODE_DND", "value": "1,0,0,0,0,0" }
  ]
}

// 修改属性（开启录音，30分钟）
{
  "mac": "357950340001119",
  "attrList": [
    { "code": "VOICE_PARAM", "value": "1,30,1714025191" }
  ]
}

// 修改属性（关闭录音）
{
  "mac": "357950340001119",
  "attrList": [
    { "code": "VOICE_PARAM", "value": "0,," }
  ]
}
```

---

### 2.5 声网实时通话凭证 ⭐⭐⭐

**接口**：`POST /uclgwapp/pet/agora/getToken`

```json
// 请求
{
  "loginCustomerId": "66cd35c332eba5609030d2f6",
  "streamNo": "Robot20141120112551920213",
  "mac": "202411061234567",
  "langType": "zh-CN"
}

// 响应
{
  "code": 0,
  "info": {
    "appId": "0bc0f2d2e0994f5e8005a87cb1564463",
    "channelName": "202411061234567_17411444447169605",
    "token": "007eJxTYGH...",
    "userId": "66cd35c332eba5609030d2f6",
    "terminalToken": "007eJxTYHh...",
    "terminalUserId": "202411061234567",
    "license": "licensefsafsdf"
  }
}
```

**通话流程**：
```
1. App 调用 /pet/agora/getToken
2. App 使用 appId + token + channelName 加入声网频道
3. 设备使用 terminalToken + terminalUserId 加入同一频道
4. 双向音频通道建立 → 人宠实时通话
```

---

### 2.6 活动监测 ⭐⭐

| 接口 | 功能 |
|------|------|
| `POST /uclgwapp/pet/step/listDate` | 按天聚合（日统计） |
| `POST /uclgwapp/pet/step/list` | 原始数据（不聚合） |
| `POST /uclgwapp/pet/step/listDayCount` | 时间段内平均值 |

```json
// 请求（三个接口通用）
{
  "loginCustomerId": "xxx",
  "streamNo": "xxx",
  "mac": "202411061234567",
  "langType": "zh-CN",
  "startTime": "1632182400000",
  "endTime": "1832268800000"
}

// listDate 响应
{
  "code": 0,
  "list": [{
    "reportTime": 1733184000000,
    "stepNum": 427,
    "stepDistance": 31.7,
    "stepHeat": 52754051.97,
    "stepTime": 3083000
  }]
}
```

**单位说明**：
- `stepDistance` — 厘米（÷100 得米）
- `stepHeat` — 卡路里（÷1000 得千卡）
- `stepTime` — 毫秒（÷60000 得分钟）

---

### 2.7 运动计划 ⭐

| 接口 | 功能 |
|------|------|
| `POST /uclgwapp/pet/plan/list` | 查询当前计划 |
| `POST /uclgwapp/pet/plan/set` | 设置/更新计划（不存在则新增） |
| `POST /uclgwapp/pet/plan/advice` | 获取健康建议计划值 |
| `POST /uclgwapp/pet/plan/queryAdvice` | 查询建议值 |

```json
// 设置计划
{
  "mac": "202411061234561",
  "loginCustomerId": "xxx",
  "langType": "zh-CN",
  "streamNo": "xxx",
  "planHeat": "167",       // 目标热量（卡路里）
  "planDistance": "771",   // 目标距离（厘米）
  "planSecond": "478"      // 目标时长（秒）
}
```

---

### 2.8 信任WiFi（家庭围栏）⭐⭐

| 接口 | 功能 |
|------|------|
| `POST /uclgwapp/pet/houseWifi/add` | 新增信任WiFi |
| `POST /uclgwapp/pet/houseWifi/del` | 删除信任WiFi |
| `POST /uclgwapp/pet/houseWifi/update` | 修改信任WiFi |
| `POST /uclgwapp/pet/houseWifi/list` | 查询信任WiFi列表 |

```json
// 新增信任WiFi
{
  "mac": "353682680378096",
  "loginCustomerId": "619eec5a91fe743dbb39ccbe",
  "langType": "zh-CN",
  "streamNo": "APP2024032108043065401",
  "ssid": "HomeWiFi_Name",
  "macAddress": "30:89:D3:46:9A:EB",
  "latitude": "40.244924",
  "longitude": "-111.674390",
  "address": "深圳市南山区科技园"
}
```

---

### 2.9 音乐播放（宠物舒缓音乐）⭐⭐

| 接口 | 功能 |
|------|------|
| `POST /uclgwapp/pet/music/queryPlayList` | 查询系统歌单列表 |
| `POST /uclgwapp/pet/music/queryList` | 查询歌单下的歌曲 |
| `POST /uclgwapp/pet/musicPlaylist/queryMyPlaylist` | 查询用户自建歌单 |
| `POST /uclgwapp/pet/music/addMusicToPlaylist` | 歌单添加歌曲 |
| `POST /uclgwapp/pet/music/delMusicToPlaylist` | 歌单删除歌曲 |
| `POST /uclgwapp/pet/music/add` | 导入外部歌曲 |
| `POST /uclgwapp/pet/musicPlaylist/queryPlaylistById` | 查询歌单详情 |

**歌单类别 `category` 参数**：

| 值 | 含义 |
|----|------|
| `ALL` | 全部 |
| `DOG` | 狗狗专属 |
| `CAT` | 猫咪专属 |
| `LIMITEDTIMEFREE` | 限时免费 |

```json
// 查询歌单列表
{
  "streamNo": "xxx",
  "loginCustomerId": "xxx",
  "mac": "123451234512345",
  "category": "DOG",
  "langType": "zh-CN"
}
```

---

### 2.10 声纹管理 ⭐

| 接口 | 功能 |
|------|------|
| `POST /uclgwapp/pet/sound/add` | 上传声纹文件记录 |
| `POST /uclgwapp/pet/sound/list` | 查询声纹列表 |
| `POST /uclgwapp/pet/sound/update` | 修改声纹（含定时播放） |
| `POST /uclgwapp/pet/sound/del` | 删除声纹 |

```json
// 声纹列表响应（含定时播放设置）
{
  "list": [{
    "id": 33333334,
    "url": "https://xxx.com/sound.mp4",
    "soundSecond": 3.0,
    "playTime": "0143",   // 定时播放时间 "HHMM" (GMT0)，如 "0143" = 01:43
    "playFlag": "1"       // 1=开启定时播放，0=关闭
  }]
}
```

---

### 2.11 宠物好友社交 ⭐

| 接口 | 功能 |
|------|------|
| `POST /uclgwapp/pet/friend/friendTypeList` | 查询扫描到的周边设备 |
| `POST /uclgwapp/pet/friendLog/query` | 查询好友申请记录 |
| `POST /uclgwapp/pet/friendLog/audit` | 审批好友申请 |
| `POST /uclgwapp/pet/friend/list` | 好友列表（传 friendType=0/1） |
| `POST /uclgwapp/pet/friend/update` | 操作好友（见操作类型） |
| `POST /uclgwapp/pet/friend/del` | 永久删除好友 |
| `POST /uclgwapp/pet/friend/friendTypeInfo` | 查询单个对象信息 |

**好友 `operateType` 操作类型**：

| 值 | 含义 |
|----|------|
| `2` | 添加到黑名单 |
| `3` | 解除黑名单 |
| `4` | 修改好友备注 |
| `6` | 修改通话权限（callType: 1=允许, 0=禁止） |

---

### 2.12 宠物信息管理 ⭐⭐

| 接口 | 功能 |
|------|------|
| `POST /uclgwapp/pet/info/add` | 新增宠物（绑定 mac） |
| `POST /uclgwapp/pet/info/update` | 修改宠物信息 |
| `POST /uclgwapp/pet/info/get` | 查询宠物信息 |
| `POST /uclgwapp/pet/updatePosition` | 更新设备位置（App端定位上报） |

**宠物信息字段**：

| 字段 | 类型 | 说明 |
|------|------|------|
| `mac` | String | 设备 IMEI（宠物与设备绑定的关键） |
| `petName` | String | 宠物名称 |
| `breed` | String | 物种：`cat` / `dog` / `other` |
| `breedType` | String | 品种子类型，如 `TEDDY` |
| `sex` | String | `GG`=公，`MM`=母 |
| `age` | String | 年龄 |
| `weight` | String | 体重 |
| `avatar` | String | 头像 URL |
| `scene` | String | `PET`=宠物 / `HUMAN`=人 / `ITEM`=物品 |
| `birthTimestamp` | Long | 生日时间戳（毫秒） |

---

### 2.13 安全围栏排行榜 ⭐

**接口**：`POST /uclgwapp/pet/fence/safeTop`

返回好友宠物在围栏内的时长排行，用于社区排行榜功能。

---

## 三、坐标系说明

| 字段前缀 | 坐标系 | 适用场景 |
|---------|-------|---------|
| `wsg84` | WGS-84（国际GPS） | 海外地图、谷歌地图、Apple Maps |
| `gcj02` | GCJ-02（火星坐标） | 高德地图、腾讯地图（中国大陆） |
| `bd09` | BD-09（百度坐标） | 百度地图 |

> **移植建议**：统一使用 `wsg84Latitude/wsg84Longitude` 存储，按目标平台在渲染时转换。

---

## 四、场景类型 `scene`

| 值 | 含义 |
|----|------|
| `PET` | 宠物场景（设备挂在宠物上） |
| `HUMAN` | 人场景（主人手持设备） |
| `ITEM` | 物品追踪场景 |

---

## 五、移植优先级

```
第一阶段（MVP）：
  ├─ /pet/device/list        → 首页设备卡片（在线、电量、位置）
  ├─ /pet/position           → 实时位置地图
  └─ /pet/deviceAttr/*       → 勿扰模式 + 录音开关

第二阶段（核心功能）：
  ├─ /pet/agora/getToken     → 人宠实时通话
  ├─ /pet/music/queryPlayList → 舒缓音乐
  ├─ /pet/step/listDate      → 活动统计
  └─ /pet/houseWifi/*        → 家庭WiFi围栏（在家检测）

第三阶段（完整功能）：
  ├─ /pet/plan/*             → 运动计划
  ├─ /pet/sound/*            → 声纹管理
  ├─ /pet/friend/*           → 宠物社交
  ├─ /pet/info/*             → 宠物档案
  └─ /pet/fence/safeTop      → 围栏排行榜
```

---

## 六、Flutter 层对应实现规划

```
lib/
├─ core/
│   ├─ api/
│   │   ├─ api_endpoints.dart     ← 需新增所有 /uclgwapp/ 路由常量
│   │   └─ api_client.dart        ← 需支持 access_token URL 拼接（非 Bearer）
│   └─ config/
│       └─ app_config.dart        ← 需新增硬件网关 baseUrl
│
└─ features/
    ├─ home/
    │   └─ data/repository/
    │       ├─ device_repository.dart      ← 设备列表、位置
    │       └─ activity_repository.dart    ← 步数、热量
    ├─ device_control/
    │   └─ data/repository/
    │       ├─ device_attr_repository.dart ← 勿扰、录音
    │       └─ agora_repository.dart       ← 通话凭证
    ├─ music/
    │   └─ data/repository/
    │       └─ music_repository.dart       ← 歌单、歌曲
    └─ pet/
        └─ data/repository/
            ├─ pet_info_repository.dart    ← 宠物档案
            └─ wifi_fence_repository.dart  ← 信任WiFi
```

---

## 七、当前 App 对接现状

| 功能 | 状态 | 说明 |
|------|------|------|
| AI 语音翻译 | ✅ 已实现 | 对接 `http://49.234.39.11:8002/analyze` |
| 设备绑定流程 | ⚠️ UI完成 | 无真实 API，扫码后用模拟数据 |
| 设备卡片状态 | ⚠️ UI完成 | 硬编码：电量85%、在线、位置南山区 |
| 实时位置 | ❌ 未实现 | 需接 `/pet/position` |
| 活动统计 | ❌ 未实现 | 需接 `/pet/step/listDate` |
| 人宠通话 | ❌ 未实现 | 需接声网凭证 + Agora SDK |
| 舒缓音乐 | ❌ 未实现 | 需接 `/pet/music/*` |
| 勿扰模式 | ❌ 未实现 | 需接 `/pet/deviceAttr/update` |
| 宠物好友 | ❌ 未实现 | 需接 `/pet/friend/*` |
