# WiFi 项圈蓝牙配网协议规范

**版本**: v1.0  
**更新日期**: 2026-08-14  
**适用产品**: WiFi 版项圈 (collar_wifi_v1)  
**协议类型**: BLE (Bluetooth Low Energy) 配网

---

## 1. 概述

本文档定义 WiFi 版项圈通过蓝牙（BLE）接收配网指令的完整协议，包括 BLE 服务定义、配网指令格式、硬件侧处理流程、错误处理等。

### 1.1 配网流程概览

```
┌─────────────┐                ┌─────────────┐                ┌─────────────┐
│   手机 App  │                │  WiFi 项圈  │                │  PeerApi   │
└─────────────┘                └─────────────┘                └─────────────┘
       │                              │                              │
       │  1. 扫描 BLE 设备             │                              │
       │─────────────────────────────>│                              │
       │                              │                              │
       │  2. 连接蓝牙                  │                              │
       │<─────────────────────────────│                              │
       │                              │                              │
       │  3. 写入配网指令 (JSON)       │                              │
       │─────────────────────────────>│                              │
       │  {ssid, password, token}     │                              │
       │                              │                              │
       │                              │  4. 连接 WiFi                │
       │                              │     (使用 ssid/password)     │
       │                              │                              │
       │                              │  5. 调用绑定接口              │
       │                              │  POST /user/device/bind      │
       │                              │  Header: token: <granwin_token> │
       │                              │  Body: {mac, deviceNickName} │
       │                              │─────────────────────────────>│
       │                              │                              │
       │                              │  6. 绑定成功响应              │
       │                              │<─────────────────────────────│
       │                              │  {code: 0, info: {...}}      │
       │                              │                              │
       │  7. 轮询设备列表              │                              │
       │  POST /user/device/list      │                              │
       │──────────────────────────────────────────────────────────>│
       │                              │                              │
       │  8. 检测到新设备 → 配网成功    │                              │
       │<─────────────────────────────────────────────────────────│
       │                              │                              │
       │  9. 断开蓝牙连接              │                              │
       │─────────────────────────────>│                              │
       │                              │                              │
```

---

## 2. BLE 服务定义

### 2.1 Service UUID（服务标识）

```
UUID: 0000FFF0-0000-1000-8000-00805F9B34FB
```

**用途**：  
- App 扫描蓝牙设备时，通过此 UUID 过滤，只显示 WiFi 项圈设备
- 项圈必须在 BLE 广播包中包含此 Service UUID

**实现要求**：
```c
// 示例伪代码（具体实现根据硬件平台调整）
BLE_Service provision_service = {
    .uuid = "0000FFF0-0000-1000-8000-00805F9B34FB",
    .characteristics = {provision_char_write}
};
```

---

### 2.2 Characteristic UUID (Write)（写特征值）

```
UUID: 0000FFF1-0000-1000-8000-00805F9B34FB
```

**用途**：  
- App 通过写入此特征值向项圈发送配网指令
- 项圈接收到数据后，解析为 JSON 并执行配网流程

**属性**：
- **Type**: Write（可写）
- **Permissions**: Write without response（无响应写入，性能更优）
- **Max Length**: 512 字节（足够容纳 JSON 配网指令）

**实现要求**：
```c
// 示例伪代码
BLE_Characteristic provision_char_write = {
    .uuid = "0000FFF1-0000-1000-8000-00805F9B34FB",
    .properties = BLE_CHAR_PROP_WRITE,
    .permissions = BLE_CHAR_PERM_WRITE,
    .max_length = 512,
    .callback = on_provision_data_received
};

void on_provision_data_received(uint8_t* data, uint16_t length) {
    // 解析 JSON 配网指令
    parse_provision_json(data, length);
}
```

---

### 2.3 设备名（BLE Advertising Name）

**格式**：
```
iPetCollar_<MAC后6位>
```

**示例**：
- MAC 地址 = `AA:BB:CC:DD:EE:FF` → 设备名 = `iPetCollar_DDEEFF`
- MAC 地址 = `12:34:56:78:9A:BC` → 设备名 = `iPetCollar_789ABC`

**用途**：
- 用户在 App 扫描列表中识别自己的项圈
- 避免多个项圈时混淆

**实现要求**：
```c
// 示例伪代码
char device_name[32];
sprintf(device_name, "iPetCollar_%02X%02X%02X", 
        mac[3], mac[4], mac[5]);
ble_set_device_name(device_name);
```

