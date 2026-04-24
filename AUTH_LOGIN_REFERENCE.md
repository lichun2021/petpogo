# PetPogo 移动端 账户登录认证 完整分析

> 基于 H5 注册代码（`WEB_MP_H5_移动端页面`）+ Flutter App 认证架构 + `AppConfig` 整理  
> 更新时间：2026-04-23

---

## 一、认证系统整体架构

```
                    ┌─────────────────────────────────────────────┐
                    │              uCloudlink 用户中心（BSS）       │
                    │  baseUrl: https://api.ucloudlink.com/        │
                    │  (CN环境: https://saas.ucloudlink.cn/)       │
                    └──────────────────┬──────────────────────────┘
                                       │
                    ┌──────────────────▼──────────────────────────┐
                    │            OAuth2 认证中心                   │
                    │  /oauth/token  →  access_token              │
                    │  partnerCode / clientId / clientSecret        │
                    └──────────────────┬──────────────────────────┘
                                       │ 登录成功后返回 access_token
                    ┌──────────────────▼──────────────────────────┐
                    │          /uclgwapp/ 业务网关                  │
                    │   所有业务接口：设备/宠物/位置/音乐...          │
                    │   URL 后拼接：?access_token={token}          │
                    └─────────────────────────────────────────────┘
```

---

## 二、OAuth2 认证配置参数

这是连接 uCloudlink 用户中心的核心凭证（来自 `AppConfig.dart`）：

| 参数 | 值 | 说明 |
|------|-----|------|
| `baseUrl` | `https://api.ucloudlink.com/` | 海外/默认环境 |
| `baseUrlCn` | `https://saas.ucloudlink.cn/` | 中国大陆环境 |
| `partnerCode` | `GCGROUP` | 合作方编码（标识是谁的App） |
| `clientId` | `585920816499674940a2cbae` | OAuth 客户端 ID |
| `clientSecret` | `585920816499674940a2cbaf` | OAuth 客户端密钥 |
| `enterpriseCode` | `EA00000484` | 企业代码（用于多租户隔离） |

> ⚠️ **安全警告**：`clientSecret` 不应硬编码在 App 中，生产环境应通过后端中转或 iOS Keychain / Android Keystore 保存。

---

## 三、注册流程（两种方式）

### 3.1 手机号注册流程

```
手机号注册完整步骤：

Step 1: 获取注册渠道配置
  POST /webmps/cfg/get_cfg_table
  { channel_code, version, app_version }
  响应：commonRegister { enterpriseCode, bssApi, jumpUrl, registerChannel }

Step 2: 检查账号是否已存在
  POST {bssApi}/register/checkUser
  {
    langType: "zh-CN",
    enterpriseCode: "EA00000484",
    registerType: "PHONE",
    userCode: "13812345678",     ← 手机号
    countryCode: "86"            ← 国际区号（去掉+）
  }

Step 3: 发送短信验证码
  POST {bssApi}/register/sendSMS
  {
    nationNum: "86",
    phone: "13812345678",
    msgTemplateCode: "sms_verification_code_template",
    businessType: "1",           ← 0:通用 1:注册 2:找回密码
    enterpriseCode: "EA00000484",
    langType: "zh-CN"
  }

Step 4: 验证短信验证码
  POST {bssApi}/register/checkSMS
  {
    nationNum: "86",
    phone: "13812345678",
    businessType: "1",
    enterpriseCode: "EA00000484",
    langType: "zh-CN",
    msgCode: "123456"            ← 用户输入的6位验证码
  }
  响应成功：继续设置密码

Step 5: 设置密码
  → 前端本地存入 sessionStorage.register_param = {
      registerType: "PHONE",
      nationNum: "86",
      phone: "13812345678",
      msgCode: "123456",
      password: "用户设置的密码"
    }

Step 6: 选择注册地区（国家/地区）
  → 默认 CN（中国），特殊配置 AE（阿联酋，不可更改）
  → 检查企业配置：POST {bssApi}/register/queryEnterpriseConfigList

Step 7: 提交注册
  POST {bssApi}/register/registerUser
  {
    channelType: "WEB",          ← WEB/WAP/APP
    countryCode: "86",
    userCode: "13812345678",
    password: "密码（MD5加密）",
    msgCode: "123456",
    registerType: "PHONE",
    registerCountry: "CN",
    langType: "zh-CN",
    enterpriseCode: "EA00000484",
    registerChannel: "xxx"       ← 来自 commonRegister
  }

Step 8（注册成功）: 自动触发登录，跳转到 jumpUrl
```

