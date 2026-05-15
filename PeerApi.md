# iPet App API 接口文档

> 基于完整测试 (34/34 PASS) 生成 — 2026-05-13

> [!NOTE]
> 基础URL: `http://192.168.1.130:8002`  
> 认证方式: 通过 `token` Header 传递登录获取的 `granwin_token`  
> Content-Type: `application/x-www-form-urlencoded` (除特别说明外)


---

## 1. 用户模块 (UserController)

### 1.1 POST /user/register — 用户注册

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| account | String | ✅ | 账号 (邮箱格式, 不能含下划线等特殊字符) |
| password | String | ✅ | 密码 |
| merchantId | Long | ✅ | 商户ID |

**响应:**
```json
{"code": 0, "tip": "响应成功"}
```

---

### 1.2 POST /user/login — 用户登录

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| account | String | ✅ | 账号 |
| password | String | ✅ | 密码 |
| merchantId | Long | ✅ | 商户ID |

**响应:**
```json
{
  "code": 0,
  "info": {
    "granwin_token": "granwin_aws_user_info_hash:_43200_xxx",
    "refresh_token": "granwin_aws_user_info_refresh_hash:_2592000_xxx",
    "endpoint": "a1xqh218n3g872-ats.iot.us-east-1.amazonaws.com",
    "region": "us-east-1",
    "merchantId": 1,
    "account": "testuser@example.com",
    "expiration": 43200,
    "pool": {
      "identifier": "1_testuser@example.com_1214421015901298688",
      "identityId": "us-east-1:xxx",
      "identityPoolId": "us-east-1:xxx",
      "token": "eyJ..."
    },
    "proof": {
      "accessKeyId": "ASIAxxx",
      "secretKey": "xxx",
      "sessionToken": "xxx",
      "sessionExpiration": 1778665202000
    }
  },
  "tip": "响应成功"
}
```

---

### 1.3 POST /user/refresh/token — 刷新Token

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| refreshToken | String | ✅ | 登录时返回的 refresh_token |

> [!IMPORTANT]
> 参数名是 `refreshToken`（驼峰），不是 `refresh_token`

**响应:** 与登录响应相同结构，返回新的 `granwin_token`

---

### 1.4 POST /user/info/get — 获取用户信息 🔒

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| (无) | | | |

**响应:**
```json
{
  "code": 0,
  "info": {
    "id": 1214421015901298688,
    "account": "testuser@example.com",
    "email": "testuser@example.com",
    "name": "TestPetUser",
    "phone": "",
    "sex": 1,
    "age": 25,
    "country": "China",
    "countryId": "CN",
    "merchantId": 1,
    "merchantName": "iPet",
    "identityId": "us-east-1:xxx",
    "identityPoolId": "us-east-1:xxx",
    "param": "{\"deviceOfflineSub\":true,...}",
    "status": 1,
    "deleted": 0,
    "createTime": 1778652143283
  },
  "tip": "响应成功"
}
```

---

### 1.5 POST /user/info/update — 更新用户信息 🔒

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| name | String | ❌ | 昵称 |
| sex | Integer | ❌ | 性别 (1=男, 2=女) |
| age | Integer | ❌ | 年龄 |

**响应:** `{"code": 0, "tip": "响应成功"}`

---

### 1.6 POST /user/password/update — 修改密码 🔒

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| oldPassword | String | ✅ | 旧密码 |
| newPassword | String | ✅ | 新密码 |

**响应:** `{"code": 0, "tip": "响应成功"}`

---

### 1.7 POST /user/time/get — 获取服务器时间 🔒

**响应:**
```json
{"code": 0, "info": {"time": 1778661605792}, "tip": "响应成功"}
```

---

### 1.8 POST /user/set/param — 设置用户附加参数 🔒

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| unit | String | ❌ | 单位制 (metric/imperial) |
| timezone | String | ❌ | 时区 |

**响应:** `{"code": 0, "tip": "响应成功"}`

---

### 1.9 POST /user/get/sub — 获取订阅配置 🔒

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| placeId | Long | ❌ | 场所ID (0=全部) |

**响应:**
```json
{
  "code": 0,
  "info": {
    "deviceOfflineSub": true,
    "taskCreateSub": true,
    "taskCompletionSub": true,
    "deviceFaultSub": true
  },
  "tip": "响应成功"
}
```

---

### 1.10 POST /user/query — 查询用户信息

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| account | String | ✅ | 账号 |
| merchantId | Long | ✅ | 商户ID |

