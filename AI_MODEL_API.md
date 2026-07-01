# iPet-AI 服务 API 参考

> **服务地址**: `http://49.234.39.11:8007`
> **版本**: v0.5.0
> **框架**: FastAPI
> **认证**: 无（内网服务）
> **Swagger UI**: http://49.234.39.11:8007/docs

---

## 一、语音分析

### POST /voice/analyze

上传音频文件或传入 URL → 物种识别 + 情绪分析

**请求格式**: `multipart/form-data`

| 字段 | 类型 | 说明 |
|---|---|---|
| `file` | UploadFile（二选一） | WAV/MP3/OGG，建议 1-10 秒 |
| `url`  | string（二选一）| 远程音频 URL（http/https）|

> App 使用方式：传 `url`（OSS 公开地址）

**推理流程**（三层）：
1. YAMNet 前置过滤 — 非宠物声音直接拒绝
2. 物种识别：猫 / 狗
3. 情绪识别：Top-3 情绪

**成功响应** (`success=true`)：

```json
{
  "success": true,
  "input_type": "audio",
  "detected_type": "pet",
  "species": { "label": "dog", "label_zh": "狗", "confidence": 0.98 },
  "species_label": "dog",
  "species_zh": "狗",
  "primary_emotion": { "label": "relaxed", "label_zh": "放松", "confidence": 0.72 },
  "top3_emotions": [
    { "label": "relaxed", "label_zh": "放松", "confidence": 0.72 },
    { "label": "happy",   "label_zh": "开心", "confidence": 0.18 },
    { "label": "curious", "label_zh": "好奇", "confidence": 0.06 }
  ],
  "emotions": [ /* 全部情绪概率列表 */ ],
  "advice": "你的宠物目前处于放松状态...",
  "yamnet": {
    "is_pet_sound": true,
    "sound_type": "dog_bark",
    "pet_score": 0.92,
    "top3": ["dog_bark", "whimper", "growl"]
  },
  "duration_seconds": 3.2,
  "sample_rate": 16000,
  "processing_time_ms": 245.6
}
```

**非宠物/拒绝响应** (`success=false`)：

```json
{
  "success": false,
  "reason": "not_pet_input",
  "input_type": "audio",
  "detected_type": "human_speech",
  "message": "检测到人声，不是宠物叫声",
  "yamnet": { "is_pet_sound": false, "pet_score": 0.02, ... },
  "processing_time_ms": 89.3
}
```

---

### POST /voice/analyze-url

传 JSON body（与 `/voice/analyze` 逻辑相同，仅请求格式不同）

**请求格式**: `application/json`

```json
{ "url": "https://oss.example.com/ai-voice/xxx.wav" }
```

---

### POST /voice/detect

检测音频中是否有猫/狗叫声（仅文件上传，无 URL 参数）

---

### GET /voice/emotions

获取支持的情绪类别列表

### GET /voice/species

获取支持的物种类别列表

---

## 二、图片分析

### POST /image/analyze

上传图片文件或传入 URL → 物种 + 品种 + 情绪分析

**请求格式**: `multipart/form-data`

| 字段 | 类型 | 说明 |
|---|---|---|
| `file` | UploadFile（二选一） | JPEG/PNG/WebP |
| `url`  | string（二选一）| 远程图片 URL（http/https）|

> App 使用方式：传 `url`（OSS 公开地址）

**推理流程**（两阶段）：
1. 品种分类（EfficientNet-Lite0，37 类）— 识别猫/狗及品种
2. 情绪分析：
   - 🐕 狗：4 模型集成，13 类情绪
   - 🐈 猫：3 模型集成，7 类情绪（`emotion_supported=false` 时跳过）

**成功响应** (`success=true`)：

```json
{
  "success": true,
  "input_type": "image",
  "detected_type": "pet",
  "species": "dog",
  "species_label": "dog",
  "species_zh": "狗",
  "breed": {
    "breed": "Golden Retriever",
    "species": "dog",
    "species_zh": "狗",
    "confidence": 0.88
  },
  "emotion_supported": true,
  "primary_emotion": { "label": "happy", "label_zh": "开心", "confidence": 0.65 },
  "top3_emotions": [
    { "label": "happy",   "label_zh": "开心", "confidence": 0.65 },
    { "label": "excited", "label_zh": "兴奋", "confidence": 0.21 },
    { "label": "relaxed", "label_zh": "放松", "confidence": 0.09 }
  ],
  "all_emotions": { "happy": 0.65, "excited": 0.21, "relaxed": 0.09 },
  "advice": "你的狗狗看起来很开心！",
  "classifier_loaded": true,
  "emotion_model_count": 4,
  "processing_time_ms": 312.4
}
```

