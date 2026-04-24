# 🐾 PetPogo App — 项目接口与流程总览

> 📍 文件位置: `/Users/leea9/Documents/Pet/petpogo_app/PROJECT_REFERENCE.md`  
> 🕐 最后更新: 2026-04-20  
> 💡 重新打开项目时先看这个文件

---

## 一、快速启动

```bash
# 进入项目目录
cd /Users/leea9/Documents/Pet/petpogo_app

# 安装依赖
flutter pub get

# 运行（连接设备或模拟器）
flutter run

# 分析代码
flutter analyze --no-fatal-infos
```

---

## 二、项目结构

```
petpogo_app/
├── lib/
│   ├── main.dart                     # 入口
│   ├── app.dart                      # 路由 + 底部导航
│   ├── core/
│   │   ├── config/
│   │   │   ├── app_config.dart       # ⭐ API Key / 端点配置
│   │   │   └── shop_config.dart      # ⭐ 附近门店数据源切换
│   │   ├── api/                      # (待创建) 接口层
│   │   ├── models/                   # (待创建) 数据模型
│   │   └── storage/                  # (待创建) 本地存储
│   ├── features/
│   │   ├── home/                     # 🏠 首页 + AI识别
│   │   ├── bind_device/              # 📡 设备绑定流程
│   │   ├── message/                  # 💬 消息 IM
│   │   ├── community/                # 🌐 社区图文/视频
│   │   ├── mall/                     # 🛍️ 商城 + 附近门店
│   │   └── profile/                  # 👤 我的 + 设置
│   └── shared/
│       ├── theme/
│       │   ├── app_colors.dart       # 颜色系统
│       │   └── app_theme.dart        # Material3 主题
│       └── widgets/
│           └── pet_avatar.dart       # 通用头像组件
└── PROJECT_REFERENCE.md              # 👈 本文件
```

---

## 三、底部导航（5 Tab）

| Index | Tab | 路由 | 文件 | 游客可用 |
|-------|-----|------|------|----------|
| 0 | 🏠 首页 | `/` | `home/home_page.dart` | ✅ (AI识别可用) |
| 1 | 💬 消息 | `/message` | `message/message_page.dart` | ❌ 需登录 |
| 2 | 🌐 社区 | `/community` | `community/community_page.dart` | ✅ 可浏览 |
| 3 | 🛍️ 商城 | `/mall` | `mall/mall_page.dart` | ✅ 可浏览 |
| 4 | 👤 我的 | `/profile` | `profile/profile_page.dart` | ✅ 有限功能 |

### 子路由

| 路由 | 文件 | 说明 |
|------|------|------|
| `/settings` | `profile/settings_page.dart` | 设置页 |
| `/bind-device` | `bind_device/select_device_page.dart` | 选择设备 |
| `/scan-qr/:deviceType` | `bind_device/scan_qr_page.dart` | 扫二维码绑定 |

---

## 四、关键配置文件

### `lib/core/config/app_config.dart`

```dart
baseUrl        = 'https://api.ucloudlink.com/'
partnerCode    = 'GCGROUP'
clientId       = '585920816499674940a2cbae'
clientSecret   = '585920816499674940a2cbaf'
enterpriseCode = 'EA00000484'

// ⚠️ 以下需要填入：
amapAndroidKey = 'YOUR_AMAP_ANDROID_KEY'   // 高德地图
amapIosKey     = 'YOUR_AMAP_IOS_KEY'       // 高德地图
timSdkAppId    = 0                          // 腾讯云 IM
timSecretKey   = ''                         // 腾讯云 IM
translationBaseUrl = 'http://HOST:8078'     // AI识别服务
```

### `lib/core/config/shop_config.dart`

```dart
// 🔧 改这一行切换附近门店数据源
static const NearbyStoreSource nearbySource = NearbyStoreSource.amapPoi;
//                                                               ↑
//                              amapPoi = 高德POI（无需后台，立即可用）
//                              ownBackend = 自有后台（需新建接口）
```

---

## 五、后端 API 接口

### 基础信息

```
Base URL:    https://api.ucloudlink.com/
Auth:        URL 拼接 ?access_token={token}
每次请求:    Body 包含 streamNo（UUID，每次生成）
             Body 包含 loginCustomerId（用户ID）
```