---

## 3. 配网指令格式

### 3.1 JSON 格式定义

App 通过 BLE Characteristic `0000FFF1-...` 写入以下 JSON 字符串（UTF-8 编码）：

```json
{
  "ssid": "我家WiFi",
  "password": "12345678",
  "token": "granwin_aws_user_info_hash:_43200_8698cc5d519e53810ffdc57acea6cc34",
  "timestamp": 1779688400
}
```

### 3.2 字段说明

| 字段 | 类型 | 必填 | 说明 | 示例 |
|------|------|------|------|------|
| `ssid` | String | **是** | WiFi SSID（支持中文/特殊字符，UTF-8 编码） | `"我家WiFi"` 或 `"Home-WiFi-5G"` |
| `password` | String | **是** | WiFi 密码（明文） | `"12345678"` |
| `token` | String | **是** | PeerApi 的 `granwin_token`（用于调用绑定接口） | `"granwin_aws_user_info_hash:_43200_xxx"` |
| `timestamp` | Number | 否 | Unix 时间戳（秒），可选，用于防重放攻击 | `1779688400` |

### 3.3 JSON 示例（实际传输时压缩，无换行）

```json
{"ssid":"MyHome","password":"pass123","token":"granwin_aws_user_info_hash:_43200_abc123","timestamp":1779688400}
```

### 3.4 编码格式

- **字符编码**: UTF-8
- **数据格式**: JSON 字符串
- **数据长度**: 通常 200-400 字节（根据 SSID/密码长度变化）

---

## 4. 硬件侧处理流程

### 4.1 接收配网指令

```c
// 伪代码示例
void on_provision_data_received(uint8_t* data, uint16_t length) {
    // 1. 转为字符串
    char json_str[512];
    memcpy(json_str, data, length);
    json_str[length] = '\0';
    
    // 2. 解析 JSON（使用 cJSON 或其他 JSON 库）
    cJSON* root = cJSON_Parse(json_str);
    if (root == NULL) {
        log_error("JSON parse failed");
        return;
    }
    
    // 3. 提取字段
    const char* ssid = cJSON_GetObjectItem(root, "ssid")->valuestring;
    const char* password = cJSON_GetObjectItem(root, "password")->valuestring;
    const char* token = cJSON_GetObjectItem(root, "token")->valuestring;
    
    // 4. 保存到全局变量
    strcpy(g_wifi_ssid, ssid);
    strcpy(g_wifi_password, password);
    strcpy(g_peerapi_token, token);
    
    // 5. 启动 WiFi 连接流程
    wifi_connect(g_wifi_ssid, g_wifi_password);
    
    cJSON_Delete(root);
}
```

---

### 4.2 连接 WiFi

```c
// 伪代码示例
bool wifi_connect(const char* ssid, const char* password) {
    // 1. 配置 WiFi 参数
    wifi_config_t config = {0};
    strcpy(config.sta.ssid, ssid);
    strcpy(config.sta.password, password);
    
    // 2. 启动连接
    esp_wifi_set_config(WIFI_IF_STA, &config);
    esp_wifi_connect();
    
    // 3. 等待连接结果（最多 60s）
    int timeout = 60;
    while (timeout-- > 0) {
        if (wifi_is_connected()) {
            log_info("WiFi connected successfully");
            return true;
        }
        vTaskDelay(1000 / portTICK_PERIOD_MS);
    }
    
    log_error("WiFi connection timeout");
    return false;
}
```

**WiFi 连接失败处理**：
- 密码错误 / 信号弱 / 超时 → 项圈保持 BLE 广播状态，等待 App 重新配网
- 不关机、不重启，让用户可以快速重试

---

### 4.3 调用 PeerApi 绑定接口

#### 4.3.1 接口定义

```
POST http://<peerapi_url>/user/device/bind
Header: token: <granwin_token>
Content-Type: application/x-www-form-urlencoded

Body:
mac=AA:BB:CC:DD:EE:FF&deviceNickName=我的项圈
```

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `mac` | String | 是 | 项圈自己的 MAC 地址（例如 `AA:BB:CC:DD:EE:FF`） |
| `deviceNickName` | String | 否 | 设备昵称（可选，默认 `我的项圈` 或留空） |

#### 4.3.2 成功响应