**前端验证规则**：
- 中国手机号（+86）：固定 11 位
- 境外手机号：7～16 位
- 验证码：固定 6 位，60秒后可重发

---

### 3.2 邮箱注册流程

```
Step 1-3: 同手机号注册（获取渠道、检查账号）
          registerType: "EMAIL", userCode: 邮箱地址

Step 4: 设置密码

Step 5: 选择注册地区

Step 6: 提交注册（不含 msgCode，不含 nationNum）
  POST {bssApi}/register/registerUser
  {
    channelType: "WEB",
    userCode: "user@example.com",
    password: "密码",
    registerType: "EMAIL",
    registerCountry: "CN",
    langType: "zh-CN",
    enterpriseCode: "EA00000484"
  }

Step 7（注册成功）: 跳转邮箱激活等待页
  → 后端发送激活邮件
  → 用户点击邮件中的激活链接
  → 激活完成后返回 App 登录
  → 可重发激活邮件：POST {bssApi}/register/resendActivationMail
```

---

## 四、登录流程（OAuth2）

### 4.1 标准账号密码登录

```
POST https://api.ucloudlink.com/oauth/token
Content-Type: application/json

{
  "grantType": "password",
  "clientId": "585920816499674940a2cbae",
  "clientSecret": "585920816499674940a2cbaf",
  "username": "13812345678",      ← 手机号或邮箱
  "password": "xxxxxx",           ← 密码（MD5）
  "langType": "zh-CN",
  "partnerCode": "GCGROUP",
  "enterpriseCode": "EA00000484"
}

响应：
{
  "access_token": "eyJhbGciOiJSUzI1NiJ9...",   ← 核心！后续所有接口用这个
  "token_type": "bearer",
  "expires_in": 86400,                            ← 有效期（秒）
  "loginCustomerId": "619eec5a91fe743dbb39ccbe", ← 用户ID，同样需要保存
  "refresh_token": "xxxxxx"                       ← 刷新token
}
```

### 4.2 短信验证码登录（无密码）

```
POST https://api.ucloudlink.com/oauth/token

{
  "grantType": "sms_code",
  "clientId": "585920816499674940a2cbae",
  "clientSecret": "585920816499674940a2cbaf",
  "phone": "13812345678",
  "nationNum": "86",
  "msgCode": "123456",
  "langType": "zh-CN",
  "partnerCode": "GCGROUP",
  "enterpriseCode": "EA00000484"
}
```

### 4.3 H5 页面通过 URL 参数传递 Token（WebView 场景）

H5 页面通过 URL query 参数接收 Token，无需独立登录：

```javascript
// auth.js 中解析
const config = {
  access_token: AllValue.access_token,
  loginCustomerId: AllValue.loginCustomerId,
  langType: AllValue.lang,
  mvnoId: AllValue.mvnoId,
  orgId: AllValue.orgId,
  partnerCode: "UKAPP"
};
```

**URL 格式示例**：
```
https://h5.petpogo.com/page?access_token=eyJ...&loginCustomerId=619eec5a...&lang=zh-CN&mvnoId=xxx&orgId=xxx
```

---

## 五、Token 管理机制

### 5.1 Token 存储位置