**响应:**
```json
{
  "code": 0,
  "info": {
    "id": 1214421015901298688,
    "account": "testuser@example.com",
    "name": "TestPetUser",
    "email": "testuser@example.com",
    "country": "China",
    "status": 1,
    "deleted": 0
  },
  "tip": "响应成功"
}
```

---

## 2. 用户设备模块 (UserDeviceController)

### 2.1 POST /user/device/bind — 绑定设备 🔒

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| mac | String | ✅* | 设备MAC地址 (与deviceId二选一) |
| deviceId | Long | ✅* | 设备ID (与mac二选一) |
| productKey | String | ❌ | 产品Key (设备不存在时用于自动创建) |
| deviceNickName | String | ❌ | 设备昵称 |

**响应:**
```json
{
  "code": 0,
  "info": {
    "appuserId": "1214421015901298688",
    "deviceId": "1",
    "mac": "ipet-esp32-Device",
    "productId": "1",
    "productKey": "PK_IPET_ESP32",
    "deviceNickname": "iPet ESP32 智能宠物设备",
    "connect": true,
    "uType": "1",
    "sharer": "0",
    "createTime": 1778661536700,
    "updateTime": 1778661536700
  },
  "tip": "响应成功"
}
```

---

### 2.2 POST /user/device/list — 设备列表 🔒

**响应:**
```json
{
  "code": 0,
  "info": [{
    "deviceId": "1",
    "mac": "ipet-esp32-Device",
    "productId": "1",
    "productKey": "PK_IPET_ESP32",
    "alias": "ipet-esp32",
    "deviceNickname": "iPet ESP32 智能宠物设备",
    "connect": true,
    "uType": "1",
    "sharer": "0",
    "appuserId": "1214421015901298688",
    "createTime": 1778661536700,
    "updateTime": 1778661536700
  }],
  "tip": "响应成功"
}
```

---

### 2.3 POST /user/device/own/devices — 用户拥有的设备 🔒

**响应:**
```json
{
  "code": 0,
  "info": [{
    "deviceId": "1",
    "mac": "ipet-esp32-Device",
    "nickName": "iPet ESP32 智能宠物设备",
    "count": 0,
    "time": 1778661536700,
    "type": "1"
  }],
  "tip": "响应成功"
}
```

---

### 2.4 POST /user/device/detail — 设备详情 🔒

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| mac | String | ✅ | 设备MAC |

**响应:**
```json
{
  "code": 0,
  "info": {
    "id": 1,
    "name": "iPet ESP32 智能宠物设备",
    "mac": "ipet-esp32-Device",
    "productId": 1,
    "productKey": "PK_IPET_ESP32",
    "productName": "iPet ESP32 智能宠物设备",
    "onlineStatus": true,
    "deviceNickName": "iPet ESP32 智能宠物设备",
    "merchantId": 1,
    "merchantName": "平台",
    "lastOnlineTime": 1778571516272,
    "status": 1,
    "deleted": 0
  },
  "tip": "响应成功"
}
```

---

### 2.5 GET /user/device/online/state — 设备在线状态 🔒

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| mac | String | ✅ | 设备MAC (URL参数) |

**响应:**
```json
{"code": 0, "info": {"onlineState": true}, "tip": "响应成功"}
```

---

### 2.6 POST /user/device/share/withme — 共享给我的设备 🔒

**响应:** `{"code": 0, "info": [], "tip": "响应成功"}`

---

### 2.7 POST /user/device/member/query — 设备成员查询 🔒

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| mac | String | ✅ | 设备MAC |

**响应:**
```json
{
  "code": 0,
  "info": [{
    "userId": 1214421015901298688,
    "account": "testuser@example.com",
    "username": "TestPetUser",
    "mac": "ipet-esp32-Device",
    "type": "1",
    "createTime": 1778661536700
  }],
  "tip": "响应成功"
}
```

---

### 2.8 POST /user/device/update — 更新设备信息 🔒

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| mac | String | ✅ | 设备MAC |
| deviceNickName | String | ❌ | 设备昵称 |

**响应:** `{"code": 0, "tip": "响应成功"}`

---

### 2.9 POST /user/device/mcuota/get — 获取MCU OTA信息 🔒

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| mac | String | ✅ | 设备MAC |

