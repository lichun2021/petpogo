# iPet App 接口文档

> 服务地址: `http://localhost:8002`
> 测试时间: 2026-05-25 13:53:32
> 测试设备: `ipet-esp32-Device-02`
> App 端接口: **93** 个

---

## 认证方式

除标注 `免登录` 的接口外，所有接口均需在请求 Header 中携带 Token：

| Header | 值 |
|--------|----|
| `token` | 登录返回的 `granwin_token` |

Token 有效期 **12 小时**，过期后使用 `refresh_token` 刷新。

```bash
# 获取 Token
TOKEN=$(curl -s http://localhost:8002/user/login -X POST \
  -d "account=your@email.com&password=xxx&merchantId=1" \
  | python3 -c "import sys,json;print(json.load(sys.stdin)['info']['granwin_token'])")
```

---

## 目录

1. [用户模块](#1-用户模块) (16个)
2. [用户设备模块](#2-用户设备模块) (15个)
3. [设备模块](#3-设备模块) (10个)
4. [宠物信息模块](#4-宠物信息模块) (3个)
5. [宠物围栏模块](#5-宠物围栏模块) (4个)
6. [应用模块](#6-应用模块) (6个)
7. [消息模块](#7-消息模块) (5个)
8. [用户反馈模块](#8-用户反馈模块) (2个)
9. [数据中心模块](#9-数据中心模块) (6个)
10. [国家地区模块](#10-国家地区模块) (4个)
11. [任务模块](#11-任务模块) (2个)
12. [设备分组模块](#12-设备分组模块) (1个)
13. [设备控制模块](#13-设备控制模块) (8个)
14. [需外部条件的接口](#14-需外部条件的接口) (11个)

## 1. 用户模块

### 1.1 POST /user/register — 用户注册 ✅

> **认证**: 免登录

**请求参数:**

| 参数 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `account` | String | `apitest688365@test.com` | |
| `password` | String | `Test123456` | |
| `merchantId` | String | `1` | |

```json
{
  "account": "apitest688365@test.com",
  "password": "Test123456",
  "merchantId": "1"
}
```

**curl 示例:**

```bash
curl -s http://localhost:8002/user/register -X POST \
  -d "account=apitest688365@test.com&password=Test123456&merchantId=1"
```

**响应:** `code: 0` 响应成功

```json
{
  "code": 0,
  "tip": "响应成功"
}
```

---

### 1.2 POST /user/login — 用户登录 ✅

> **认证**: 免登录

**请求参数:**

| 参数 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `account` | String | `apitest688365@test.com` | |
| `password` | String | `Test123456` | |
| `merchantId` | String | `1` | |

```json
{
  "account": "apitest688365@test.com",
  "password": "Test123456",
  "merchantId": "1"
}
```

**curl 示例:**

```bash
curl -s http://localhost:8002/user/login -X POST \
  -d "account=apitest688365@test.com&password=Test123456&merchantId=1"
```

**响应:** `code: 0` 响应成功

```json
{
  "code": 0,
  "info": {
    "refresh_token": "granwin_aws_user_info_refresh_hash:_2592000_e67ef8733e9e7dcafc855e71241bdc02",
    "endpoint": "a1xqh218n3g872-ats.iot.us-east-1.amazonaws.com",
    "merchantId": 1,
    "pool": {
      "identifier": "1_apitest688365@test.com_1218767262805061632",
      "identityId": "us-east-1:22ec8aba-481f-cdca-3e53-91197b321ae8",
      "identityPoolId": "us-east-1:323e03d5-050e-4c7f-b314-23ebb3682e0b",
      "token": "eyJraWQiOiJ1cy1lYXN0LTEtOSIsInR5cCI6IkpXUyIsImFsZyI6IlJTNTEyIn0.eyJzdWIiOiJ1cy1lYXN0LTE6MjJlYzhhYmEtNDgxZi1jZGNhLTNlNTMtOTExOTdiMzIxYWU4IiwiYXVkIjoidXMtZWFzdC0xOjMyM2UwM2Q1LTA1MGUtNGM3Zi1iMzE0LTIzZWJiMzY4MmUwYiIsImFtciI6WyJhdXRoZW50aWNhdGVkIiwibG9naW4uZ3Jhbndpbi5wZXQiLCJsb2dpbi5ncmFud2luLnBldDp1cy1lYXN0LTE6MzIzZTAzZDUtMDUwZS00YzdmLWIzMTQtMjNlYmIzNjgyZTBiOjFfYXBpdGVzdDY4ODM2NUB0ZXN0LmNvbV8xMjE4NzY3MjYyODA1MDYxNjMyIl0sImlzcyI6Imh0dHBzOi8vY29nbml0by1pZGVudGl0eS5hbWF6b25hd3MuY29tIiwiZXhwIjoxNzc5Nzc0Nzc1LCJpYXQiOjE3Nzk2ODgzNzV9.E91pLejOV3TC3Ssv2MG3lg1ygnrjkmFGeEC5qu2MRR6W1cNXqJlYMUIlRTU-_mBpu5VLo8AQHqj72rDuPfLGbBco6tJwOXZZya7A1RXhTh-J53TPKT60DNyns3MNBcArOvKvJd0sa74cwNcf3YdrHI7Z8n1JRQmyy2HLNpbrKTor779yCC2D67bZUafu9xAubW1i-yN_W5afSuQeh1QAsn7zLn32nWcGMT6Ni0JvnJgMy67ON0jmj8II6a6zlHwSDlmW8-fO9NLCgFtqQJmc-ErgGupqCn94JMoyZy-4RtBDf_4ZsCsA2lWfH-H75WrbpSe_sAzuyLh-X3QuGke07w"
    },
    "expiration": 43200,
    "granwin_token": "granwin_aws_user_info_hash:_43200_8698cc5d519e53810ffdc57acea6cc34",
    "proof": {
      "accessKeyId": "<AWS_ACCESS_KEY_ID>",
      "secretKey": "<AWS_SECRET_ACCESS_KEY>",
      "sessionToken": "<AWS_SESSION_TOKEN>",
      "sessionExpiration": 1779691978000
    },
    "region": "us-east-1",
    "account": "apitest688365@test.com"
  },
  "tip": "响应成功"
}
```

---

### 1.3 POST /user/refresh/token — 刷新Token ✅

> **认证**: 免登录

**请求参数:**

| 参数 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `refreshToken` | String | `granwin_aws_user_info_refresh_hash:_2592000_e67ef8733e9e7dcafc855e71241bdc02` | |

```json
{
  "refreshToken": "granwin_aws_user_info_refresh_hash:_2592000_e67ef8733e9e7dcafc855e71241bdc02"
}
```

**curl 示例:**

```bash
curl -s http://localhost:8002/user/refresh/token -X POST \
  -d "refreshToken=granwin_aws_user_info_refresh_hash:_2592000_e67ef8733e9e7dcafc855e71241bdc02"
```

**响应:** `code: 0` 响应成功

```json
{
  "code": 0,
  "info": {
    "refresh_token": "granwin_aws_user_info_refresh_hash:_2592000_e67ef8733e9e7dcafc855e71241bdc02",
    "endpoint": "a1xqh218n3g872-ats.iot.us-east-1.amazonaws.com",
    "pool": {
      "identifier": "1_apitest688365@test.com_1218767262805061632",
      "identityId": "us-east-1:22ec8aba-481f-cdca-3e53-91197b321ae8",
      "identityPoolId": "us-east-1:323e03d5-050e-4c7f-b314-23ebb3682e0b",
      "token": "eyJraWQiOiJ1cy1lYXN0LTEtOSIsInR5cCI6IkpXUyIsImFsZyI6IlJTNTEyIn0.eyJzdWIiOiJ1cy1lYXN0LTE6MjJlYzhhYmEtNDgxZi1jZGNhLTNlNTMtOTExOTdiMzIxYWU4IiwiYXVkIjoidXMtZWFzdC0xOjMyM2UwM2Q1LTA1MGUtNGM3Zi1iMzE0LTIzZWJiMzY4MmUwYiIsImFtciI6WyJhdXRoZW50aWNhdGVkIiwibG9naW4uZ3Jhbndpbi5wZXQiLCJsb2dpbi5ncmFud2luLnBldDp1cy1lYXN0LTE6MzIzZTAzZDUtMDUwZS00YzdmLWIzMTQtMjNlYmIzNjgyZTBiOjFfYXBpdGVzdDY4ODM2NUB0ZXN0LmNvbV8xMjE4NzY3MjYyODA1MDYxNjMyIl0sImlzcyI6Imh0dHBzOi8vY29nbml0by1pZGVudGl0eS5hbWF6b25hd3MuY29tIiwiZXhwIjoxNzc5Nzc0Nzc5LCJpYXQiOjE3Nzk2ODgzNzl9.X2yucGfO3ytdOErRJOGNsHjpTfa21L1tM96Mm1muV6W_F57Uc5wK0qDTw1q4TWVaqIiZHUGx-VHo-2i4mCJx_RzJ6-sWhRdN47t3piZwWPLVx33vvVA1wKiMxwpVwGvr9sOU_TTssSUheoYMpZL89kGxH6RcIhi83607Jk30fb2--7OdIpmJBByOoJjVlj19Q596oWkRaKEq6SrQMsaEcEBs13rkYkcpiQajueyF5ho0q-vSUrZPxlJhC2_fdrnvBn1Lybg2ez8kktxU0RIKwPAYjqRZ6N4D8VeystykfqYSrnA9nefQqe8hjCEFBq71z2UkFdwXey9UowCGix6-Mg"
    },
    "expiration": 43200,
    "granwin_token": "granwin_aws_user_info_hash:_43200_e7df3d1dbc4c0db7eebb171dc40c7c5a",
    "proof": {
      "accessKeyId": "<AWS_ACCESS_KEY_ID>",
      "secretKey": "<AWS_SECRET_ACCESS_KEY>",
      "sessionToken": "<AWS_SESSION_TOKEN>",
      "sessionExpiration": 1779691980000
    },
    "region": "us-east-1",
    "account": "apitest688365@test.com"
  },
  "tip": "响应成功"
}
```

---

### 1.4 POST /user/info/get — 获取用户信息 ✅

> **认证**: 需Token
> **备注**: 需token

**请求参数:**

无参数

**curl 示例:**

```bash
curl -s http://localhost:8002/user/info/get -X POST \
  -H "token: $TOKEN"
```

**响应:** `code: 0` 响应成功

```json
{
  "code": 0,
  "info": {
    "account": "apitest688365@test.com",
    "country": "China",
    "countryId": "CN",
    "createBy": 1218767262805061632,
    "createTime": 1779688369295,
    "deleted": 0,
    "email": "apitest688365@test.com",
    "id": 1218767262805061632,
    "identityId": "us-east-1:22ec8aba-481f-cdca-3e53-91197b321ae8",
    "identityPoolId": "us-east-1:323e03d5-050e-4c7f-b314-23ebb3682e0b",
    "merchantId": 1,
    "merchantName": "iPet",
    "name": "apitest688365@test.com",
    "param": "{\"deviceOfflineSub\":true,\"taskCreateSub\":true,\"taskCompletionSub\":true,\"deviceFaultSub\":true}",
    "phone": "",
    "status": 1
  },
  "tip": "响应成功"
}
```

---

### 1.5 POST /user/info/update — 更新用户信息 ✅

> **认证**: 需Token

**请求参数:**

| 参数 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `name` | String | `ApiTester` | |
| `sex` | String | `1` | |
| `age` | String | `25` | |

```json
{
  "name": "ApiTester",
  "sex": "1",
  "age": "25"
}
```

**curl 示例:**

```bash
curl -s http://localhost:8002/user/info/update -X POST \
  -H "token: $TOKEN" \
  -d "name=ApiTester&sex=1&age=25"
```

**响应:** `code: 0` 响应成功

```json
{
  "code": 0,
  "tip": "响应成功"
}
```

---

### 1.6 POST /user/password/update — 修改密码 ✅

> **认证**: 需Token

**请求参数:**

| 参数 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `oldPassword` | String | `Test123456` | |
| `newPassword` | String | `Test123456` | |

```json
{
  "oldPassword": "Test123456",
  "newPassword": "Test123456"
}
```

**curl 示例:**

```bash
curl -s http://localhost:8002/user/password/update -X POST \
  -H "token: $TOKEN" \
  -d "oldPassword=Test123456&newPassword=Test123456"
```

**响应:** `code: 0` 响应成功

```json
{
  "code": 0,
  "tip": "响应成功"
}
```

---

### 1.7 POST /user/time/get — 获取服务器时间 ✅

> **认证**: 免登录

**请求参数:**

无参数

**curl 示例:**

```bash
curl -s http://localhost:8002/user/time/get -X POST
```

**响应:** `code: 0` 响应成功

```json
{
  "code": 0,
  "info": {
    "time": 1779688381741
  },
  "tip": "响应成功"
}
```

---

### 1.8 POST /user/set/param — 设置附加参数 ✅

> **认证**: 需Token

**请求参数:**

| 参数 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `unit` | String | `metric` | |
| `timezone` | String | `Asia/Shanghai` | |

```json
{
  "unit": "metric",
  "timezone": "Asia/Shanghai"
}
```

**curl 示例:**

```bash
curl -s http://localhost:8002/user/set/param -X POST \
  -H "token: $TOKEN" \
  -d "unit=metric&timezone=Asia/Shanghai"
```

**响应:** `code: 0` 响应成功

```json
{
  "code": 0,
  "tip": "响应成功"
}
```

---

### 1.9 POST /user/get/sub — 获取订阅配置 ✅

> **认证**: 需Token

**请求参数:**

无参数

**curl 示例:**

```bash
curl -s http://localhost:8002/user/get/sub -X POST \
  -H "token: $TOKEN"
```

**响应:** `code: 0` 响应成功

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

### 1.10 POST /user/query — 查询用户(免登录) ✅

> **认证**: 免登录

**请求参数:**

| 参数 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `account` | String | `apitest688365@test.com` | |
| `merchantId` | String | `1` | |

```json
{
  "account": "apitest688365@test.com",
  "merchantId": "1"
}
```

**curl 示例:**

```bash
curl -s http://localhost:8002/user/query -X POST \
  -d "account=apitest688365@test.com&merchantId=1"
```

**响应:** `code: 0` 响应成功

```json
{
  "code": 0,
  "info": {
    "account": "apitest688365@test.com",
    "age": 25,
    "country": "China",
    "deleted": 0,
    "email": "apitest688365@test.com",
    "id": 1218767262805061632,
    "name": "ApiTester",
    "param": "{\"deviceOfflineSub\":true,\"taskCreateSub\":true,\"taskCompletionSub\":true,\"deviceFaultSub\":true}",
    "password": "a6198d527a8d3686492fd97a3d196259",
    "phone": "",
    "salt": "EKKSJ6646EKES",
    "sex": 1,
    "status": 1
  },
  "tip": "响应成功"
}
```

---

### 1.11 POST /user/channel/get — 获取频道信息 ✅

> **认证**: 需Token

**请求参数:**

无参数

**curl 示例:**

```bash
curl -s http://localhost:8002/user/channel/get -X POST \
  -H "token: $TOKEN"
```

**响应:** `code: 1` 获取失败

```json
{
  "code": 1,
  "tip": "获取失败"
}
```

---

### 1.12 POST /user/app/check — App版本检查 ✅

> **认证**: 免登录

**请求参数:**

| 参数 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `version` | String | `1.0.0` | |
| `packageName` | String | `com.granwin.ipet` | |
| `type` | String | `1` | |

```json
{
  "version": "1.0.0",
  "packageName": "com.granwin.ipet",
  "type": "1"
}
```

**curl 示例:**

```bash
curl -s http://localhost:8002/user/app/check -X POST \
  -d "version=1.0.0&packageName=com.granwin.ipet&type=1"
```

**响应:** `code: 3030` 商户App应用不存在

```json
{
  "code": 3030,
  "tip": "商户App应用不存在"
}
```

---

### 1.13 POST /user/message/config/get — 获取推送配置 ✅

> **认证**: 需Token

**请求参数:**

无参数

**curl 示例:**

```bash
curl -s http://localhost:8002/user/message/config/get -X POST \
  -H "token: $TOKEN"
```

**响应:** `code: 0` 响应成功

```json
{
  "code": 0,
  "info": {
    "devicePushMsg": 0,
    "deviceShareMsg": 0,
    "promoteMsg": 0,
    "systemMsg": 0,
    "updateTime": 1779688381779,
    "userId": 1218767262805061632
  },
  "tip": "响应成功"
}
```

---

### 1.14 POST /user/message/config/save — 保存推送配置 ✅

> **认证**: 需Token

**请求参数:**

| 参数 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `devicePushMsg` | String | `1` | |
| `promoteMsg` | String | `0` | |
| `systenMsg` | String | `1` | |
| `deviceShareMsg` | String | `1` | |

```json
{
  "devicePushMsg": "1",
  "promoteMsg": "0",
  "systenMsg": "1",
  "deviceShareMsg": "1"
}
```

**curl 示例:**

```bash
curl -s http://localhost:8002/user/message/config/save -X POST \
  -H "token: $TOKEN" \
  -d "devicePushMsg=1&promoteMsg=0&systenMsg=1&deviceShareMsg=1"
```

**响应:** `code: 0` 响应成功

```json
{
  "code": 0,
  "tip": "响应成功"
}
```

---

### 1.15 POST /user/mobile/set — 注册移动端推送 ✅

> **认证**: 需Token

**请求参数:**

| 参数 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `token` | String | `fcm-test-688365` | |
| `channel` | String | `fcm` | |
| `status` | String | `1` | |

```json
{
  "token": "fcm-test-688365",
  "channel": "fcm",
  "status": "1"
}
```

**curl 示例:**

```bash
curl -s http://localhost:8002/user/mobile/set -X POST \
  -H "token: $TOKEN" \
  -d "token=fcm-test-688365&channel=fcm&status=1"
```

**响应:** `code: 0` 响应成功

```json
{
  "code": 0,
  "tip": "响应成功"
}
```

---

### 1.16 POST /user/update/sub — 更新订阅配置 ✅

> **认证**: 需Token

**请求参数:**

| 参数 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `deviceFaultSub` | String | `true` | |
| `deviceOfflineSub` | String | `true` | |
| `taskCreateSub` | String | `true` | |
| `taskCompletionSub` | String | `true` | |

```json
{
  "deviceFaultSub": "true",
  "deviceOfflineSub": "true",
  "taskCreateSub": "true",
  "taskCompletionSub": "true"
}
```

**curl 示例:**

```bash
curl -s http://localhost:8002/user/update/sub -X POST \
  -H "token: $TOKEN" \
  -d "deviceFaultSub=true&deviceOfflineSub=true&taskCreateSub=true&taskCompletionSub=true"
```

**响应:** `code: 0` 响应成功

```json
{
  "code": 0,
  "tip": "响应成功"
}
```

---

## 2. 用户设备模块

### 2.1 POST /user/device/bind — 绑定设备 ✅

> **认证**: 需Token

**请求参数:**

| 参数 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `mac` | String | `ipet-esp32-Device-02` | |
| `deviceNickName` | String | `TestDev02` | |

```json
{
  "mac": "ipet-esp32-Device-02",
  "deviceNickName": "TestDev02"
}
```

**curl 示例:**

```bash
curl -s http://localhost:8002/user/device/bind -X POST \
  -H "token: $TOKEN" \
  -d "mac=ipet-esp32-Device-02&deviceNickName=TestDev02"
```

**响应:** `code: 0` 响应成功

```json
{
  "code": 0,
  "info": {
    "appuserId": "1218767262805061632",
    "connect": true,
    "createTime": 1779688383180,
    "deviceId": "1218761715930296320",
    "deviceNickname": "TestDev02",
    "mac": "ipet-esp32-Device-02",
    "productId": "1",
    "productKey": "PK_IPET_ESP32",
    "sharer": "0",
    "uType": "1",
    "updateTime": 1779688383180
  },
  "tip": "响应成功"
}
```

---

### 2.2 POST /user/device/list — 设备列表 ✅

> **认证**: 需Token

**请求参数:**

无参数

**curl 示例:**

```bash
curl -s http://localhost:8002/user/device/list -X POST \
  -H "token: $TOKEN"
```

**响应:** `code: 0` 响应成功

```json
{
  "code": 0,
  "info": [
    {
      "productKey": "PK_IPET_ESP32",
      "deviceId": "1218761715930296320",
      "mac": "ipet-esp32-Device-02",
      "sharer": "0",
      "uType": "1",
      "alias": "ipet-esp32",
      "connect": true,
      "deviceNickname": "TestDev02",
      "productId": "1",
      "updateTime": 1779688383180,
      "appuserId": "1218767262805061632",
      "createTime": 1779688383180
    }
  ],
  "tip": "响应成功"
}
```

---

### 2.3 POST /user/device/own/devices — 拥有的设备 ✅

> **认证**: 需Token

**请求参数:**

无参数

**curl 示例:**

```bash
curl -s http://localhost:8002/user/device/own/devices -X POST \
  -H "token: $TOKEN"
```

**响应:** `code: 0` 响应成功

```json
{
  "code": 0,
  "info": [
    {
      "nickName": "TestDev02",
      "count": 0,
      "time": 1779688383180,
      "type": "1",
      "deviceId": "1218761715930296320",
      "mac": "ipet-esp32-Device-02"
    }
  ],
  "tip": "响应成功"
}
```

---

### 2.4 POST /user/device/detail — 设备详情 ✅

> **认证**: 需Token

**请求参数:**

| 参数 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `mac` | String | `ipet-esp32-Device-02` | |

```json
{
  "mac": "ipet-esp32-Device-02"
}
```

**curl 示例:**

```bash
curl -s http://localhost:8002/user/device/detail -X POST \
  -H "token: $TOKEN" \
  -d "mac=ipet-esp32-Device-02"
```

**响应:** `code: 0` 响应成功

```json
{
  "code": 0,
  "info": {
    "productId": 1,
    "onlineStatus": true,
    "deviceNickName": "TestDev02",
    "remark": "[2026-05-25 13:30:46]设备已被重新配网旧->id[1218075289007661057]",
    "updateTime": 1779687046801,
    "productKey": "PK_IPET_ESP32",
    "mac": "ipet-esp32-Device-02",
    "deleted": 0,
    "createTime": 1779682434678,
    "merchantId": 1,
    "updateBy": 1218761339260825600,
    "name": "TestDev02",
    "lastOnlineTime": 1779688369258,
    "id": 1218761715930296320,
    "status": 1
  },
  "tip": "响应成功"
}
```

---

### 2.5 GET /user/device/online/state — 设备在线状态(GET) ✅

> **认证**: 需Token

**请求参数:**

| 参数 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `mac` | String | `ipet-esp32-Device-02` | |

```json
{
  "mac": "ipet-esp32-Device-02"
}
```

**curl 示例:**

```bash
curl -s http://localhost:8002/user/device/online/state -X GET \
  -H "token: $TOKEN" \
  -d "mac=ipet-esp32-Device-02"
```

**响应:** `code: 0` 响应成功

```json
{
  "code": 0,
  "info": {
    "onlineState": true
  },
  "tip": "响应成功"
}
```

---

### 2.6 POST /user/device/update — 更新设备信息 ✅

> **认证**: 需Token

**请求参数:**

| 参数 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `mac` | String | `ipet-esp32-Device-02` | |
| `deviceNickName` | String | `TestDev02-Updated` | |

```json
{
  "mac": "ipet-esp32-Device-02",
  "deviceNickName": "TestDev02-Updated"
}
```

**curl 示例:**

```bash
curl -s http://localhost:8002/user/device/update -X POST \
  -H "token: $TOKEN" \
  -d "mac=ipet-esp32-Device-02&deviceNickName=TestDev02-Updated"
```

**响应:** `code: 0` 响应成功

```json
{
  "code": 0,
  "tip": "响应成功"
}
```

---

### 2.7 POST /user/device/share/withme — 共享给我的设备 ✅

> **认证**: 需Token

**请求参数:**

无参数

**curl 示例:**

```bash
curl -s http://localhost:8002/user/device/share/withme -X POST \
  -H "token: $TOKEN"
```

**响应:** `code: 0` 响应成功

```json
{
  "code": 0,
  "info": [],
  "tip": "响应成功"
}
```

---

### 2.8 POST /user/device/member/query — 设备成员查询 ✅

> **认证**: 免登录

**请求参数:**

| 参数 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `mac` | String | `ipet-esp32-Device-02` | |

```json
{
  "mac": "ipet-esp32-Device-02"
}
```

**curl 示例:**

```bash
curl -s http://localhost:8002/user/device/member/query -X POST \
  -d "mac=ipet-esp32-Device-02"
```

**响应:** `code: 0` 响应成功

```json
{
  "code": 0,
  "info": [
    {
      "createTime": 1779688383180,
      "type": "1",
      "userId": 1218767262805061632,
      "account": "apitest688365@test.com",
      "mac": "ipet-esp32-Device-02",
      "username": "ApiTester"
    }
  ],
  "tip": "响应成功"
}
```

---

### 2.9 POST /user/device/mcuota/get — MCU OTA信息 ✅

> **认证**: 需Token

**请求参数:**

| 参数 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `mac` | String | `ipet-esp32-Device-02` | |

```json
{
  "mac": "ipet-esp32-Device-02"
}
```

**curl 示例:**

```bash
curl -s http://localhost:8002/user/device/mcuota/get -X POST \
  -H "token: $TOKEN" \
  -d "mac=ipet-esp32-Device-02"
```

**响应:** `code: 0` 响应成功

```json
{
  "code": 0,
  "info": {
    "msg": "没有新版本",
    "isUpgrade": false,
    "deviceId": 1218761715930296320,
    "mac": "ipet-esp32-Device-02",
    "currentVersion": "default",
    "msgCode": "OTA_MCU_000"
  },
  "tip": "响应成功"
}
```

---

### 2.10 POST /user/device/mcuota/query — MCU OTA查询 ✅

> **认证**: 需Token

**请求参数:**

| 参数 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `upgradeId` | String | `999999` | |

```json
{
  "upgradeId": "999999"
}
```

**curl 示例:**

```bash
curl -s http://localhost:8002/user/device/mcuota/query -X POST \
  -H "token: $TOKEN" \
  -d "upgradeId=999999"
```

**响应:** `code: 2324` 设备升级信息不存在或无效

```json
{
  "code": 2324,
  "tip": "设备升级信息不存在或无效"
}
```

---

### 2.11 POST /user/device/share/cancel/list — 取消分享列表 ✅

> **认证**: 需Token

**请求参数:**

无参数

**curl 示例:**

```bash
curl -s http://localhost:8002/user/device/share/cancel/list -X POST \
  -H "token: $TOKEN"
```

**响应:** `code: 1` 查询取消分享设备列表失败

```json
{
  "code": 1,
  "tip": "查询取消分享设备列表失败"
}
```

---

### 2.12 POST /user/device/get/bdevice — 蓝牙子设备 ✅

> **认证**: 需Token

**请求参数:**

| 参数 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `mac` | String | `ipet-esp32-Device-02` | |

```json
{
  "mac": "ipet-esp32-Device-02"
}
```

**curl 示例:**

```bash
curl -s http://localhost:8002/user/device/get/bdevice -X POST \
  -H "token: $TOKEN" \
  -d "mac=ipet-esp32-Device-02"
```

**响应:** `code: 0` 响应成功

```json
{
  "code": 0,
  "info": [],
  "tip": "响应成功"
}
```

---

### 2.13 POST /user/device/get/city — 获取城市 ✅

> **认证**: 需Token

**请求参数:**

| 参数 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `longitude` | String | `113.946` | |
| `latitude` | String | `22.547` | |

```json
{
  "longitude": "113.946",
  "latitude": "22.547"
}
```

**curl 示例:**

```bash
curl -s http://localhost:8002/user/device/get/city -X POST \
  -H "token: $TOKEN" \
  -d "longitude=113.946&latitude=22.547"
```

**响应:** `code: 1` 经度或纬度不能为空

```json
{
  "code": 1,
  "tip": "经度或纬度不能为空"
}
```

---

### 2.14 POST /user/device/weather — 设备天气 ✅

> **认证**: 需Token

**请求参数:**

| 参数 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `mac` | String | `ipet-esp32-Device-02` | |

```json
{
  "mac": "ipet-esp32-Device-02"
}
```

**curl 示例:**

```bash
curl -s http://localhost:8002/user/device/weather -X POST \
  -H "token: $TOKEN" \
  -d "mac=ipet-esp32-Device-02"
```

**响应:** `code: 1` 当前设备未绑定经纬度

```json
{
  "code": 1,
  "tip": "当前设备未绑定经纬度"
}
```

---

### 2.15 POST /user/device/update/location — 更新设备位置 ✅

> **认证**: 需Token

**请求参数:**

| 参数 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `mac` | String | `ipet-esp32-Device-02` | |
| `longitude` | String | `113.946` | |
| `latitude` | String | `22.547` | |

```json
{
  "mac": "ipet-esp32-Device-02",
  "longitude": "113.946",
  "latitude": "22.547"
}
```

**curl 示例:**

```bash
curl -s http://localhost:8002/user/device/update/location -X POST \
  -H "token: $TOKEN" \
  -d "mac=ipet-esp32-Device-02&longitude=113.946&latitude=22.547"
```

**响应:** `code: 1` 用户无权限操作该设备

```json
{
  "code": 1,
  "tip": "用户无权限操作该设备"
}
```

---

## 3. 设备模块

### 3.1 POST /device/product/list — 产品列表 ✅

> **认证**: 需Token

**请求参数:**

无参数

**curl 示例:**

```bash
curl -s http://localhost:8002/device/product/list -X POST \
  -H "token: $TOKEN"
```

**响应:** `code: 0` 响应成功

```json
{
  "code": 0,
  "list": [
    {
      "alias": "ipet-esp32",
      "createBy": 1,
      "createTime": 1778331215198,
      "createUser": {
        "account": "admin",
        "createBy": 1,
        "createTime": 1777801763000,
        "deleted": 0,
        "email": "admin@granwin.com",
        "id": 1,
        "lastLoginTime": 1778816760513,
        "level": 1,
        "merchantId": 100000000000000000,
        "merchantName": "平台",
        "name": "系统管理员",
        "phone": "13800000001",
        "roleId": 1,
        "roleName": "超级管理员",
        "status": 1,
        "type": 1
      },
      "deleted": 0,
      "id": 1,
      "merchantId": 1,
      "merchantName": "平台",
      "name": "iPet ESP32 智能宠物设备",
      "productKey": "PK_IPET_ESP32",
      "productTypeName": "智能宠物设备",
      "status": 1,
      "updateBy": 1,
      "updateTime": 1778331215198
  ...
}
```

---

### 3.2 POST /device/product/tree — 产品分类树 ✅

> **认证**: 需Token

**请求参数:**

无参数

**curl 示例:**

```bash
curl -s http://localhost:8002/device/product/tree -X POST \
  -H "token: $TOKEN"
```

**响应:** `code: 0` 响应成功

```json
{
  "code": 0,
  "info": [
    {
      "children": [
        {
          "createBy": 1,
          "createTime": 1778227343839,
          "deleted": 0,
          "id": 2,
          "level": 2,
          "name": "喂食器",
          "parentId": 1,
          "status": 1
        },
        {
          "createBy": 1,
          "createTime": 1778227343839,
          "deleted": 0,
          "id": 3,
          "level": 2,
          "name": "饮水机",
          "parentId": 1,
          "status": 1
        },
        {
          "createBy": 1,
          "createTime": 1778227343839,
          "deleted": 0,
          "id": 4,
          "level": 2,
          "name": "摄像头",
          "parentId": 1,
          "status": 1
        }
  ...
}
```

---

### 3.3 POST /device/category/list — 品类列表 ✅

> **认证**: 需Token

**请求参数:**

无参数

**curl 示例:**

```bash
curl -s http://localhost:8002/device/category/list -X POST \
  -H "token: $TOKEN"
```

**响应:** `code: 0` 响应成功

```json
{
  "code": 0,
  "list": [
    {
      "createBy": 1,
      "createTime": 1778227343839,
      "deleted": 0,
      "id": 2,
      "level": 2,
      "name": "喂食器",
      "parentId": 1,
      "status": 1
    },
    {
      "createBy": 1,
      "createTime": 1778227343839,
      "deleted": 0,
      "id": 3,
      "level": 2,
      "name": "饮水机",
      "parentId": 1,
      "status": 1
    },
    {
      "createBy": 1,
      "createTime": 1778227343839,
      "deleted": 0,
      "id": 4,
      "level": 2,
      "name": "摄像头",
      "parentId": 1,
      "status": 1
    }
  ],
  "pageTurn": {
  ...
}
```

---

### 3.4 POST /device/point/list — 功能点列表 ✅

> **认证**: 需Token

**请求参数:**

| 参数 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `mac` | String | `ipet-esp32-Device-02` | |

```json
{
  "mac": "ipet-esp32-Device-02"
}
```

**curl 示例:**

```bash
curl -s http://localhost:8002/device/point/list -X POST \
  -H "token: $TOKEN" \
  -d "mac=ipet-esp32-Device-02"
```

**响应:** `code: 0` 响应成功

```json
{
  "code": 0,
  "info": [
    {
      "createBy": 1,
      "createTime": 1778669678263,
      "deleted": 0,
      "id": 1,
      "markName": "led_r",
      "pointName": "红色LED",
      "pointType": 1,
      "productId": 1,
      "readType": 2,
      "status": 1,
      "updateBy": 1,
      "updateTime": 1778669678263
    },
    {
      "createBy": 1,
      "createTime": 1778669678263,
      "deleted": 0,
      "id": 2,
      "markName": "brightness_r",
      "maxValue": "100",
      "minValue": "0",
      "pointName": "红色亮度",
      "pointType": 2,
      "productId": 1,
      "readType": 2,
      "status": 1,
      "updateBy": 1,
      "updateTime": 1778669678263
    },
    {
      "createBy": 1,
  ...
}
```

---

### 3.5 POST /device/bind/parameter — 绑定参数 ✅

> **认证**: 需Token

**请求参数:**

| 参数 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `mac` | String | `ipet-esp32-Device-02` | |

```json
{
  "mac": "ipet-esp32-Device-02"
}
```

**curl 示例:**

```bash
curl -s http://localhost:8002/device/bind/parameter -X POST \
  -H "token: $TOKEN" \
  -d "mac=ipet-esp32-Device-02"
```

**响应:** `code: 0` 响应成功

```json
{
  "code": 0,
  "info": {
    "p": "",
    "r": "",
    "s": "8fR40a"
  },
  "tip": "响应成功"
}
```

---

### 3.6 POST /device/property/query — 查询设备属性 ✅

> **认证**: 需Token

**请求参数:**

| 参数 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `mac` | String | `ipet-esp32-Device-02` | |

```json
{
  "mac": "ipet-esp32-Device-02"
}
```

**curl 示例:**

```bash
curl -s http://localhost:8002/device/property/query -X POST \
  -H "token: $TOKEN" \
  -d "mac=ipet-esp32-Device-02"
```

**响应:** `code: 0` 响应成功

```json
{
  "code": 0,
  "info": {
    "reportDataTime": 0
  },
  "tip": "响应成功"
}
```

---

### 3.7 POST /device/property/querybatch — 批量查询属性 ✅

> **认证**: 需Token

**请求参数:**

| 参数 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `macs` | String | `ipet-esp32-Device-02` | |

```json
{
  "macs": "ipet-esp32-Device-02"
}
```

**curl 示例:**

```bash
curl -s http://localhost:8002/device/property/querybatch -X POST \
  -H "token: $TOKEN" \
  -d "macs=ipet-esp32-Device-02"
```

**响应:** `code: 1001` 请选择设备

```json
{
  "code": 1001,
  "tip": "请选择设备"
}
```

---

### 3.8 POST /device/message — 设备消息列表 ✅

> **认证**: 需Token

**请求参数:**

| 参数 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `mac` | String | `ipet-esp32-Device-02` | |

```json
{
  "mac": "ipet-esp32-Device-02"
}
```

**curl 示例:**

```bash
curl -s http://localhost:8002/device/message -X POST \
  -H "token: $TOKEN" \
  -d "mac=ipet-esp32-Device-02"
```

**响应:** `code: 1` 查询设备消息失败

```json
{
  "code": 1,
  "tip": "查询设备消息失败"
}
```

---

### 3.9 GET /device/mac/message — MAC消息查询(GET) ✅

> **认证**: 需Token

**请求参数:**

| 参数 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `mac` | String | `ipet-esp32-Device-02` | |

```json
{
  "mac": "ipet-esp32-Device-02"
}
```

**curl 示例:**

```bash
curl -s http://localhost:8002/device/mac/message -X GET \
  -H "token: $TOKEN" \
  -d "mac=ipet-esp32-Device-02"
```

**响应:** `code: 0` 响应成功

```json
{
  "code": 0,
  "info": {
    "count": 0,
    "results": [],
    "scannedCount": 0
  },
  "tip": "响应成功"
}
```

---

### 3.10 POST /device/delete/message — 删除消息 ✅

> **认证**: 需Token

**请求参数:**

| 参数 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `ids` | String | `[]` | |

```json
{
  "ids": "[]"
}
```

**curl 示例:**

```bash
curl -s http://localhost:8002/device/delete/message -X POST \
  -H "token: $TOKEN" \
  -d "ids=[]"
```

**响应:** `code: 1001` 列表不能为空

```json
{
  "code": 1001,
  "tip": "列表不能为空"
}
```

---

## 4. 宠物信息模块

### 4.1 POST /pet/info/add — 添加宠物 ✅

> **认证**: 需Token

**请求参数:**

| 参数 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `petName` | String | `Lucky_688365` | |
| `mac` | String | `ipet-esp32-Device-02` | |
| `breed` | String | `GoldenRetriever` | |
| `age` | String | `3` | |
| `weight` | String | `25.5` | |
| `sex` | String | `GG` | |

```json
{
  "petName": "Lucky_688365",
  "mac": "ipet-esp32-Device-02",
  "breed": "GoldenRetriever",
  "age": "3",
  "weight": "25.5",
  "sex": "GG"
}
```

**curl 示例:**

```bash
curl -s http://localhost:8002/pet/info/add -X POST \
  -H "token: $TOKEN" \
  -d "petName=Lucky_688365&mac=ipet-esp32-Device-02&breed=GoldenRetriever&age=3&weight=25.5&sex=GG"
```

**响应:** `code: 0` 响应成功

```json
{
  "code": 0,
  "tip": "响应成功"
}
```

---

### 4.2 POST /pet/info/get — 获取宠物信息 ✅

> **认证**: 需Token

**请求参数:**

| 参数 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `mac` | String | `ipet-esp32-Device-02` | |

```json
{
  "mac": "ipet-esp32-Device-02"
}
```

**curl 示例:**

```bash
curl -s http://localhost:8002/pet/info/get -X POST \
  -H "token: $TOKEN" \
  -d "mac=ipet-esp32-Device-02"
```

**响应:** `code: 0` 响应成功

```json
{
  "code": 0,
  "info": {
    "age": 3,
    "breed": "GoldenRetriever",
    "createTime": 1779688400100,
    "deviceId": 1218761715930296320,
    "petId": 1218767392077705216,
    "petName": "Lucky_688365",
    "sex": "GG",
    "userId": 1218767262805061632,
    "weight": "25.5"
  },
  "tip": "响应成功"
}
```

---

### 4.3 POST /pet/info/update — 更新宠物信息 ✅

> **认证**: 需Token

**请求参数:**

| 参数 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `petId` | String | `1218767392077705216` | |
| `petName` | String | `Lucky_Updated` | |
| `age` | String | `4` | |
| `sex` | String | `DD` | |

```json
{
  "petId": "1218767392077705216",
  "petName": "Lucky_Updated",
  "age": "4",
  "sex": "DD"
}
```

**curl 示例:**

```bash
curl -s http://localhost:8002/pet/info/update -X POST \
  -H "token: $TOKEN" \
  -d "petId=1218767392077705216&petName=Lucky_Updated&age=4&sex=DD"
```

**响应:** `code: 0` 响应成功

```json
{
  "code": 0,
  "tip": "响应成功"
}
```

---

## 5. 宠物围栏模块

### 5.1 POST /pet/fence/add — 添加围栏 ✅

> **认证**: 需Token

**请求参数:**

| 参数 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `fenceName` | String | `Home_688365` | |
| `mac` | String | `ipet-esp32-Device-02` | |
| `longitude` | String | `113.946` | |
| `latitude` | String | `22.547` | |
| `radius` | String | `200` | |
| `address` | String | `Test Address` | |
| `coordinateType` | String | `wgs84` | |

```json
{
  "fenceName": "Home_688365",
  "mac": "ipet-esp32-Device-02",
  "longitude": "113.946",
  "latitude": "22.547",
  "radius": "200",
  "address": "Test Address",
  "coordinateType": "wgs84"
}
```

**curl 示例:**

```bash
curl -s http://localhost:8002/pet/fence/add -X POST \
  -H "token: $TOKEN" \
  -d "fenceName=Home_688365&mac=ipet-esp32-Device-02&longitude=113.946&latitude=22.547&radius=200&address=Test Address&coordin"
```

**响应:** `code: 0` 响应成功

```json
{
  "code": 0,
  "tip": "响应成功"
}
```

---

### 5.2 POST /pet/fence/list — 围栏列表 ✅

> **认证**: 需Token

**请求参数:**

| 参数 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `mac` | String | `ipet-esp32-Device-02` | |

```json
{
  "mac": "ipet-esp32-Device-02"
}
```

**curl 示例:**

```bash
curl -s http://localhost:8002/pet/fence/list -X POST \
  -H "token: $TOKEN" \
  -d "mac=ipet-esp32-Device-02"
```

**响应:** `code: 0` 响应成功

```json
{
  "code": 0,
  "list": [
    {
      "address": "Test Address",
      "bd09Latitude": "22.549699340567805",
      "bd09Longitude": "113.95742277851583",
      "createTime": 1779688400160,
      "deviceId": 1218761715930296320,
      "fenceId": 1218767392329363456,
      "fenceName": "Home_688365",
      "gcj02Latitude": "22.543990088422582",
      "gcj02Longitude": "113.9508804155239",
      "latitude": "22.547",
      "longitude": "113.946",
      "radius": "200",
      "wsg84Latitude": "22.547",
      "wsg84Longitude": "113.946"
    }
  ],
  "tip": "响应成功"
}
```

---

### 5.3 POST /pet/fence/update — 更新围栏 ✅

> **认证**: 需Token

**请求参数:**

| 参数 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `fenceId` | String | `1218767392329363456` | |
| `fenceName` | String | `Home_Updated` | |
| `radius` | String | `300` | |
| `longitude` | String | `113.946` | |
| `latitude` | String | `22.547` | |
| `address` | String | `Updated` | |
| `coordinateType` | String | `wgs84` | |

```json
{
  "fenceId": "1218767392329363456",
  "fenceName": "Home_Updated",
  "radius": "300",
  "longitude": "113.946",
  "latitude": "22.547",
  "address": "Updated",
  "coordinateType": "wgs84"
}
```

**curl 示例:**

```bash
curl -s http://localhost:8002/pet/fence/update -X POST \
  -H "token: $TOKEN" \
  -d "fenceId=1218767392329363456&fenceName=Home_Updated&radius=300&longitude=113.946&latitude=22.547&address=Updated&coordina"
```

**响应:** `code: 0` 响应成功

```json
{
  "code": 0,
  "tip": "响应成功"
}
```

---

### 5.4 POST /pet/fence/del — 删除围栏 ✅

> **认证**: 需Token

**请求参数:**

| 参数 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `fenceId` | String | `1218767392329363456` | |

```json
{
  "fenceId": "1218767392329363456"
}
```

**curl 示例:**

```bash
curl -s http://localhost:8002/pet/fence/del -X POST \
  -H "token: $TOKEN" \
  -d "fenceId=1218767392329363456"
```

**响应:** `code: 0` 响应成功

```json
{
  "code": 0,
  "tip": "响应成功"
}
```

---

## 6. 应用模块

### 6.1 POST /app/advertising — 获取广告 ✅

> **认证**: 需Token

**请求参数:**

| 参数 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `merchantId` | String | `1` | |

```json
{
  "merchantId": "1"
}
```

**curl 示例:**

```bash
curl -s http://localhost:8002/app/advertising -X POST \
  -H "token: $TOKEN" \
  -d "merchantId=1"
```

**响应:** `code: 0` 响应成功

```json
{
  "code": 0,
  "info": [],
  "tip": "响应成功"
}
```

---

### 6.2 POST /app/open/advertising — 开屏广告(免登录) ✅

> **认证**: 免登录

**请求参数:**

| 参数 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `merchantId` | String | `1` | |

```json
{
  "merchantId": "1"
}
```

**curl 示例:**

```bash
curl -s http://localhost:8002/app/open/advertising -X POST \
  -d "merchantId=1"
```

**响应:** `code: 0` 响应成功

```json
{
  "code": 0,
  "info": [],
  "tip": "响应成功"
}
```

---

### 6.3 POST /app/network/get — 配网说明 ✅

> **认证**: 需Token

**请求参数:**

| 参数 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `mac` | String | `ipet-esp32-Device-02` | |
| `productId` | String | `1` | |

```json
{
  "mac": "ipet-esp32-Device-02",
  "productId": "1"
}
```

**curl 示例:**

```bash
curl -s http://localhost:8002/app/network/get -X POST \
  -H "token: $TOKEN" \
  -d "mac=ipet-esp32-Device-02&productId=1"
```

**响应:** `code: 0` 响应成功

```json
{
  "code": 0,
  "info": {},
  "tip": "响应成功"
}
```

---

### 6.4 POST /app/product/list — App产品列表 ✅

> **认证**: 需Token

**请求参数:**

无参数

**curl 示例:**

```bash
curl -s http://localhost:8002/app/product/list -X POST \
  -H "token: $TOKEN"
```

**响应:** `code: 0` 响应成功

```json
{
  "code": 0,
  "list": [
    {
      "alias": "ipet-esp32",
      "createBy": 1,
      "createTime": 1778331215198,
      "createUser": {
        "account": "admin",
        "createBy": 1,
        "createTime": 1777801763000,
        "deleted": 0,
        "email": "admin@granwin.com",
        "id": 1,
        "lastLoginTime": 1778816760513,
        "level": 1,
        "merchantId": 100000000000000000,
        "merchantName": "平台",
        "name": "系统管理员",
        "phone": "13800000001",
        "roleId": 1,
        "roleName": "超级管理员",
        "status": 1,
        "type": 1
      },
      "deleted": 0,
      "id": 1,
      "merchantId": 1,
      "merchantName": "平台",
      "name": "iPet ESP32 智能宠物设备",
      "productKey": "PK_IPET_ESP32",
      "productTypeName": "智能宠物设备",
      "status": 1,
      "updateBy": 1,
      "updateTime": 1778331215198
  ...
}
```

---

### 6.5 POST /app/public/product/list — 公开产品列表(免登录) ✅

> **认证**: 免登录

**请求参数:**

| 参数 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `merchantId` | String | `1` | |

```json
{
  "merchantId": "1"
}
```

**curl 示例:**

```bash
curl -s http://localhost:8002/app/public/product/list -X POST \
  -d "merchantId=1"
```

**响应:** `code: 0` 响应成功

```json
{
  "code": 0,
  "list": [
    {
      "alias": "ipet-esp32",
      "createBy": 1,
      "createTime": 1778331215198,
      "createUser": {
        "account": "admin",
        "createBy": 1,
        "createTime": 1777801763000,
        "deleted": 0,
        "email": "admin@granwin.com",
        "id": 1,
        "lastLoginTime": 1778816760513,
        "level": 1,
        "merchantId": 100000000000000000,
        "merchantName": "平台",
        "name": "系统管理员",
        "phone": "13800000001",
        "roleId": 1,
        "roleName": "超级管理员",
        "status": 1,
        "type": 1
      },
      "deleted": 0,
      "id": 1,
      "merchantId": 1,
      "merchantName": "平台",
      "name": "iPet ESP32 智能宠物设备",
      "productKey": "PK_IPET_ESP32",
      "productTypeName": "智能宠物设备",
      "status": 1,
      "updateBy": 1,
      "updateTime": 1778331215198
  ...
}
```

---

### 6.6 POST /app/app/version — App版本检查(旧) ✅

> **认证**: 免登录

**请求参数:**

| 参数 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `version` | String | `1.0.0` | |
| `packageName` | String | `com.granwin.ipet` | |
| `type` | String | `1` | |

```json
{
  "version": "1.0.0",
  "packageName": "com.granwin.ipet",
  "type": "1"
}
```

**curl 示例:**

```bash
curl -s http://localhost:8002/app/app/version -X POST \
  -d "version=1.0.0&packageName=com.granwin.ipet&type=1"
```

**响应:** `code: 0` 响应成功

```json
{
  "code": 0,
  "tip": "响应成功"
}
```

---

## 7. 消息模块

### 7.1 POST /app/message/list — 已读消息列表 ✅

> **认证**: 需Token

**请求参数:**

| 参数 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `messageIds` | String | `["1"]` | |

```json
{
  "messageIds": "[\"1\"]"
}
```

**curl 示例:**

```bash
curl -s http://localhost:8002/app/message/list -X POST \
  -H "token: $TOKEN" \
  -d "messageIds=["1"]"
```

**响应:** `code: 1` 获取消息列表失败

```json
{
  "code": 1,
  "tip": "获取消息列表失败"
}
```

---

### 7.2 POST /app/message/cnt — 未读消息计数 ✅

> **认证**: 需Token

**请求参数:**

无参数

**curl 示例:**

```bash
curl -s http://localhost:8002/app/message/cnt -X POST \
  -H "token: $TOKEN"
```

**响应:** `code: 1` 获取消息计数信息失败

```json
{
  "code": 1,
  "tip": "获取消息计数信息失败"
}
```

---

### 7.3 POST /app/message/check — 检查新消息 ✅

> **认证**: 需Token

**请求参数:**

无参数

**curl 示例:**

```bash
curl -s http://localhost:8002/app/message/check -X POST \
  -H "token: $TOKEN"
```

**响应:** `code: 1` 响应失败

```json
{
  "code": 1,
  "tip": "响应失败"
}
```

---

### 7.4 POST /app/message/add — 标记消息已读 ✅

> **认证**: 需Token

**请求参数:**

| 参数 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `messageId` | String | `1` | |
| `type` | String | `1` | |

```json
{
  "messageId": "1",
  "type": "1"
}
```

**curl 示例:**

```bash
curl -s http://localhost:8002/app/message/add -X POST \
  -H "token: $TOKEN" \
  -d "messageId=1&type=1"
```

**响应:** `code: 1` 插入消息失败

```json
{
  "code": 1,
  "tip": "插入消息失败"
}
```

---

### 7.5 POST /app/message/all/read — 全部标记已读 ✅

> **认证**: 需Token

**请求参数:**

| 参数 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `type` | String | `1` | |

```json
{
  "type": "1"
}
```

**curl 示例:**

```bash
curl -s http://localhost:8002/app/message/all/read -X POST \
  -H "token: $TOKEN" \
  -d "type=1"
```

**响应:** `code: 1` 批量插入消息失败

```json
{
  "code": 1,
  "tip": "批量插入消息失败"
}
```

---

## 8. 用户反馈模块

### 8.1 POST /app/user/feedback/add — 添加用户反馈 ✅

> **认证**: 需Token

**请求参数:**

| 参数 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `type` | String | `1` | |
| `source` | String | `1` | |
| `remark` | String | `Test feedback` | |

```json
{
  "type": "1",
  "source": "1",
  "remark": "Test feedback"
}
```

**curl 示例:**

```bash
curl -s http://localhost:8002/app/user/feedback/add -X POST \
  -H "token: $TOKEN" \
  -d "type=1&source=1&remark=Test feedback"
```

**响应:** `code: 0` 响应成功

```json
{
  "code": 0,
  "tip": "响应成功"
}
```

---

### 8.2 POST /app/user/feedback/grade — 设备评分 ✅

> **认证**: 需Token

**请求参数:**

| 参数 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `deviceId` | String | `1` | |
| `grade` | String | `5` | |
| `source` | String | `1` | |

```json
{
  "deviceId": "1",
  "grade": "5",
  "source": "1"
}
```

**curl 示例:**

```bash
curl -s http://localhost:8002/app/user/feedback/grade -X POST \
  -H "token: $TOKEN" \
  -d "deviceId=1&grade=5&source=1"
```

**响应:** `code: 12021` 设备不存在

```json
{
  "code": 12021,
  "tip": "设备不存在"
}
```

---

## 9. 数据中心模块

### 9.1 POST /data/center/help/list — 帮助列表 ✅

> **认证**: 需Token

**请求参数:**

| 参数 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `merchantId` | String | `1` | |

```json
{
  "merchantId": "1"
}
```

**curl 示例:**

```bash
curl -s http://localhost:8002/data/center/help/list -X POST \
  -H "token: $TOKEN" \
  -d "merchantId=1"
```

**响应:** `code: 1` 请选择设备

```json
{
  "code": 1,
  "tip": "请选择设备"
}
```

---

### 9.2 POST /data/center/service/list — 服务条款 ✅

> **认证**: 免登录

**请求参数:**

| 参数 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `merchantId` | String | `1` | |

```json
{
  "merchantId": "1"
}
```

**curl 示例:**

```bash
curl -s http://localhost:8002/data/center/service/list -X POST \
  -d "merchantId=1"
```

**响应:** `code: 0` 响应成功

```json
{
  "code": 0,
  "info": [],
  "tip": "响应成功"
}
```

---

### 9.3 POST /data/center/app/help — 应用帮助 ✅

> **认证**: 需Token

**请求参数:**

| 参数 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `merchantId` | String | `1` | |

```json
{
  "merchantId": "1"
}
```

**curl 示例:**

```bash
curl -s http://localhost:8002/data/center/app/help -X POST \
  -H "token: $TOKEN" \
  -d "merchantId=1"
```

**响应:** `code: 0` 响应成功

```json
{
  "code": 0,
  "info": [],
  "tip": "响应成功"
}
```

---

### 9.4 POST /data/center/privacy/list — 隐私政策 ✅

> **认证**: 免登录

**请求参数:**

| 参数 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `merchantId` | String | `1` | |

```json
{
  "merchantId": "1"
}
```

**curl 示例:**

```bash
curl -s http://localhost:8002/data/center/privacy/list -X POST \
  -d "merchantId=1"
```

**响应:** `code: 0` 响应成功

```json
{
  "code": 0,
  "info": [],
  "tip": "响应成功"
}
```

---

### 9.5 POST /data/center/about/list — 关于我们 ✅

> **认证**: 免登录

**请求参数:**

| 参数 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `merchantId` | String | `1` | |

```json
{
  "merchantId": "1"
}
```

**curl 示例:**

```bash
curl -s http://localhost:8002/data/center/about/list -X POST \
  -d "merchantId=1"
```

**响应:** `code: 0` 响应成功

```json
{
  "code": 0,
  "info": [],
  "tip": "响应成功"
}
```

---

### 9.6 POST /data/center/get/content — 内容详情 ✅

> **认证**: 需Token

**请求参数:**

| 参数 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `id` | String | `1` | |

```json
{
  "id": "1"
}
```

**curl 示例:**

```bash
curl -s http://localhost:8002/data/center/get/content -X POST \
  -H "token: $TOKEN" \
  -d "id=1"
```

**响应:** `code: 1` 获取数据中心内容详情任务失败

```json
{
  "code": 1,
  "tip": "获取数据中心内容详情任务失败"
}
```

---

## 10. 国家地区模块

### 10.1 POST /world/country/list — 国家列表 ✅

> **认证**: 免登录

**请求参数:**

无参数

**curl 示例:**

```bash
curl -s http://localhost:8002/world/country/list -X POST
```

**响应:** `code: 0` 响应成功

```json
{
  "code": 0,
  "info": [
    {
      "country": "中国",
      "countryEn": "China",
      "countryId": "CN",
      "id": "1",
      "phoneId": "+86"
    },
    {
      "country": "美国",
      "countryEn": "United States",
      "countryId": "US",
      "id": "2",
      "phoneId": "+1"
    },
    {
      "country": "英国",
      "countryEn": "United Kingdom",
      "countryId": "GB",
      "id": "3",
      "phoneId": "+44"
    },
    {
      "country": "日本",
      "countryEn": "Japan",
      "countryId": "JP",
      "id": "4",
      "phoneId": "+81"
    },
    {
      "country": "韩国",
      "countryEn": "South Korea",
      "countryId": "KR",
  ...
}
```

---

### 10.2 GET /world/country/default — 默认国家(GET) ✅

> **认证**: 免登录

**请求参数:**

无参数

**curl 示例:**

```bash
curl -s http://localhost:8002/world/country/default -X GET
```

**响应:** `code: ?` 

```json
{
  "phoneId": "",
  "countryName": "China",
  "countryId": "CN"
}
```

---

### 10.3 POST /world/country/region/list — 区域节点列表 ✅

> **认证**: 免登录

**请求参数:**

无参数

**curl 示例:**

```bash
curl -s http://localhost:8002/world/country/region/list -X POST
```

**响应:** `code: 1` 获取节点信息列表失败

```json
{
  "code": 1,
  "tip": "获取节点信息列表失败"
}
```

---

### 10.4 POST /world/country/region/get — 区域国家详情 ✅

> **认证**: 免登录

**请求参数:**

| 参数 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `regionId` | String | `1` | |

```json
{
  "regionId": "1"
}
```

**curl 示例:**

```bash
curl -s http://localhost:8002/world/country/region/get -X POST \
  -d "regionId=1"
```

**响应:** `code: 1001` 请求参数错误

```json
{
  "code": 1001,
  "tip": "请求参数错误"
}
```

---

## 11. 任务模块

### 11.1 POST /task/list — 任务列表 ✅

> **认证**: 需Token

**请求参数:**

| 参数 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `pageNum` | String | `1` | |
| `pageSize` | String | `10` | |

```json
{
  "pageNum": "1",
  "pageSize": "10"
}
```

**curl 示例:**

```bash
curl -s http://localhost:8002/task/list -X POST \
  -H "token: $TOKEN" \
  -d "pageNum=1&pageSize=10"
```

**响应:** `code: 1001` 组织id不能为空

```json
{
  "code": 1001,
  "tip": "组织id不能为空"
}
```

---

### 11.2 POST /task/notice — 通知列表 ✅

> **认证**: 需Token

**请求参数:**

| 参数 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `pageNum` | String | `1` | |
| `pageSize` | String | `10` | |
| `placeId` | String | `0` | |

```json
{
  "pageNum": "1",
  "pageSize": "10",
  "placeId": "0"
}
```

**curl 示例:**

```bash
curl -s http://localhost:8002/task/notice -X POST \
  -H "token: $TOKEN" \
  -d "pageNum=1&pageSize=10&placeId=0"
```

**响应:** `code: 1` 查询通知列表失败

```json
{
  "code": 1,
  "tip": "查询通知列表失败"
}
```

---

## 12. 设备分组模块

### 12.1 POST /group/list — 分组列表 ✅

> **认证**: 需Token

**请求参数:**

无参数

**curl 示例:**

```bash
curl -s http://localhost:8002/group/list -X POST \
  -H "token: $TOKEN"
```

**响应:** `code: 1` 获取设备组列表失败

```json
{
  "code": 1,
  "tip": "获取设备组列表失败"
}
```

---

## 13. 设备控制模块

### 13.1 POST /device/shadow/update — 更新设备Shadow(灯控) ✅

> **认证**: 需Token

**请求参数:**

| 参数 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `mac` | String | `ipet-esp32-Device-02` | |
| `version` | String | `0` | |
| `data` | String | `{"led_r":true,"brightness_r":80}` | |

```json
{
  "mac": "ipet-esp32-Device-02",
  "version": "0",
  "data": "{\"led_r\":true,\"brightness_r\":80}"
}
```

**curl 示例:**

```bash
curl -s http://localhost:8002/device/shadow/update -X POST \
  -H "token: $TOKEN" \
  -d "mac=ipet-esp32-Device-02&version=0&data={"led_r":true,"brightness_r":80}"
```

**响应:** `code: 0` 响应成功

```json
{
  "code": 0,
  "tip": "响应成功"
}
```

---

### 13.2 POST /device/shadow/dp/update — 更新DP Shadow ✅

> **认证**: 需Token

**请求参数:**

| 参数 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `mac` | String | `ipet-esp32-Device-02` | |
| `version` | String | `0` | |
| `data` | String | `{"led_r":false}` | |

```json
{
  "mac": "ipet-esp32-Device-02",
  "version": "0",
  "data": "{\"led_r\":false}"
}
```

**curl 示例:**

```bash
curl -s http://localhost:8002/device/shadow/dp/update -X POST \
  -H "token: $TOKEN" \
  -d "mac=ipet-esp32-Device-02&version=0&data={"led_r":false}"
```

**响应:** `code: 0` 响应成功

```json
{
  "code": 0,
  "tip": "响应成功"
}
```

---

### 13.3 POST /device/shadow/transparentData/update — 透传Shadow更新 ✅

> **认证**: 需Token

**请求参数:**

| 参数 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `mac` | String | `ipet-esp32-Device-02` | |
| `state` | String | `{"desired":{}}` | |

```json
{
  "mac": "ipet-esp32-Device-02",
  "state": "{\"desired\":{}}"
}
```

**curl 示例:**

```bash
curl -s http://localhost:8002/device/shadow/transparentData/update -X POST \
  -H "token: $TOKEN" \
  -d "mac=ipet-esp32-Device-02&state={"desired":{}}"
```

**响应:** `code: 1001` 请输入控制内容

```json
{
  "code": 1001,
  "tip": "请输入控制内容"
}
```

---

### 13.4 POST /device/v3/update — V3设备更新 ✅

> **认证**: 需Token

**请求参数:**

| 参数 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `mac` | String | `ipet-esp32-Device-02` | |
| `state` | String | `{"desired":{}}` | |

```json
{
  "mac": "ipet-esp32-Device-02",
  "state": "{\"desired\":{}}"
}
```

**curl 示例:**

```bash
curl -s http://localhost:8002/device/v3/update -X POST \
  -H "token: $TOKEN" \
  -d "mac=ipet-esp32-Device-02&state={"desired":{}}"
```

**响应:** `code: 1001` 请输入控制内容

```json
{
  "code": 1001,
  "tip": "请输入控制内容"
}
```

---

### 13.5 POST /device/property/set — 设置设备属性 ✅

> **认证**: 需Token

**请求参数:**

| 参数 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `mac` | String | `ipet-esp32-Device-02` | |
| `dpId` | String | `1` | |
| `value` | String | `1` | |

```json
{
  "mac": "ipet-esp32-Device-02",
  "dpId": "1",
  "value": "1"
}
```

**curl 示例:**

```bash
curl -s http://localhost:8002/device/property/set -X POST \
  -H "token: $TOKEN" \
  -d "mac=ipet-esp32-Device-02&dpId=1&value=1"
```

**响应:** `code: 1` 请选择功能点

```json
{
  "code": 1,
  "tip": "请选择功能点"
}
```

---

### 13.6 POST /device/set/param — 设备参数设置 ✅

> **认证**: 需Token

**请求参数:**

| 参数 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `mac` | String | `ipet-esp32-Device-02` | |
| `dpId` | String | `1` | |

```json
{
  "mac": "ipet-esp32-Device-02",
  "dpId": "1"
}
```

**curl 示例:**

```bash
curl -s http://localhost:8002/device/set/param -X POST \
  -H "token: $TOKEN" \
  -d "mac=ipet-esp32-Device-02&dpId=1"
```

**响应:** `code: 1001` 请选择设备

```json
{
  "code": 1001,
  "tip": "请选择设备"
}
```

---

### 13.7 POST /device/invent/certificate/get — 虚拟设备证书 ✅

> **认证**: 需Token

**请求参数:**

| 参数 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `mac` | String | `ipet-esp32-Device-02` | |

```json
{
  "mac": "ipet-esp32-Device-02"
}
```

**curl 示例:**

```bash
curl -s http://localhost:8002/device/invent/certificate/get -X POST \
  -H "token: $TOKEN" \
  -d "mac=ipet-esp32-Device-02"
```

**响应:** `code: 1` 获取虚拟设备证书失败

```json
{
  "code": 1,
  "tip": "获取虚拟设备证书失败"
}
```

---

### 13.8 POST /device/invent/shadow/update — 虚拟Shadow更新 ✅

> **认证**: 需Token

**请求参数:**

| 参数 | 类型 | 示例值 | 说明 |
|------|------|--------|------|
| `mac` | String | `ipet-esp32-Device-02` | |
| `state` | String | `{"desired":{}}` | |

```json
{
  "mac": "ipet-esp32-Device-02",
  "state": "{\"desired\":{}}"
}
```

**curl 示例:**

```bash
curl -s http://localhost:8002/device/invent/shadow/update -X POST \
  -H "token: $TOKEN" \
  -d "mac=ipet-esp32-Device-02&state={"desired":{}}"
```

**响应:** `code: 1001` 请输入控制内容

```json
{
  "code": 1001,
  "tip": "请输入控制内容"
}
```

---

## 14. 需外部条件的接口

> 以下接口需要特定外部服务才能完整工作，当前环境返回错误码属于正常。

| # | 接口 | 功能 | 所需条件 | 返回码 |
|---|------|------|---------|--------|
| 1 | `/user/family/ask` | 家庭成员询问 | 需先创建家庭 | `1001` |
| 2 | `/user/device/device/position/get` | 设备位置 | 需GPS数据 | `1` |
| 3 | `/pet/position` | 宠物实时位置 | 需地图配置 | `17812` |
| 4 | `/address/get` | 地址解析(逆地理) | 需Google Maps Key | `17816` |
| 5 | `/pet/agora/getToken` | 获取Agora Token | 需Agora配置 | `1` |
| 6 | `/email/code/get` | 邮箱验证码 | 需邮件服务 | `-1` |
| 7 | `/sms/code/get` | 短信验证码 | 需短信服务 | `1013` |
| 8 | `/file/info/upload` | 文件上传预签名 | 需FILE_ENDPOINT配置 | `1001` |
| 9 | `/device/certificate/get` | 获取设备证书 | 需AWS证书 | `1` |
| 10 | `/device/property/log` | 属性日志 | 需DynamoDB | `1001` |
| 11 | `/device/get/polyline` | 轨迹折线数据 | 需轨迹数据 | `1` |

### 14.1 POST /user/family/ask — 家庭成员询问

> **前置条件**: 需先创建家庭

**请求参数:**
```json
{}
```

**响应:**
```json
{
  "code": 1001,
  "tip": "未选择家庭"
}
```
---

### 14.2 POST /user/device/device/position/get — 设备位置

> **前置条件**: 需GPS数据

**请求参数:**
```json
{
  "mac": "ipet-esp32-Device-02"
}
```

**响应:**
```json
{
  "code": 1,
  "tip": "请求失败"
}
```
---

### 14.3 POST /pet/position — 宠物实时位置

> **前置条件**: 需地图配置

**请求参数:**
```json
{
  "mac": "ipet-esp32-Device-02"
}
```

**响应:**
```json
{
  "code": 17812,
  "tip": "地图mark_name未配置"
}
```
---

### 14.4 POST /address/get — 地址解析(逆地理)

> **前置条件**: 需Google Maps Key

**请求参数:**
```json
{
  "longitude": "113.946",
  "latitude": "22.547",
  "language": "zh_CN"
}
```

**响应:**
```json
{
  "code": 17816,
  "tip": "地图api_key未配置"
}
```
---

### 14.5 POST /pet/agora/getToken — 获取Agora Token

> **前置条件**: 需Agora配置

**请求参数:**
```json
{
  "mac": "ipet-esp32-Device-02"
}
```

**响应:**
```json
{
  "code": 1,
  "tip": "响应失败"
}
```
---

### 14.6 POST /email/code/get — 邮箱验证码

> **前置条件**: 需邮件服务

**请求参数:**
```json
{
  "email": "apitest688365@test.com",
  "codeType": "1"
}
```

**响应:**
```json
{
  "code": -1,
  "tip": "请选择验证码类型"
}
```
---

### 14.7 POST /sms/code/get — 短信验证码

> **前置条件**: 需短信服务

**请求参数:**
```json
{
  "phone": "13800138000",
  "phoneId": "+86",
  "codeType": "1"
}
```

**响应:**
```json
{
  "code": 1013,
  "tip": "手机号码必需带上国家编码"
}
```
---

### 14.8 POST /file/info/upload — 文件上传预签名

> **前置条件**: 需FILE_ENDPOINT配置

**请求参数:**
```json
{
  "fileName": "test.jpg"
}
```

**响应:**
```json
{
  "code": 1001,
  "tip": "系统未配置【FILE_ENDPOINT（文件访问端点）】"
}
```
---

### 14.9 POST /device/certificate/get — 获取设备证书

> **前置条件**: 需AWS证书

**请求参数:**
```json
{
  "mac": "ipet-esp32-Device-02"
}
```

**响应:**
```json
{
  "code": 1,
  "tip": "获取设备证书失败"
}
```
---

### 14.10 POST /device/property/log — 属性日志

> **前置条件**: 需DynamoDB

**请求参数:**
```json
{
  "mac": "ipet-esp32-Device-02",
  "dpId": "1"
}
```

**响应:**
```json
{
  "code": 1001,
  "tip": "请选择设备"
}
```
---

### 14.11 POST /device/get/polyline — 轨迹折线数据

> **前置条件**: 需轨迹数据

**请求参数:**
```json
{
  "mac": "ipet-esp32-Device-02",
  "dpId": "1"
}
```

**响应:**
```json
{
  "code": 1,
  "tip": "请选择设备属性"
}
```
---
