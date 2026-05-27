# 宠小伊 AI 问诊 — 完整实施方案

> **AI 医生名称**：宠小伊（ChongXiaoYi）  
> **后端地址**：`http://49.234.39.11:8007`  
> **宠物ID方案**：方案 A — 直接使用 PeerApi 的 `petId` 字段  
> **报告类型**：三类独立页面（宠小伊问诊报告 / 治疗养护建议 / 医疗检测方案）

---

## 完整文件清单

### 🆕 新建文件（共 10 个）

| 文件路径 | 说明 |
|---|---|
| `lib/features/consultation/data/models/consultation_models.dart` | 数据模型（Session、消息、三类报告） |
| `lib/features/consultation/data/repository/consultation_repository.dart` | API 封装（SSE 解析 + 3个接口） |
| `lib/features/consultation/controller/consultation_controller.dart` | Riverpod 状态管理 |
| `lib/features/consultation/consultation_page.dart` | 主聊天页 |
| `lib/features/consultation/report_list_page.dart` | 报告入口列表页（三块卡片） |
| `lib/features/consultation/report_diagnosis_page.dart` | ① 宠小伊问诊报告页 |
| `lib/features/consultation/report_care_page.dart` | ② 治疗养护建议页 |
| `lib/features/consultation/report_medical_page.dart` | ③ 医疗检测方案页 |
| `lib/features/home/widgets/ai_consultation_banner.dart` | 首页入口 Banner 卡片 |
| `lib/features/home/widgets/pet_picker_sheet.dart` | 宠物选择底部弹窗 |

### ✏️ 修改文件（共 3 个）

| 文件路径 | 修改内容 |
|---|---|
| `lib/features/home/home_page.dart` | 在 AiImagePanel 下方插入 AiConsultationBanner |
| `lib/core/router/app_routes.dart` | 新增问诊相关路由常量 |
| `lib/core/router/app_router.dart` | 注册 consultation 和 report 路由 |

---

## 分步实施计划（9步）

### Step 1 — 数据模型

**文件**：`lib/features/consultation/data/models/consultation_models.dart`

```
ConsultationSession
  - session_id: String
  - pet_id: String
  - pet_info: PetInfoSnapshot（名字/品种/年龄/体重）

ChatMessage
  - role: 'user' | 'assistant'
  - content: String
  - isStreaming: bool（流式输出中标志）
  - timestamp: DateTime

ConsultationReport（完整报告对象，从 POST /report 返回）
  - report: String（综合描述）
  - diseaseCards: List<DiseaseCard>
  - medicalSolutions: String（医疗检测方案）
  - careSuggestions: String（养护建议，从 report 中提取）
  - symptomSummary: String
  - primaryDisease: String

DiseaseCard
  - diseaseName: String
  - diseaseType: String
  - probability: String（"65%"）
  - definition: String
  - cause: String
  - symptoms: String
  - diagnosis: String
  - treatment: String
```

---

### Step 2 — Repository（API 层）

**文件**：`lib/features/consultation/data/repository/consultation_repository.dart`

**4个方法：**

```dart
// ① 创建 Session
Future<ConsultationSession> createSession(String petId)
  → GET /session/new?pet_id={petId}

// ② 流式问诊（核心，SSE 解析）
Stream<String> streamMessage(String sessionId, String text)
  → POST /messages/stream
  → 解析 event: delta → data: { "text": "..." }
  → yield 每个 text 片段
  → event: done 时 close stream

// ③ 生成报告
Future<ConsultationReport> generateReport(String sessionId)
  → POST /report

// ④ 删除 Session（退出时调用）
Future<void> deleteSession(String sessionId)
  → POST /session/delete
```

**SSE 解析逻辑（关键）：**
```dart
// 使用 http package 的 Client.send() 获取流式响应
// 逐行读取，按 \n\n 分帧
// 解析 event: 和 data: 行
// 遇到 event: error → 抛出异常
// 遇到 event: done → 关闭流
```

**Reqable 调试配置：**
```dart
// 在 debug 模式下打印每个 SSE 帧
if (kDebugMode) debugPrint('[SSE] event=$event data=$data');
```

---

### Step 3 — Controller（状态管理）

**文件**：`lib/features/consultation/controller/consultation_controller.dart`

