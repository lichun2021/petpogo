# PetPogo 设备媒体

本地 Flutter 插件，不访问网络。Android 使用 AudioTrack、MediaCodec、MediaMuxer，iOS 使用 AVAudioEngine、AVAssetWriter。用于当前硬件 WebSocket 的 JPEG + PCM（16kHz、单声道、s16le）协议。

## 客户端链路

- `lib/features/device/stream/device_stream_api.dart`：复用 SDKAPI Peer HTTP 中转启动/停止，完整使用返回的 `wsAppUrl`。
- `device_stream_session.dart`：观看、重连、页面退出、PCM 对讲；每 15 秒 WebSocket ping。
- `jpeg_stream_view.dart`：只保留最新待解码帧，不使用全局图片缓存保存每一帧。
- `device_audio_io.dart`：按 640 字节 / 20ms 发送对讲，限制排队长度；本地音量不关闭其他观看者的设备音频。
- `http_motor_controller.dart`：行走统一使用原 `/device/shadow/update`，串行请求、合并中间移动指令，松手发送停止。
- `local_stream_recorder.dart`：最长约 30 秒，临时文件逐帧写入，使用单调时间戳。结束后本地导出 H.264/AAC MP4；无设备音频时导出纯视频。默认只录制设备声音，不混入手机对讲声。

原生 MP4 导出在工作线程执行，长边最多 1280；保留实际帧时间，PCM 按 16kHz 时间线补静音。失败保留临时素材，成功清理素材。相册保存和 OSS 上传沿用 App 现有流程；退出/账号切换关闭观看和麦克风，后台持续录像暂不支持。

## 方法通道

`petpogo/device_media`：`openAudio`、`feedAudio(Uint8List)`、`setVolume(0..1)`、`closeAudio`、`encodeRecording(manifestPath)`。

清单 JSON 包含 `frames: [{path, timeUs}]`、`audioPath`（裸 PCM）、`durationUs` 和 `outputPath`。路径由 App 临时目录生成，不来自远程接口。

## 验证

```sh
flutter test --no-pub test/device_stream_test.dart test/device_battery_test.dart
flutter run -t integration_test/device_media_smoke.dart -d <模拟器或测试设备>
```

冒烟入口不连接机器人，也不使用手机麦克风；验证原生 PCM 播放通道、实际 MP4 导出以及系统播放器初始化，并检查 H.264/AAC 音视频轨道。`DEVICE_MEDIA_SMOKE_OK` 表示通过。

当前阶段按硬件约定支持 `ws://49.234.39.11:8006`，平台网络例外只限定到 `49.234.39.11`。未来鉴权参数保留在返回的完整 URL 中；WSS 和媒体连接鉴权由后续对接提供。不要记录媒体 URL 查询参数、登录凭证或音频内容。

## 客户端视频诊断

调试包运行时执行 `./log.sh --video`；`--dump` 读取当前进程的历史快照后退出；`--stream <streamId>` 筛选某次观看。App 重启后需重新运行实时日志命令以获取新的 PID。发布包仅记录告警和错误，完整链路须使用调试包。

每条日志包含 `streamId`（本次观看）、`attempt`（连接尝试次数）、`deviceMac`、中文 `stage` / `message`、`elapsedMs`（本次连接尝试开始后的时间）。请求和解码另有 `durationMs`。首条会话日志记录系统、App 版本和 API 环境；WebSocket 地址保留主机与路径，移除鉴权查询参数。

| 事件 / diagnosis | 含义或卡住的位置 |
| --- | --- |
| `start.request` → `start.response` | 请求后台启动推流，检查请求耗时和业务码 |
| `ws.connect.begin` → `ws.connect.ok` | 连接媒体中转；10 秒握手超时、网络错误单独记录 |
| `ws.first_message` → `video.first_packet` | 收到 WS 消息并解析出第一帧视频 |
| `packet.rejected` / `protocol_rejected` | 二进制头部、长度或类型不符，包含具体 reason 和声明 / 实收字节数 |
| `jpeg.decode.begin` → `jpeg.decode.ok` | 第一帧开始解码并得到图片尺寸、耗时 |
| `jpeg_decode_failed` | 视频包已到达，图片内容不能解码 |
| `video.presented` | 第一帧已进入实际绘制流程；包含视图、尺寸和收包到绘制耗时 |
| `decoded_but_not_painted` | 解码成功但视图尚未绘制 |
| `waiting_for_websocket_data` | 手机 WS 已连接，尚未收到任何数据 |
| `device_not_connected_to_relay` | 最近 30 秒内的状态查询确认设备未接入媒体中转 |
| `audio_only_no_video` / `text_messages_only` | 仅收到音频 / 文本，没有有效视频 |
| `video_stalled` | 先前显示过画面，但超过 5 秒未收到新视频帧 |
| `paint_stalled_or_view_hidden` | 收包和解码有进展，绘制中断或视图隐藏；结合页面生命周期查看 |
| `video_playing` | 收包、解码、绘制均已发生；结合帧率判断流畅度 |