### 5.1 鉴权 — 手机号登录（获取 Token）

```
POST /uclgwapp/oauth2/grant/mobile

Body:
{
  "mobile":       "13800138000",
  "smsCode":      "123456",
  "partnerCode":  "GCGROUP",
  "clientId":     "585920816499674940a2cbae",
  "clientSecret": "585920816499674940a2cbaf",
  "grantType":    "MOBILE"
}

Response:
{
  "access_token":      "xxx",
  "loginCustomerId":   "xxx",
  "expires_in":        7200
}
```

### 5.2 设备管理

#### 获取绑定设备列表
```
POST /uclgwapp/pet/device/list?access_token={token}

Body: { "loginCustomerId": "xxx", "streamNo": "uuid" }

Response:
{
  "data": [
    {
      "deviceSn":    "XXXXXXXXXXX",
      "deviceType":  "KeyTracker" | "PetPhone",
      "deviceName":  "我的KeyTracker",
      "onlineStatus": 1,          // 1=在线 0=离线
      "petId":       "xxx",
      "bindTime":    "2024-01-01"
    }
  ]
}
```

#### 获取设备属性（电量/心率/录音状态）
```
POST /uclgwapp/pet/deviceAttr/list?access_token={token}

Body:
{
  "loginCustomerId": "xxx",
  "streamNo":        "uuid",
  "deviceSn":        "XXXXXXXXXXX",
  "codeList":        ["BATTERY", "HEART_RATE", "MODE_DND", "VOICE_PARAM"]
}

Response:
{
  "data": [
    { "code": "BATTERY",    "value": "78" },
    { "code": "HEART_RATE", "value": "85" },
    { "code": "MODE_DND",   "value": "0"  }
  ]
}
```

#### 更新设备属性
```
POST /uclgwapp/pet/deviceAttr/update?access_token={token}

Body:
{
  "loginCustomerId": "xxx",
  "streamNo":        "uuid",
  "deviceSn":        "XXXXXXXXXXX",
  "code":            "MODE_DND",
  "value":           "1"
}
```

### 5.3 设备位置

```
POST /uclgwapp/pet/position?access_token={token}

Body: { "loginCustomerId": "xxx", "streamNo": "uuid", "deviceSn": "xxx" }

Response:
{
  "data": {
    "lat":       22.5431,     // GCJ02 纬度
    "lng":       113.9395,    // GCJ02 经度
    "locType":   "GPS" | "WIFI",
    "address":   "广东省深圳市南山区科技园北区",
    "updateTime": "2024-01-01 12:00:00"
  }
}
```

### 5.4 宠物信息

#### 获取宠物档案
```
POST /uclgwapp/pet/info/get?access_token={token}

Body: { "loginCustomerId": "xxx", "streamNo": "uuid" }

Response:
{
  "data": {
    "petId":     "xxx",
    "petName":   "豆豆",
    "petType":   "CAT" | "DOG",
    "petBreed":  "英短",
    "petAge":    2,
    "petGender": "MALE" | "FEMALE",
    "petAvatar": "https://..."
  }
}
```

#### 新增宠物
```
POST /uclgwapp/pet/info/add?access_token={token}

Body:
{
  "loginCustomerId": "xxx",
  "streamNo":        "uuid",
  "petName":         "豆豆",
  "petType":         "CAT",
  "petBreed":        "英短",
  "petAge":          2,
  "petGender":       "MALE"
}
```

### 5.5 好友系统

#### 获取好友列表
```
POST /uclgwapp/pet/friend/list?access_token={token}

Body: { "loginCustomerId": "xxx", "streamNo": "uuid" }

Response:
{
  "data": [
    {
      "friendId":    "xxx",
      "friendName":  "豆包的主人",
      "petName":     "豆包",
      "petType":     "CAT",
      "petAvatar":   "https://..."
    }
  ]
}
```

#### 获取好友申请记录
```
POST /uclgwapp/pet/friendLog/query?access_token={token}

Body: { "loginCustomerId": "xxx", "streamNo": "uuid", "status": 0 }
// status: 0=待处理 1=已同意 2=已拒绝
```