**状态对象：**
```dart
class ConsultationState {
  final ConsultationSession? session
  final List<ChatMessage> messages
  final bool isStreaming       // AI 正在打字
  final bool isLoading         // 创建 session / 生成报告中
  final ConsultationReport? report
  final String? errorMessage
  final bool reportReady       // AI 已给出 <诊断> 标签，可生成报告
}
```

**Notifier 方法：**
```dart
Future<void> initSession(String petId)   // 创建session + AI主动问候
Future<void> sendMessage(String text)    // 发消息 + 接收SSE流
Future<void> generateReport()           // 生成报告
void dispose()                           // 删除session
```

**流式文字处理：**
- 发送消息后，先在 messages 列表末尾追加一个空的 assistant 消息（isStreaming=true）
- 每收到 SSE delta，拼接到该消息的 content
- 收到 done，标记 isStreaming=false
- 检测 content 是否包含 `<诊断>` → 若是，设 reportReady=true

---

### Step 4 — 首页入口 Banner

**文件**：`lib/features/home/widgets/ai_consultation_banner.dart`

**视觉设计：**
```
┌─────────────────────────────────────┐
│  🩺  宠小伊 · AI 问诊               │
│      描述您的宠物症状，立即获得      │
│      专业 AI 诊断建议                │
│                        [ 立即问诊 → ]│
└─────────────────────────────────────┘
```

- 背景：青绿渐变（AppColors.secondary → 浅青）
- 图标：医疗圆形头像 + 脉冲动画
- 点击 → 弹出 PetPickerSheet

---

### Step 5 — 宠物选择 BottomSheet

**文件**：`lib/features/home/widgets/pet_picker_sheet.dart`

**交互流程：**
1. 从 `deviceListProvider` 取设备列表
2. 并发调 PeerApi 获取每台设备绑定的宠物
3. 显示宠物卡片列表（横向滑动，仿截图第一屏样式）
4. 用户选中宠物后，点击"去问诊"
5. 调 `context.push('/consultation', extra: petId)`

**特殊情况：**
- 无宠物 → 提示"请先绑定设备并添加宠物"
- 加载中 → 显示骨架屏

---

### Step 6 — 主聊天页

**文件**：`lib/features/consultation/consultation_page.dart`

**页面结构：**
```
AppBar
  - 返回按钮
  - 宠物头像 + 名字
  - 二维码按钮（暂不实现）

Body（聊天消息列表）
  ┌─ AI 消息气泡（左对齐）
  │   宠小伊头像 🩺 + 聊天气泡
  │   流式时：打字机光标闪烁
  │
  └─ 用户消息气泡（右对齐）

报告准备区（当 reportReady=true）
  ┌────────────────────────────────┐
  │ 📋 宠小伊问诊报告  已生成    │
  │ 🏥 治疗养护建议     已生成    │
  │ 🔬 医疗检测方案     已生成    │
  └────────────────────────────────┘

底部输入栏
  [ 生成报告 ]  [ 设备数据 ]
  [ 请输入问题...          ] [发送]
```

**关键细节：**
- 流式时，底部输入框禁用，显示"宠小伊正在回复…"
- 收到 `<追问>` 标签时，提取追问内容用不同样式高亮显示
- 收到 `<诊断>` 标签时，"生成报告"按钮高亮变绿

---

### Step 7 — 报告入口列表页

**文件**：`lib/features/consultation/report_list_page.dart`

仿照截图（第二行最左屏）：

```
┌──── 宠小伊问诊报告 ────────────────┐
│  📋  宠小伊智能宠医已开出诊断，       │
│      请点击查看详情           →      │
└──────────────────────────────────┘

┌──── 治疗养护建议 ─────────────────┐
│  🏠  已生成在家处理建议，           │
│      请点击查看详情           →    │
└──────────────────────────────────┘

┌──── 医疗检测方案 ─────────────────┐
│  🔬  已生成医疗处理建议，           │
│      请点击查看详情           →    │
└──────────────────────────────────┘
```

三张卡片各自跳转对应报告页。

---

### Step 8 — 三类报告页

#### ① `report_diagnosis_page.dart` — 宠小伊问诊报告

内容来源：`report.diseaseCards` + `report.report`