**响应:**
```json
{
  "code": 0,
  "info": {
    "isUpgrade": false,
    "deviceId": 1,
    "mac": "ipet-esp32-Device",
    "currentVersion": "default",
    "msg": "没有新版本",
    "msgCode": "OTA_MCU_000"
  },
  "tip": "响应成功"
}
```

---

### 2.10 POST /user/device/unbind — 解绑设备 🔒

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| mac | String | ✅ | 设备MAC |

**响应:** `{"code": 0, "tip": "响应成功"}`

---

## 3. 设备模块 (DeviceController)

### 3.1 POST /device/product/list — 产品列表 🔒

**响应:**
```json
{
  "code": 0,
  "list": [{
    "id": 1,
    "name": "iPet ESP32 智能宠物设备",
    "productKey": "PK_IPET_ESP32",
    "alias": "ipet-esp32",
    "merchantId": 1,
    "productTypeName": "智能宠物设备",
    "status": 1
  }],
  "pageTurn": {"currentPage": 1, "pageCount": 1, "rowCount": 1, "pageSize": 20},
  "tip": "响应成功"
}
```

---

### 3.2 POST /device/product/tree — 产品分类树 🔒

**响应:**
```json
{
  "code": 0,
  "info": [{
    "id": 1, "name": "宠物用品", "level": 1, "parentId": 0,
    "children": [
      {"id": 2, "name": "喂食器", "level": 2, "parentId": 1},
      {"id": 3, "name": "饮水机", "level": 2, "parentId": 1},
      {"id": 4, "name": "摄像头", "level": 2, "parentId": 1}
    ]
  }],
  "tip": "响应成功"
}
```

---

### 3.3 POST /device/category/list — 品类列表 🔒

**响应:** 分页列表，包含 `list` 和 `pageTurn`

---

### 3.4 POST /device/point/list — 功能点列表 🔒

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| mac | String | ✅ | 设备MAC |

**响应:** `{"code": 0, "info": [], "tip": "响应成功"}`

---

### 3.5 POST /device/bind/parameter — 生成绑定参数 🔒

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| mac | String | ✅ | 设备MAC |

**响应:**
```json
{"code": 0, "info": {"p": "", "r": "", "s": "4AVhkY"}, "tip": "响应成功"}
```

---

## 4. 宠物信息模块 (PetInfoController)

### 4.1 POST /pet/info/add — 添加宠物 🔒

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| petName | String | ✅ | 宠物名称 |
| mac | String | ✅* | 设备MAC (与deviceId二选一) |
| deviceId | Long | ✅* | 设备ID (与mac二选一) |
| breed | String | ❌ | 品种 |
| age | Integer | ❌ | 年龄 |
| weight | String | ❌ | 体重 |
| sex | String | ❌ | 性别 (GG=公, MM=母, GG_sterilization=公绝育, MM_sterilization=母绝育) |
| avatar | String | ❌ | 头像URL |

**响应:** `{"code": 0, "tip": "响应成功"}`

---

### 4.2 POST /pet/info/get — 获取宠物信息 🔒

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| mac | String | ✅* | 设备MAC (与deviceId二选一) |
| deviceId | Long | ✅* | 设备ID (与mac二选一) |

**响应:**
```json
{
  "code": 0,
  "info": {
    "petId": 1214460409028706304,
    "petName": "Lucky",
    "breed": "GoldenRetriever",
    "age": 3,
    "weight": "25.5",
    "sex": "GG",
    "deviceId": 1,
    "userId": 1214421015901298688,
    "createTime": 1778661535321
  },
  "tip": "响应成功"
}
```

---

### 4.3 POST /pet/info/update — 更新宠物信息 🔒

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| petId | Long | ✅ | 宠物ID |
| petName | String | ❌ | 宠物名称 |
| breed | String | ❌ | 品种 |
| age | Integer | ❌ | 年龄 |
| weight | String | ❌ | 体重 |
| sex | String | ❌ | 性别 |
| avatar | String | ❌ | 头像URL |

**响应:** `{"code": 0, "tip": "响应成功"}`

---

### 4.4 POST /pet/info/del — 删除宠物 🔒

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| petId | Long | ✅* | 宠物ID (与deviceId二选一) |
| deviceId | Long | ✅* | 设备ID (与petId二选一) |

**响应:** `{"code": 0, "tip": "响应成功"}`

---

### 4.5 POST /pet/position — 获取宠物位置 🔒

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| mac | String | ✅* | 设备MAC (与deviceId二选一) |
| deviceId | Long | ✅* | 设备ID |
| lang | String | ❌ | 语言 (zh/en) |