#### 发送好友申请
```
POST /uclgwapp/pet/friendLog/add?access_token={token}

Body:
{
  "loginCustomerId": "xxx",
  "streamNo":        "uuid",
  "targetCustomerId": "目标用户ID"
}
```

### 5.6 Agora 语音通话

```
POST /uclgwapp/pet/agora/getToken?access_token={token}

Body:
{
  "loginCustomerId": "xxx",
  "streamNo":        "uuid",
  "channelName":     "channel_xxx",
  "uid":             12345
}

Response:
{
  "data": {
    "token":       "Agora RTC Token",
    "appId":       "Agora AppId",
    "channelName": "channel_xxx",
    "uid":         12345
  }
}
```

### 5.7 AI 宠物识别（独立服务）

```
Base URL: http://YOUR_TRANSLATION_HOST:8078

POST /analyze
Content-Type: multipart/form-data

Form Data:
  audio_file: <WAV or PCM 音频文件>
  session_id: "uuid"

Response:
{
  "status": "success",
  "data": {
    "pet_type":         "cat",
    "translation":      "主人快来抱我！",
    "emotion_analysis": {
      "primary_emotion": "撒娇",
      "confidence":       0.78,
      "emotions": [
        { "name": "撒娇", "score": 0.78 },
        { "name": "开心", "score": 0.45 }
      ]
    },
    "suggestion":  "轻轻抚摸猫咪下巴",
    "audio_duration": 3.2
  }
}
```

### 5.8 音乐播放（PetPhone）

#### 获取音乐列表
```
POST /uclgwapp/pet/music/queryList?access_token={token}

Body: { "loginCustomerId": "xxx", "streamNo": "uuid", "pageNum": 1, "pageSize": 20 }
```

#### 获取播放列表
```
POST /uclgwapp/pet/music/queryPlayList?access_token={token}
```

### 5.9 围栏管理

```
// 添加围栏
POST /uclgwapp/pet/fence/add

// 删除围栏
POST /uclgwapp/pet/fence/del

// 围栏列表
POST /uclgwapp/pet/fence/list

// 更新围栏
POST /uclgwapp/pet/fence/update

Body 基础字段:
{
  "loginCustomerId": "xxx",
  "streamNo":        "uuid",
  "deviceSn":        "xxx",
  "fenceName":       "家",
  "lat":             22.5431,   // GCJ02
  "lng":             113.9395,
  "radius":          200        // 米
}
```

### 5.10 WiFi 管理

```
// 添加家庭 WiFi
POST /uclgwapp/pet/houseWifi/add

// WiFi 列表
POST /uclgwapp/pet/houseWifi/list

Body:
{
  "loginCustomerId": "xxx",
  "streamNo":        "uuid",
  "ssid":            "HomeWiFi",
  "password":        "xxxxxxxx"
}
```

---

## 六、待后台新建的接口 ⚠️

> 以下接口在现有代码库中**不存在**，需要后台团队开发

| 接口 | 用途 | 优先级 |
|------|------|--------|
| `POST /uclgwapp/merchant/nearby/list` | 附近门店列表 | 低（可用高德POI替代）|
| `POST /uclgwapp/pet/community/post/list` | 社区图文列表 | 🔴 高 |
| `POST /uclgwapp/pet/community/post/add` | 发布图文 | 🔴 高 |
| `POST /uclgwapp/pet/community/video/list` | 社区视频列表 | 🔴 高 |
| `POST /uclgwapp/pet/community/video/add` | 发布视频 | 🔴 高 |
| `POST /uclgwapp/pet/mall/banner/list` | 商城 Banner | 🟡 中 |
| `POST /uclgwapp/pet/mall/product/list` | 商品列表 | 🟡 中 |

### 附近门店接口设计草案
```
POST /uclgwapp/merchant/nearby/list?access_token={token}

Body:
{
  "loginCustomerId": "xxx",
  "streamNo":        "uuid",
  "lat":             22.5431,    // GCJ02
  "lng":             113.9395,
  "radius":          5000,       // 米
  "sortType":        "DISTANCE" | "SALES" | "RATING",
  "pageNum":         1,
  "pageSize":        20
}

Response:
{
  "data": {
    "list": [
      {
        "storeId":   "xxx",
        "storeName": "聚宠生活馆 南湾店",
        "storeType": "附件门店",
        "rating":    5.0,
        "sales":     238,
        "address":   "南湾街道南岭村...",
        "distance":  1200,        // 米
        "lat":       22.5431,
        "lng":       113.9395,
        "imageUrl":  "https://...",
        "tags":      ["宠物用品", "PetPhone授权"]
      }
    ],
    "total": 1
  }
}
```