```json
{
  "code": 0,
  "info": {
    "appuserId": "1218767262805061632",
    "connect": true,
    "createTime": 1779688383180,
    "deviceId": "1218761715930296320",
    "deviceNickname": "我的项圈",
    "mac": "AA:BB:CC:DD:EE:FF",
    "productId": "1",
    "productKey": "collar_wifi_v1",
    "sharer": "0",
    "uType": "1",
    "updateTime": 1779688383180
  },
  "tip": "响应成功"
}
```

#### 4.3.3 失败响应

| code | tip | 说明 |
|------|-----|------|
| `401` | `Token 无效或已过期` | token 错误，需 App 重新配网 |
| `2001` | `设备已被绑定` | MAC 地址已绑定到其他用户（正常，返回成功即可） |
| `1001` | `参数错误` | MAC 地址格式错误 |

#### 4.3.4 实现示例

```c
// 伪代码示例（使用 HTTP Client 库）
bool peerapi_bind_device(const char* mac, const char* token) {
    char url[256];
    sprintf(url, "http://%s/user/device/bind", PEERAPI_HOST);
    
    // 构造请求体
    char body[256];
    sprintf(body, "mac=%s&deviceNickName=我的项圈", mac);
    
    // 构造请求头
    http_header_t headers[] = {
        {"Content-Type", "application/x-www-form-urlencoded"},
        {"token", token},
        {NULL, NULL}
    };
    
    // 发送 POST 请求
    http_response_t resp = http_post(url, headers, body);
    
    if (resp.status_code == 200) {
        // 解析响应 JSON
        cJSON* root = cJSON_Parse(resp.body);
        int code = cJSON_GetObjectItem(root, "code")->valueint;
        cJSON_Delete(root);
        
        if (code == 0) {
            log_info("Device bind success");
            return true;
        } else {
            log_error("Device bind failed, code=%d", code);
            return false;
        }
    } else {
        log_error("HTTP request failed, status=%d", resp.status_code);
        return false;
    }
}
```

---

### 4.4 配网完成后的处理

```c
// 伪代码示例
void provision_complete() {
    // 1. 关闭 BLE 广播（节省功耗）
    ble_stop_advertising();
    
    // 2. 进入正常工作模式
    device_enter_normal_mode();
    
    // 3. 可选：LED 指示灯闪烁 3 次表示配网成功
    led_blink(3);
}
```

---

## 5. 错误处理

### 5.1 JSON 解析失败

**原因**：App 传输数据损坏 / 格式错误

**处理**：
- 记录日志
- 保持 BLE 连接，等待 App 重新发送配网指令
- 不关闭 BLE 广播

```c
if (cJSON_Parse(json_str) == NULL) {
    log_error("JSON parse failed, raw data: %s", json_str);
    // 保持 BLE 连接，不做其他操作
    return;
}
```

---

### 5.2 WiFi 连接失败

**原因**：
- WiFi 密码错误
- WiFi 信号弱/超时
- 路由器故障
- 项圈只支持 2.4G，用户输入了 5G WiFi

**处理**：
- 记录失败原因
- 保持 BLE 广播，等待 App 重新配网
- 可选：LED 红灯闪烁提示失败

```c
if (!wifi_connect(ssid, password)) {
    log_error("WiFi connection failed: ssid=%s", ssid);
    
    // 重新开启 BLE 广播
    ble_start_advertising();
    
    // LED 提示（可选）
    led_set_color(RED);
    led_blink(5);
}
```

---

### 5.3 PeerApi 绑定失败

**原因**：
- Token 过期
- 网络故障
- 后端服务异常

**处理**：
- 记录失败原因
- 保持 WiFi 连接（不断开）
- 重新开启 BLE 广播，等待 App 重新配网

```c
if (!peerapi_bind_device(mac, token)) {
    log_error("PeerApi bind failed");
    
    // 保持 WiFi 连接
    // 重新开启 BLE 广播
    ble_start_advertising();
}
```

---

### 5.4 超时处理

| 阶段 | 超时时限 | 处理 |
|------|---------|------|
| WiFi 连接 | 60s | 记录失败，重新开启 BLE 广播 |
| PeerApi 请求 | 10s | 记录失败，重新开启 BLE 广播 |
| BLE 连接空闲 | 300s (5 分钟) | 自动断开 BLE，节省功耗 |

---

## 6. 安全性说明

### 6.1 当前方案（Phase 1）