`health` 每 5 秒汇总消息数、收取字节数、视频 / 音频 / 无效帧数、解码 / 绘制 / 失败 / 待解码替换数，以及收包 / 解码 / 绘制帧率和最近一次进展的间隔。全屏和内嵌视图可能同时解码，解码 / 绘制数是视图合计。等待或断流时每 15 秒查询一次只读媒体状态，记录 `deviceConnected`、`appViewerCount` 和 `statusAgeMs`；查询失败不会中断观看，也不会把未知状态当作设备离线。

音频另外标出原生播放初始化、首包 PCM 交付、播放错误，以及麦克风权限、采集、首包对讲发送和停止。交付原生播放通道或 WebSocket 仅表示客户端已交付，不表示机器人扬声器已经播出。断线日志包含关闭码、原因和重连延迟；退出、后台切换、视图挂载 / 卸载均可追踪。

日志只记录链路元数据，不记录 JPEG / PCM 内容、文本消息正文、请求头、密码或 URL 中的凭证。高频帧只计数；失败按前几次及指数间隔采样，避免日志本身影响播放。

## 对讲流程日志

运行 `./log.sh --talk`，然后在手机点击开启对讲；`./log.sh --talk --dump` 可读取历史快照。该筛选同时保留媒体 WS、重连、音频播放和页面退出事件，便于判断对讲与连接中断的先后关系。完整音视频日志继续使用 `--video`。

一次观看内每次开启对讲递增 `talkAttempt`，与 `streamId`、`attempt` 一起定位本次操作。日志顺序如下：

| 事件（省略 `device.stream.` 前缀） | 含义 |
| --- | --- |
| `talk.start.begin` / `talk.toggle.ignored` | 用户切换对讲，或因连接、忙碌状态未执行 |
| `talk.permission.check` / `request` / `result` | 当前权限、是否发起系统授权及授权结果 |
| `talk.audio_session.begin` / `ok` | iOS 录音与播放会话配置 |
| `talk.capture.start.request` / `ok` / `failed` | 请求创建原生录音流，记录 PCM 参数、音源、回声消除及耗时 |
| `talk.recorder.state` | 原生录音插件的 record / pause / stop 状态 |
| `talk.capture.first_batch` | 收到第一批麦克风 PCM，记录字节数和等待时间 |
| `talk.packet.first_ready` | 拼好第一包 640 字节、20ms PCM |
| `talk.first_packet.sent` | 首包交付 WebSocket，记录 type=3、9 字节头部加 640 字节 PCM 的总长度及时间戳 |
| `talk.health` | 每 5 秒汇总采集批数、字节数、生成包数、排队 / 丢弃 / 发送包数及最近进展间隔 |
| `talk.capture.failed` / `talk.send.failed` | 区分麦克风流异常和 WebSocket 发送异常；记录错误并清理录音，保留观看会话 |
| `talk.stop.begin` / `talk.cleanup.begin` / `ok` / `failed` | 停止和资源释放过程，以及清空前的队列和发送统计 |

`health.diagnosis` 可区分 `microphone_no_data`（已启动但无 PCM）、`microphone_capture_stalled`（采集中断超过 3 秒）、`pcm_not_enough_for_packet`（数据不足一包）、`microphone_pcm_all_zero`（累计样本全部为零）、`waiting_for_websocket_send` 和 `talk_sending`。`pcmPeak` 与 `nonZeroSamples` 是累计信号统计，不包含音频内容；全零不能单独证明硬件损坏或权限异常。客户端发送成功只能确认交付本机 WebSocket，设备接收和扬声器播放仍需硬件端确认。