| 平台 | 存储方式 | 说明 |
|------|---------|------|
| Flutter (iOS) | `flutter_secure_storage` → iOS Keychain | 安全存储，App 卸载后清除 |
| Flutter (Android) | `flutter_secure_storage` → Android Keystore | 加密存储 |
| H5/WebView | `sessionStorage` | 页面关闭后清除 |
| H5/WebView | `Cookie` (mvnoId, orgId, loginCustomerId) | 通过 CookieHelper 管理 |

### 5.2 Flutter App 中的 Token 注入（`ApiClient`）

```dart
// ① 登录后设置 Token（之后所有请求自动携带）
ref.read(apiClientProvider).setToken(loginResponse.accessToken);

// ② ApiClient 内部：每个请求头自动插入
// _AuthInterceptor.onRequest:
options.headers['Authorization'] = 'Bearer $token';

// ③ 退出登录时清除
ref.read(apiClientProvider).clearToken();
```

> **重要**：`/uclgwapp/` 业务接口的认证方式是 **URL 参数拼接**（`?access_token=xxx`），**不是** Bearer Header。  
> Flutter `ApiClient` 当前实现的是 Bearer Header 方式，移植时需要在构建请求 URL 时额外拼接 `access_token` 参数。

### 5.3 Token 有效期与刷新

| 参数 | 说明 |
|------|------|
| `expires_in` | 通常为 86400 秒（24小时） |
| `refresh_token` | 用于无感刷新，避免重新登录 |
| 过期错误码 | `resultCode: 00000006/00000007/00000008`（来自 H5 代码） |
| HTTP 状态码 | 401（在 Flutter ApiClient 中捕获为 `ApiErrorType.unauthorized`） |

---

## 六、公共请求参数组装

所有业务接口请求体都需要包含以下公共参数：

```dart
// Flutter 端组装公共参数模板
Map<String, dynamic> buildCommonParams() {
  return {
    'loginCustomerId': currentUser.id,              // 登录用户ID
    'langType': AppConfig.defaultLang,              // "zh-CN" 或 "en-US"
    'streamNo': 'APP${DateTime.now().millisecondsSinceEpoch}${Random().nextInt(9999)}',
    // 业务接口中还可能需要：
    // 'mac': currentDevice.imei,                  // 当前绑定设备的IMEI
    // 'partnerCode': AppConfig.partnerCode,       // "GCGROUP"（部分接口需要）
  };
}
```

**`streamNo` 格式规范**：
- Flutter App：`APP{时间戳}{4位随机数}` 如 `APP17140251911234`
- H5：`UKAPPH5{时间戳}{4位随机数}`
- 机器人/后台：`Robot20241120103929234663`

---

## 七、登出逻辑

```dart
// Flutter 端登出
Future<void> logout() async {
  // 1. 可选：通知服务端（让服务端令牌失效）
  // await apiClient.post(ApiEndpoints.logout);

  // 2. 清除本地 Token
  ref.read(apiClientProvider).clearToken();

  // 3. 清除 SecureStorage 中的持久化 Token
  await secureStorage.delete(key: 'access_token');
  await secureStorage.delete(key: 'login_customer_id');

  // 4. 跳转到登录页
  context.go('/login');
}
```

---

## 八、多会话与用户标识

| 标识 | 来源 | 用途 |
|------|------|------|
| `loginCustomerId` | 登录响应 | 所有业务接口的用户ID |
| `access_token` | OAuth2 Token | 接口鉴权 |
| `mvnoId` | 登录响应/Cookie | MVNO 多租户标识 |
| `orgId` | 登录响应/Cookie | 组织ID |
| `enterpriseCode` | 配置 `EA00000484` | 企业多租户标识 |
| `partnerCode` | 配置 `GCGROUP` | 合作方标识（UKAPP用于H5） |

---

## 九、当前 Flutter App 登录现状