---

## 七、用户登录状态流程

```
App 启动
    │
    ▼
读取本地 Token (flutter_secure_storage)
    │
    ├─ Token 存在 ──► 验证有效性 ──► 进入主界面（正式用户）
    │                     │
    │                  过期/无效 ──► 自动登出 ──► 游客模式
    │
    └─ Token 不存在 ──► 游客模式
                            │
                    触发以下操作时弹出绑定弹窗：
                    ├─ 绑定设备
                    ├─ 发布内容
                    ├─ 发送消息
                    └─ 访问个人设置
                            │
                            ▼
                    输入手机号 → 获取短信验证码 → 登录
                    POST /uclgwapp/oauth2/grant/mobile
                            │
                            ▼
                    保存 access_token + loginCustomerId
                    → 进入正式用户状态
```

---

## 八、设备绑定流程

```
首页点击"添加设备"
    │
    ▼ （游客则先触发手机绑定）
选择设备类型 (/bind-device)
    ├─ KeyTracker（黑色追踪器）
    └─ PetPhone（粉色宠物手机）
    │
    ▼
扫描设备背面二维码 (/scan-qr/:deviceType)
    │
    ├─ 需要相机权限（permission_handler）
    └─ 扫到二维码 → 解析设备 SN 码
    │
    ▼
POST /uclgwapp/user/device/phone/mobile/bind
Body: { deviceSn, loginCustomerId, streamNo }
    │
    ▼
绑定成功 → 返回首页 → 显示设备卡片
```

---

## 九、AI 识别流程

```
首页 AI 识别面板（游客可用）
    │
    ▼
长按录音按钮
    │ (record 插件录音，PCM/WAV 格式)
    │
    ▼
松开 → 停止录音
    │
    ▼
POST http://TRANSLATION_HOST:8078/analyze
multipart/form-data: audio_file + session_id
    │
    ├─ 成功 ──► 展示情绪卡片
    │           ├─ 识别文字
    │           ├─ 情绪百分比（撒娇78% / 开心45%）
    │           └─ 互动建议
    │
    └─ 失败 ──► 显示错误提示，可重试
```

---

## 十、依赖包版本

```yaml
flutter_riverpod:      ^2.5.1    # 状态管理
go_router:             ^14.2.7   # 路由
dio:                   ^5.4.3    # 网络请求
flutter_secure_storage:^9.0.0    # Token 安全存储
hive_flutter:          ^1.1.0    # 本地缓存
google_fonts:          ^6.2.1    # NotoSansSC 字体
lottie:                ^3.1.2    # Lottie 动画
flutter_animate:       ^4.5.0    # 微动画
cached_network_image:  ^3.3.1    # 图片缓存
video_player:          ^2.8.6    # 视频播放
record:                ^5.1.2    # 录音
mobile_scanner:        ^5.2.3    # 二维码扫描
```

---

## 十一、开发进度

| 阶段 | 内容 | 状态 |
|------|------|------|
| Phase 1 | 框架骨架 + 5Tab导航 + 主题 | ✅ 完成 |
| Phase 2 | 首页 + AI识别 + 设备卡 | ✅ UI完成，API待接入 |
| Phase 2 | 设备绑定流程（扫码）| ✅ UI完成，API待接入 |
| Phase 3 | 社区图文瀑布流 + 短视频 | ✅ UI完成，API待后台 |
| Phase 4 | 消息页 + IM聊天 | ✅ UI完成，腾讯IM待配置 |
| Phase 5 | 商城首页 + 附近门店 | ✅ UI完成，API待后台 |
| Phase 5 | 我的 + 设置页 | ✅ UI完成 |
| - | API 真实接入（Dio client）| 🔲 待开始 |
| - | 腾讯云 IM 配置 | 🔲 待配置 SDKAppID |
| - | 高德地图集成 | 🔲 待配置 AmapKey |
| - | 游客/登录状态管理（Riverpod）| 🔲 待开始 |
| - | 手机号登录弹窗 | 🔲 待开始 |
| - | 后台社区/商城接口对接 | 🔲 等后台开发 |