- **传输安全**：依赖 BLE Pairing（配对）的链路层 AES-128 加密
- **明文传输**：WiFi 密码和 token 以 JSON 明文传输
- **风险评估**：
  - ✅ BLE 配对已提供基础安全性，中间人攻击难度高
  - ⚠️ 未防范恶意硬件（山寨项圈伪装成正品）
  - ⚠️ 未防范重放攻击（timestamp 字段存在但未校验）

### 6.2 安全建议（可选实现）

#### 6.2.1 Timestamp 防重放

```c
// 校验 timestamp（可选）
uint32_t current_time = get_unix_timestamp(); // 从 NTP 服务器获取
uint32_t received_time = cJSON_GetObjectItem(root, "timestamp")->valueint;

if (abs(current_time - received_time) > 300) { // 5 分钟有效期
    log_error("Timestamp expired");
    return;
}
```

#### 6.2.2 应用层加密（Phase 2）

如果需要更高安全性，可以在 Phase 2 实现：
- 使用 AES-128-GCM 加密配网指令
- 通过 ECDH 协商对称密钥
- 需要 App 侧和硬件侧同步开发

---

## 7. 测试与调试

### 7.1 测试工具推荐

- **nRF Connect** (Android/iOS): 蓝牙调试神器，可以手动写入 Characteristic 测试
- **LightBlue** (iOS): iOS 平台 BLE 调试工具
- **Wireshark + Bluetooth HCI**: 抓取 BLE 通信包（需支持的硬件）

### 7.2 手动测试步骤

1. 使用 nRF Connect 扫描设备，找到 `iPetCollar_XXXXXX`
2. 连接设备
3. 找到 Service `0000FFF0-...` → Characteristic `0000FFF1-...`
4. 点击"Write"，输入 JSON：
   ```json
   {"ssid":"TestWiFi","password":"test1234","token":"test_token_123","timestamp":1779688400}
   ```
5. 点击"Send"
6. 观察项圈日志，确认收到数据并开始连接 WiFi

### 7.3 常见问题排查

| 问题 | 可能原因 | 排查方法 |
|------|---------|---------|
| App 扫描不到设备 | Service UUID 未广播 | 检查 BLE 广播包是否包含 `0000FFF0-...` |
| 写入失败 | Characteristic 权限错误 | 确认 `0000FFF1-...` 有 Write 权限 |
| JSON 解析失败 | 字符编码问题 | 确认使用 UTF-8 编码 |
| WiFi 连接超时 | 密码错误 / 信号弱 | 检查路由器日志 |
| 绑定接口 401 | Token 过期 | 检查 token 有效期（12 小时） |

---

## 8. 性能要求

| 指标 | 目标值 | 说明 |
|------|--------|------|
| BLE 广播间隔 | 100ms | 快速被 App 发现 |
| BLE 连接建立 | <5s | 从连接请求到连接成功 |
| JSON 解析耗时 | <100ms | 不阻塞主线程 |
| WiFi 连接耗时 | 10-30s | 正常情况下 |
| PeerApi 请求耗时 | <3s | 网络正常情况下 |
| 配网总时长 | <60s | 从收到指令到绑定成功 |

---

## 9. 硬件资源要求

| 资源 | 最低要求 | 推荐配置 |
|------|---------|---------|
| Flash | 512KB | 1MB |
| RAM | 128KB | 256KB |
| WiFi | 2.4GHz (802.11 b/g/n) | 2.4GHz + 5GHz 双频 |
| BLE | 4.0+ | 5.0+ |
| JSON 库 | cJSON 或 ArduinoJson | cJSON |
| HTTP Client | ESP-IDF HTTP Client 或 lwIP | ESP-IDF HTTP Client |

---

## 10. 版本历史

| 版本 | 日期 | 变更内容 |
|------|------|---------|
| v1.0 | 2026-08-14 | 初版发布 |

---

## 11. 联系方式

如有疑问或需要协助，请联系：

- **前端团队**：（联系方式）
- **后端团队**：（联系方式）
- **硬件团队**：（联系方式）

---

## 附录 A: 完整示例代码

### A.1 配网指令接收与处理（完整流程）