> ⚠️ 猫的 `emotion_supported=false`，此时 `primary_emotion` / `top3_emotions` / `all_emotions` 均为 `null`

**非宠物响应** (`success=false`)：

```json
{
  "success": false,
  "reason": "not_pet_input",
  "input_type": "image",
  "detected_type": "non_pet",
  "message": "未检测到宠物",
  "pet_score": 0.02,
  "threshold": 0.5,
  "processing_time_ms": 124.1
}
```

---

### POST /image/analyze-url

传 JSON body（与 `/image/analyze` 逻辑相同，仅请求格式不同）

```json
{ "url": "https://oss.example.com/ai-image/xxx.jpg" }
```

### GET /image/emotions

获取支持的情绪类别列表（猫/狗）

---

## 三、视频分析

### POST /video/analyze

上传视频 → 逐帧检测猫/狗 → 截图并图片情绪分析

**请求格式**: `multipart/form-data`，字段 `file`

**成功响应**：

```json
{
  "success": true,
  "species": "dog",
  "species_zh": "狗",
  "top3_emotions": [...],
  "advice": "...",
  "capture_url": "https://oss.../capture.jpg"
}
```

---

## 四、音视频流自动分析

### POST /voice/stream/auto-analysis/settings/save
### POST /voice/stream/auto-analysis/settings/disable
### POST /voice/stream/auto-analysis/settings/delete
### POST /video/stream/auto-analysis/settings/save
### POST /video/stream/auto-analysis/settings/disable
### POST /video/stream/auto-analysis/settings/delete

请求参数：

```json
{
  "account": "用户账号",
  "device_no": "设备号",
  "effective_start_time": "08:00",
  "effective_end_time": "22:00",
  "repeat_weekdays": [1, 2, 3, 4, 5],
  "daily_analysis_count": 3,
  "enabled": true
}
```

---

## 五、AI 问诊（已在 consultation_repository.dart 中对接）

| 接口 | 说明 |
|---|---|
| `POST /session/new` | 创建问诊会话，需传 `pet_id` |
| `POST /messages` | 发送消息（同步）|
| `POST /messages/stream` | 发送消息（SSE 流式）|
| `POST /report` | 生成诊断报告 |
| `POST /session/delete` | 删除会话 |
| `POST /session/by-pet` | 按 `pet_id` 获取历史会话 |
| `POST /session/messages` | 获取会话消息列表 |

---

## 六、App 集成说明

### 语音/图片分析调用链

```
1. 录音/拍照 → 本地文件
2. POST api.jxpetai.com/sdkapi/upload/sign
   → 获取 OSS 预签名 uploadUrl + publicUrl
3. PUT <uploadUrl> → 直传 OSS（不走业务后端流量）
4. POST http://49.234.39.11:8007/voice/analyze   ← 语音
   POST http://49.234.39.11:8007/image/analyze   ← 图片
   Content-Type: multipart/form-data
   Body: url=<publicUrl>
```

### 响应字段映射（AI → App 模型）

| AI 字段 | App `AiAnalysisResult` | 备注 |
|---|---|---|
| `success` | `success` | false = 非宠物 |
| `primary_emotion` | `primaryEmotion` | `{label, label_zh, confidence}` |
| `top3_emotions` | `top3` | 列表 |
| `advice` | `advice` | AI 照顾建议文本 |
| `emotion_model_count` | `ensembleSize` | 集成模型数量 |
| `message` / `reason` | `reason` | 失败原因说明 |
| _(无 `_quota`)_ | `quota.limit=-1` | 无限制，UI 隐藏配额显示 |

### 相关代码

| 文件 | 作用 |
|---|---|
| `lib/features/home/data/repository/ai_repository.dart` | AI 接口调用、OSS 上传封装 |
| `lib/features/home/data/models/ai_result_model.dart` | `fromAiDirectJson()` 解析 AI 直连响应 |
| `lib/core/config/app_config.dart` | `aiConsultBaseUrl = "http://49.234.39.11:8007"` |
| `lib/features/consultation/data/repository/consultation_repository.dart` | AI 问诊接口 |