| 功能 | 状态 | 代码位置 | 说明 |
|------|------|---------|------|
| 登录 UI | ❌ 未实现 | 无 | `profile_page.dart` 中 `_isLoggedIn = true` 硬编码 |
| 注册 UI | ❌ 未实现 | 无 | — |
| OAuth2 登录接口 | ❌ 未实现 | `api_endpoints.dart` | 仅定义了 `/auth/login` 占位，未接真实接口 |
| Token 存储 | ⚠️ 架构就绪 | `api_client.dart` | `setToken()` 方法存在，但 SecureStorage 未接入 |
| Token 注入 | ⚠️ 架构就绪 | `_AuthInterceptor` | 注入方式是 Bearer Header，需改为 URL param |
| 游客模式 | ⚠️ UI存在 | `_GuestProfileView` | 有 "登录/注册" 按钮但无功能 |
| 登出 | ⚠️ UI存在 | `profile_page.dart` | 有按钮，`onPressed: () {}` 无逻辑 |

---

## 十、移植时的关键修改点

### 10.1 Token 注入方式（最重要！）

**现有实现（错误的方式）**：
```dart
// api_client.dart 当前：Bearer Header 方式
options.headers['Authorization'] = 'Bearer $token';
```

**正确方式（URL 参数拼接）**：
```dart
// 需要修改 _AuthInterceptor 为 URL 参数方式
void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
  if (_token != null && _token!.isNotEmpty) {
    options.queryParameters['access_token'] = _token;  // ← 改为 URL 参数
  }
  handler.next(options);
}
```

### 10.2 登录接口（OAuth2）

```dart
// 新增 AuthRepository
class AuthRepository {
  Future<LoginResult> loginWithPhone({
    required String phone,
    required String password,
    required String countryCode,
  }) async {
    final response = await _dio.post(
      '${AppConfig.baseUrl}oauth/token',
      data: {
        'grantType': 'password',
        'clientId': AppConfig.clientId,
        'clientSecret': AppConfig.clientSecret,
        'username': phone,
        'password': _md5(password),
        'langType': AppConfig.defaultLang,
        'partnerCode': AppConfig.partnerCode,
        'enterpriseCode': AppConfig.enterpriseCode,
      },
    );
    // 保存 access_token 和 loginCustomerId
    await _secureStorage.write(key: 'access_token', value: response['access_token']);
    await _secureStorage.write(key: 'login_customer_id', value: response['loginCustomerId']);
    return LoginResult.fromJson(response);
  }
}
```

### 10.3 持久化 Token（App 重启后保持登录）

```dart
// main.dart 启动时恢复 Token
final token = await secureStorage.read(key: 'access_token');
if (token != null) {
  ref.read(apiClientProvider).setToken(token);
}
```

### 10.4 Token 过期自动刷新

在 `_ErrorInterceptor` 中添加 401 自动刷新逻辑：
```dart
case 401:
  // 尝试用 refresh_token 刷新
  final newToken = await _refreshToken();
  if (newToken != null) {
    // 重试原请求
    options.headers['Authorization'] = 'Bearer $newToken'; // 或 URL 参数
    return handler.resolve(await dio.fetch(options));
  }
  // 刷新失败 → 跳转登录页
  break;
```

---

## 十一、快速接入步骤

```
Step 1: 修改 ApiClient 的 Token 注入方式（URL param，非 Bearer）

Step 2: 实现 AuthRepository
  ├─ loginWithPhone(phone, password, countryCode)
  ├─ loginWithEmail(email, password)
  ├─ loginWithSmsCode(phone, smsCode)
  └─ logout()

Step 3: 实现 SecureStorage 持久化
  ├─ 保存: access_token, loginCustomerId, expires_at
  └─ 读取: App 启动时恢复登录状态

Step 4: 实现登录 UI
  ├─ 手机号 + 密码登录
  ├─ 手机号 + 短信验证码登录
  └─ （可选）邮箱 + 密码登录

Step 5: 实现 AuthProvider（Riverpod）
  ├─ 暴露 isLoggedIn 状态
  ├─ 暴露 currentUser（loginCustomerId）
  └─ loginCustomerId 注入到所有业务接口请求体

Step 6: 路由守卫（GoRouter redirect）
  └─ 未登录时自动跳转 /login 页面
```