```c
#include <stdio.h>
#include <string.h>
#include "cJSON.h"
#include "esp_wifi.h"
#include "esp_http_client.h"

// 全局变量
char g_wifi_ssid[64];
char g_wifi_password[128];
char g_peerapi_token[256];
char g_device_mac[18];

// BLE 回调：接收配网指令
void on_provision_data_received(uint8_t* data, uint16_t length) {
    printf("[Provision] Received data, length=%d\n", length);
    
    // 1. 转为字符串
    char json_str[512];
    memcpy(json_str, data, length);
    json_str[length] = '\0';
    printf("[Provision] JSON: %s\n", json_str);
    
    // 2. 解析 JSON
    cJSON* root = cJSON_Parse(json_str);
    if (root == NULL) {
        printf("[Provision] JSON parse failed\n");
        return;
    }
    
    // 3. 提取字段
    cJSON* ssid_obj = cJSON_GetObjectItem(root, "ssid");
    cJSON* password_obj = cJSON_GetObjectItem(root, "password");
    cJSON* token_obj = cJSON_GetObjectItem(root, "token");
    
    if (!ssid_obj || !password_obj || !token_obj) {
        printf("[Provision] Missing required fields\n");
        cJSON_Delete(root);
        return;
    }
    
    strcpy(g_wifi_ssid, ssid_obj->valuestring);
    strcpy(g_wifi_password, password_obj->valuestring);
    strcpy(g_peerapi_token, token_obj->valuestring);
    
    printf("[Provision] SSID=%s, Token=%s\n", g_wifi_ssid, g_peerapi_token);
    
    cJSON_Delete(root);
    
    // 4. 启动 WiFi 连接
    if (wifi_connect(g_wifi_ssid, g_wifi_password)) {
        // 5. WiFi 连接成功，调用绑定接口
        if (peerapi_bind_device(g_device_mac, g_peerapi_token)) {
            // 6. 绑定成功，配网完成
            printf("[Provision] SUCCESS!\n");
            provision_complete();
        } else {
            printf("[Provision] PeerApi bind failed\n");
            ble_start_advertising(); // 重新开启 BLE
        }
    } else {
        printf("[Provision] WiFi connection failed\n");
        ble_start_advertising(); // 重新开启 BLE
    }
}

// WiFi 连接
bool wifi_connect(const char* ssid, const char* password) {
    printf("[WiFi] Connecting to %s...\n", ssid);
    
    wifi_config_t config = {0};
    strcpy((char*)config.sta.ssid, ssid);
    strcpy((char*)config.sta.password, password);
    
    esp_wifi_set_config(WIFI_IF_STA, &config);
    esp_wifi_connect();
    
    // 等待连接（最多 60s）
    for (int i = 0; i < 60; i++) {
        if (wifi_is_connected()) {
            printf("[WiFi] Connected successfully\n");
            return true;
        }
        vTaskDelay(1000 / portTICK_PERIOD_MS);
    }
    
    printf("[WiFi] Connection timeout\n");
    return false;
}

// PeerApi 绑定
bool peerapi_bind_device(const char* mac, const char* token) {
    printf("[PeerApi] Binding device, mac=%s\n", mac);
    
    char url[256];
    sprintf(url, "http://peerapi-server.com/user/device/bind");
    
    char post_data[256];
    sprintf(post_data, "mac=%s&deviceNickName=我的项圈", mac);
    
    esp_http_client_config_t config = {
        .url = url,
        .method = HTTP_METHOD_POST,
    };
    
    esp_http_client_handle_t client = esp_http_client_init(&config);
    esp_http_client_set_header(client, "Content-Type", "application/x-www-form-urlencoded");
    esp_http_client_set_header(client, "token", token);
    esp_http_client_set_post_field(client, post_data, strlen(post_data));
    
    esp_err_t err = esp_http_client_perform(client);
    
    if (err == ESP_OK) {
        int status = esp_http_client_get_status_code(client);
        printf("[PeerApi] HTTP status=%d\n", status);
        
        // 读取响应
        char buffer[512];
        int len = esp_http_client_read(client, buffer, sizeof(buffer) - 1);
        buffer[len] = '\0';
        printf("[PeerApi] Response: %s\n", buffer);
        
        // 解析响应
        cJSON* root = cJSON_Parse(buffer);
        int code = cJSON_GetObjectItem(root, "code")->valueint;
        cJSON_Delete(root);
        
        esp_http_client_cleanup(client);
        return (status == 200 && code == 0);
    } else {
        printf("[PeerApi] HTTP request failed: %s\n", esp_err_to_name(err));
        esp_http_client_cleanup(client);
        return false;
    }
}

// 配网完成
void provision_complete() {
    printf("[Provision] Complete, stopping BLE...\n");
    ble_stop_advertising();
    
    // LED 提示（可选）
    led_blink(3);
    
    // 进入正常工作模式
    device_enter_normal_mode();
}
```

---

**文档结束**
