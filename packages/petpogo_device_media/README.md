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