原生错误记录 `errorCode`、`errorMessage`、脱敏并限长的字符串 `errorDetails` 和前几层 `errorStack`。不输出音频样本或完整异常对象。发送异常会被捕获并记录，不再只成为未处理的定时器异常。

## 录像流程日志

使用 `./log.sh --record` 实时查看，`--dump` 读取历史后退出，`--recording <recordingId>` 筛选某一段录像。此模式也保留相关的媒体连接、后台切换和音频播放事件。每段录像固定 `recordingId` 及开始时的 `streamId` / `attempt`；重连或下一段录像不会覆盖正在上传的上一段录像的日志上下文。录像事件的 `elapsedMs` 从点击开始录像时计时，各步骤另有 `durationMs`。

| 事件（省略 `device.stream.record.`） | 诊断环节 |
| --- | --- |
| `start.begin` / `start.ignored` | 开始入口，或因无视频、未连接、正在处理而未执行 |
| `album.permission.result` / `request` | 相册访问权限与系统授权结果 |
| `local.start.begin` / `ok` | 创建 JPEG / PCM 临时素材目录；仅记录目录末级名称 `sourceFolder` |
| `video.first_written` / `audio.first_buffered` | 首帧已写盘；第一包设备声音已加入缓冲，刷盘稍后进行 |
| `health` / `video.dropped` | 每 5 秒记录收到和写入的帧数、音频包数与字节、待写帧、丢帧、补齐静音样本数及最近画面间隔 |
| `stop.begin` / `sources.flushed` | 停止原因和 JPEG / PCM 刷盘结果；区分手动、30 秒上限、断线、退后台与返回页面 |
| `manifest.ready` | 编码所需素材清单已生成 |
| `encode.begin` / `encode.waiting` / `encode.ok` | 调用原生编码，每 5 秒报告等待耗时，返回后检查 MP4 非空并记录文件大小；等待日志不表示原生编码百分比或具体内部进度 |
| `sources.cleanup.begin` / `ok` | 编码成功后清理 JPEG、PCM、清单并保留 MP4 |
| `album.save.begin` / `ok` | 系统相册保存结果，与生成本地 MP4 分开记录 |
| `upload.sign.begin` / `ok` | 申请 OSS 上传凭证，不记录地址、签名及对象 Key |
| `upload.file.begin` / `progress` / `waiting` / `ok` | 文件字节数、约 25% 间隔的发送进度和等待时长；100% 仅表示已发送，`ok` 表示 OSS 已返回成功 |
| `library.save.begin` / `ok` / `upload.complete` | 后端登记媒体记录，完成相册、OSS 和媒体库全流程 |
| `start.failed` / `finish.failed` / `save.failed` / `upload.failed` | 中文失败阶段、错误码、脱敏错误及调用栈，并按已知状态记录本地 MP4 / 源素材是否保留 |
| `cancel.begin` / `ok` / `failed` | 未导出录像的取消与临时素材清理 |

只有 `encode.ok` 能确认本地 MP4 已生成且非空，`album.save.ok` 确认存入系统相册，`library.save.ok` 确认后端媒体记录写入。编码或输出校验失败会保留源素材；上传未发起或失败也会记录原因。日志不包含 JPEG、PCM、完整本地路径或上传凭证。

## 录像回放

设备图库的 Android 录像回放使用已有 media_kit 的软件解码，避免部分设备的 MediaCodec 解码器在缓冲区分配或启动时失败；其他平台保留系统播放器。播放器统一捕获打开失败、运行中错误与释放错误，并提供重试；退出页面或重试会先释放旧播放器。

打开录像时覆盖整个应用页面，隐藏全局底部导航；返回图库后自动恢复。

`./log.sh --record` 包含 `record.playback.open.begin`、`open.ok`、`first_frame`、`health`、`failed` 和 `dispose.*` 事件。日志用 `playbackId`、`mediaId` 与尝试次数定位一次回放，记录后端、是否软件解码、首帧输出、时长、位置及缓冲状态；不记录完整地址或签名。`open.ok` 仅表示打开请求完成，Android 的 `first_frame` 表示视频输出已收到首帧。打不开时 30 秒超时会结束等待并进入重试界面。