---

## 十二、坐标系说明

| 坐标系 | 使用场景 |
|--------|----------|
| **GCJ02** | 高德地图显示、后台存储、设备上报 |
| WGS84 | GPS 原始坐标（需转换为 GCJ02 再用）|
| BD09 | 百度地图（本项目不用）|

> ⚠️ 后台返回的所有坐标均为 **GCJ02**，直接传给高德地图 SDK 使用，无需转换。

---

## 十三、腾讯云 IM 配置（待填入）

1. 登录 [腾讯云 IM 控制台](https://console.cloud.tencent.com/im)
2. 创建应用 → 获取 `SDKAppID`
3. 在控制台生成 `SecretKey`
4. 填入 `lib/core/config/app_config.dart`:
   ```dart
   static const int    timSdkAppId  = 123456789;  // 填入
   static const String timSecretKey = 'xxxxxxxx';  // 填入
   ```

---

## 十四、高德地图配置（待填入）

1. 登录 [高德开放平台](https://console.amap.com/)
2. 创建应用 → 添加 Key（Android + iOS 各一个）
3. Android Key 需要 SHA1 + 包名 (`com.ucloudlink.petpogo_app`)
4. 填入 `lib/core/config/app_config.dart`:
   ```dart
   static const String amapAndroidKey = 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx';
   static const String amapIosKey     = 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx';
   ```
5. Android 还需在 `android/app/src/main/AndroidManifest.xml` 添加:
   ```xml
   <meta-data android:name="com.amap.api.v2.apikey" android:value="YOUR_KEY"/>
   ```

---

## 十五、设计系统：The Curated Companion

> ⭐ **所有 UI 开发必须遵循本设计系统**。本系统定义了 PetPogo 的唯一视觉语言。

### 15.1 创意北极星 (Creative North Star)

**"The Organic Concierge"** — 将高端生活方式杂志的编辑感与值得信赖的宠物医生的亲切感融合。

核心手法：
- **有意的不对称（Intentional Asymmetry）**：宠物图片有时突破容器边界
- **色调深度（Tonal Depth）**：通过柔和的色彩转换来定义层级，而非刚硬的线条

---

### 15.2 颜色系统 (Color & Tonal Architecture)

#### Token 映射表

| Token | Hex | 用途 |
|-------|-----|------|
| `primary` | `#a83206` | 主要按钮、强调色、品牌 Logo |
| `primary-dim` | `#8a2805` | 按钮 Hover 状态 |
| `primary-container` | `#ffdad5` | 主色调容器背景 |
| `on-primary` | `#ffffff` | 主色按钮上的文字 |
| `secondary` | `#3db9b0` | 次要按钮、输入框焦点底部线、支持性操作 |
| `secondary-container` | `#7fe6db` | 次要按钮背景 |
| `secondary-fixed` | `#a8f0ea` | 正向状态 Badge（如"已疫苗") |
| `surface` | `#fff4f3` | 最底层画布 Canvas |
| `surface-container-low` | `#ffedeb` | 大块结构分组背景 |
| `surface-container` | `#ffe5e3` | 输入框背景 |
| `surface-container-highest` | `#ffd2cf` | 最顶层浮动卡片 |
| `on-surface` | `#4e2120` | **所有正文文字**（禁止用纯黑 #000） |
| `on-surface-variant` | `#7a4442` | 次要文字、副标题 |
| `outline-variant` | `#e8b4b1` | Ghost Border（仅在必须用时，15% 透明度）|
| `error-container` | `#ffdad5` | 警告 Badge（如"待复诊"）|

#### "No-Line" 规则 ⚠️
> **禁止使用 1px solid 边框分割内容。** 所有分区通过背景色切换来定义。

#### "Glass & Gradient" 规则
- **玻璃态导航栏**：`surface`色 70% 透明度 + `backdrop-blur: 24px`
- **Hero CTA 渐变**：从 `primary` → `primary-container` 线性渐变，产生"光晕"效果

---

### 15.3 字体系统 (Typography)

**字体族：Plus Jakarta Sans**（Google Fonts）

| 级别 | 大小 | 字重 | 字距 | 用途 |
|------|------|------|------|------|
| `display-lg` | 3.5rem | 700 | -0.02em | 超大 Hero 标题 |
| `display-md` | 2.8rem | 700 | -0.02em | 大 Hero 标题 |
| `display-sm` | 2.25rem | 600 | -0.02em | 中 Hero 标题 |
| `headline-lg` | 2rem | 600 | -0.01em | 页面主标题 |
| `headline-md` | 1.75rem | 600 | -0.01em | 区块标题 |
| `title-lg` | 1.375rem | 600 | 0 | 卡片宠物名 |
| `title-md` | 1.125rem | 500 | 0 | 列表项标题 |
| `body-lg` | 1rem | 400 | 0 | 正文描述 |
| `body-md` | 0.875rem | 400 | 0 | 品种/详情文字 |
| `body-sm` | 0.75rem | 400 | 0 | 辅助说明 |
| `label-md` | 0.875rem | 500 | 0.01em | 元数据标签（品种、年龄）|
| `label-sm` | 0.75rem | 500 | 0.01em | 小标签 |

> ❌ 禁止使用系统默认字体。

---

### 15.4 层级与阴影 (Elevation & Depth)

#### 色调分层原则（替代传统阴影）
- **自然浮起**：将 `surface-container-lowest` 卡片放在 `surface-container-low` 区块上
- **必须浮动的元素**（FAB、Modal）使用"环境阴影 Ambient Shadow"：
  - 颜色：`on-surface` (#4e2120) at **6% opacity**
  - Blur：40px ~ 60px
  - Spread：-5px

> ❌ 禁止使用默认灰色阴影。阴影必须带有品牌棕红色调。

---

### 15.5 组件规范 (Components)

#### 按钮

| 类型 | 背景 | 文字 | 圆角 | 用途 |
|------|------|------|------|------|
| Primary | `primary` (#a83206) | `on-primary` (#fff) | 3rem (pill) | 主要操作 |
| Secondary | `secondary-container` (#7fe6db) | `on-surface` | 3rem (pill) | 支持性操作 |
| Hover | `primary-dim` (#8a2805) | — | — | 鼠标悬停 |
| Press | 内阴影模拟"按下" | — | — | 点击态 |

#### 卡片
- ❌ 禁止卡片内使用分割线
- 宠物名（`title-lg`）和品种（`body-md`）之间用 **16px 或 24px 垂直空白** 分隔
- 宠物图片使用 `2rem` 圆角；图片可"破顶"溢出卡片边缘制造视觉张力

#### 输入框
- 背景：`surface-container`
- 焦点时：底部 3px 线条，颜色为 `secondary` 青绿色（非全边框）

#### 状态 Badge
- 正向（已疫苗等）：`secondary-fixed` 背景
- 警告（待复诊等）：`error-container` 背景

#### 图标规范
- 风格：**Open-Line（描线）**，禁止使用填充型图标
- 描边粗细：1.5pt

---

### 15.6 Do's & Don'ts

#### ✅ Do
- 拥抱空白。感觉拥挤时，把 padding 加到下一档
- 不对称图片摆放。让猫从右边缘望进来比居中正方形更有张力
- 用 `surface-tint` 做背景品牌色渲染

#### ❌ Don't
- 不用纯黑 `#000000` 作文字色，用 `on-surface` (#4e2120)
- 不用 1px 分割线。想加分割线？改成 24px 额外白空间
- 不用默认灰色阴影。阴影颜色必须带品牌棕红调

---

### 15.7 UI 参考截图

以下四张截图为设计基准，所有页面风格应与之一致：

| 首页 (Home) | 社区 (Community) | 商城 (Mall) | 我的 (Profile) |
|------------|-----------------|------------|---------------|
| AI识别 + 设备卡片 | 瀑布流宠物内容 | 商品 + 附近门店 | 用户信息 + 宠物列表 |

> 关键视觉特征：暖粉底色(`#fff4f3`)、棕红主色(`#a83206`)、圆润卡片、无边框分区、Plus Jakarta Sans 字体