> [!WARNING]
> 需配置 `ucl_map_mark_name` 和 `map_key` 系统参数，否则返回 code=17812/17816

**响应 (配置完整时):**
```json
{
  "code": 0,
  "info": {
    "latitude": "31.2304",
    "longitude": "121.4737",
    "wsg84Latitude": "31.2304",
    "wsg84Longitude": "121.4737",
    "gcj02Latitude": "...",
    "gcj02Longitude": "...",
    "bd09Latitude": "...",
    "bd09Longitude": "...",
    "address": "...",
    "addressComponents": [...],
    "time": 1778661535321,
    "reportTime": 1778661535321
  }
}
```

---

### 4.6 POST /address/get — 获取地址信息

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| longitude | String | ✅ | 经度 |
| latitude | String | ✅ | 纬度 |
| lang | String | ❌ | 语言 |

> [!WARNING]
> 需配置 `map_key` 系统参数

---

## 5. 宠物围栏模块 (PetFenceController)

### 5.1 POST /pet/fence/add — 添加围栏 🔒

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| fenceName | String | ✅ | 围栏名称 |
| longitude | String | ✅ | 经度 |
| latitude | String | ✅ | 纬度 |
| radius | String | ✅ | 半径 (米) |
| address | String | ✅ | 地址 |
| mac | String | ✅* | 设备MAC (与deviceId二选一) |
| deviceId | Long | ✅* | 设备ID (与mac二选一) |
| street | String | ❌ | 街道 |
| coordinateType | String | ❌ | 坐标系类型 (`wgs84`/`gcj02`/`bd09`) |

**响应:** `{"code": 0, "tip": "响应成功"}`

---

### 5.2 POST /pet/fence/list — 围栏列表

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| mac | String | ✅* | 设备MAC (与deviceId二选一) |
| deviceId | Long | ✅* | 设备ID (与mac二选一) |

**响应:**
```json
{
  "code": 0,
  "list": [{
    "fenceId": 1214460741553127424,
    "fenceName": "Home",
    "longitude": "121.4737",
    "latitude": "31.2304",
    "radius": "500",
    "address": "Shanghai China",
    "street": "Nanjing Road",
    "deviceId": 1,
    "wsg84Longitude": "121.4737",
    "wsg84Latitude": "31.2304",
    "gcj02Longitude": "121.47822305927693",
    "gcj02Latitude": "31.22845773757727",
    "bd09Longitude": "121.484781468503",
    "bd09Latitude": "31.234310593689997",
    "createTime": 1778661614601
  }],
  "tip": "响应成功"
}
```

---

### 5.3 POST /pet/fence/update — 更新围栏 🔒

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| fenceId | Long | ✅ | 围栏ID |
| fenceName | String | ❌ | 围栏名称 |
| longitude | String | ❌ | 经度 |
| latitude | String | ❌ | 纬度 |
| radius | String | ❌ | 半径 |
| address | String | ❌ | 地址 |
| street | String | ❌ | 街道 |
| coordinateType | String | ❌ | 坐标系类型 |

**响应:** `{"code": 0, "tip": "响应成功"}`

---

### 5.4 POST /pet/fence/del — 删除围栏 🔒

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| fenceId | Long | ✅ | 围栏ID |

**响应:** `{"code": 0, "tip": "响应成功"}`

---

## 错误码参考

| code | 说明 |
|------|------|
| 0 | 成功 |
| 1 | 一般失败 |
| -1 | 业务异常 |
| 1001 | 请求参数错误 |
| 1010 | Token不存在 |
| 3030 | 商户App应用不存在 |
| 17812 | 地图mark_name未配置 |
| 17816 | 地图api_key未配置 |
| 17817 | 坐标系类型错误 |

---

## 测试结果汇总

```
Passed: 34/34 (100%)
```

| 模块 | 接口数 | 通过 |
|------|--------|------|
| 用户模块 | 11 | ✅ 11 |
| 用户设备模块 | 10 | ✅ 10 |
| 设备模块 | 5 | ✅ 5 |
| 宠物信息模块 | 4 | ✅ 4 |
| 宠物围栏模块 | 2 | ✅ 2 |
| 清理(删除/解绑) | 2 | ✅ 2 |

> [!NOTE]
> 🔒 表示需要 `token` Header 认证
> ✅* 表示标记为必填但与另一个参数二选一