```
┌── 综合描述（report 字段） ────────────────┐
│  文字段落，展示 AI 综合分析              │
└──────────────────────────────────────┘

┌── 疾病卡片列表（diseaseCards） ─────────┐
│  疾病名称      患病概率: 65%  ████░ │
│  定义 / 病因 / 临床表现 展开折叠         │
└──────────────────────────────────────┘
```

#### ② `report_care_page.dart` — 治疗养护建议

内容来源：`report.medicalSolutions` 中关于"在家处理"部分

```
┌── 建议标题 ──────────────────────────┐
│  • 建议条目 1                         │
│  • 建议条目 2                         │
│  …                                   │
└──────────────────────────────────────┘
（LAKI助手风格：宠小伊气泡 + 建议文字）
```

#### ③ `report_medical_page.dart` — 医疗检测方案

内容来源：`report.medicalSolutions` 医院检测部分

```
┌── 检测项目卡片 ──────────────────────┐
│  检测名称         概率分析 55%  ████│
│  说明文字                             │
└──────────────────────────────────────┘
```

> [!NOTE]
> 三类报告的详细 UI 待用户提供截图后完善，目前按截图中可见信息实现基础版。

---

### Step 9 — 路由注册

**修改** `app_routes.dart`：
```dart
static const consultation     = '/consultation';
static const reportList       = '/consultation/report';
static const reportDiagnosis  = '/consultation/report/diagnosis';
static const reportCare       = '/consultation/report/care';
static const reportMedical    = '/consultation/report/medical';
```

**修改** `app_router.dart`：
```dart
GoRoute(
  path: AppRoutes.consultation,
  builder: (context, state) => ConsultationPage(
    petId: state.extra as String,
  ),
  routes: [
    GoRoute(path: 'report',           builder: ...ReportListPage),
    GoRoute(path: 'report/diagnosis', builder: ...ReportDiagnosisPage),
    GoRoute(path: 'report/care',      builder: ...ReportCarePage),
    GoRoute(path: 'report/medical',   builder: ...ReportMedicalPage),
  ],
),
```

---

## Reqable 调试指南

### 调试 SSE 流式接口

1. 打开 Reqable → 设置手机/模拟器代理到 `电脑IP:8888`
2. 过滤 host `49.234.39.11:8007`
3. 发起问诊消息后，在 Reqable 中可看到：
   - 请求：`POST /messages/stream`，body `{ session_id, text }`
   - 响应：`Content-Type: text/event-stream`，逐行显示 SSE 帧

### 手动测试 API 的 Reqable 脚本

在 Reqable 中新建 API 集合：
```
📁 宠小伊问诊
  ├── GET  /session/new?pet_id=demo_pet_001
  ├── POST /messages/stream  body: { session_id, text }
  ├── POST /messages         body: { session_id, text }（同步，调试用）
  ├── POST /report           body: { session_id }
  └── POST /session/delete   body: { session_id }
```

### Debug 日志
代码中所有关键节点打印 `[宠小伊]` 前缀日志：
```dart
debugPrint('[宠小伊] createSession petId=$petId');
debugPrint('[宠小伊] SSE frame event=$event data=$data');
debugPrint('[宠小伊] reportReady = true');
```

---

## 开发顺序建议

```
Step 1 → Step 2 → Step 3   先打通后端调用链（无 UI）
    ↓
Step 4 → Step 5             首页入口 + 宠物选择
    ↓
Step 6                      聊天页（核心交互）
    ↓
Step 7 → Step 8             报告相关页面
    ↓
Step 9                      注册路由，全链路验收
```

---

## 完成后验收标准

- [ ] 首页显示"宠小伊 AI 问诊"入口卡片
- [ ] 点击入口可选择宠物
- [ ] 进入聊天页，宠小伊主动发送欢迎语
- [ ] 输入症状，AI 流式打字回复（Reqable 可抓到 SSE 帧）
- [ ] 多轮对话后，AI 给出 `<诊断>` → "生成报告"高亮
- [ ] 点击生成报告 → 进入三类报告列表页
- [ ] 三类报告页各自独立展示
- [ ] 退出聊天时自动删除 session
- [ ] 遇到 404（session 过期）自动重建并重试
