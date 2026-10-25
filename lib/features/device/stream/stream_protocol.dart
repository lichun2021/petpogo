import 'dart:typed_data';

const devicePcmRate = 16000;
const devicePcmChunkBytes = 640;
const streamHeaderBytes = 9;

class StreamFrameInspection {
  final DeviceStreamFrame? frame;
  final String? rejection;
  final int? type, declaredBytes;
  final int availableBytes;
  const StreamFrameInspection(
      {this.frame,
      this.rejection,
      this.type,
      this.declaredBytes,
      required this.availableBytes});
}

class DeviceStreamFrame {
  final int type;
  final int timestamp;
  final Uint8List payload;
  const DeviceStreamFrame(this.type, this.timestamp, this.payload);

  static DeviceStreamFrame? parse(List<int> message) => inspect(message).frame;

  /// 返回明确拒绝原因，只包含头部数字，不把音视频数据带入诊断。
  static StreamFrameInspection inspect(List<int> message) {
    if (message.length < streamHeaderBytes) {
      return StreamFrameInspection(
          rejection: 'header_too_short', availableBytes: message.length);
    }
    final bytes = message is Uint8List ? message : Uint8List.fromList(message);
    final header = ByteData.sublistView(bytes);
    final length = header.getUint32(5, Endian.big);
    final type = bytes[0];
    final available = bytes.length - streamHeaderBytes;
    String? rejection;
    if (length == 0) {
      rejection = 'empty_payload';
    } else if (length > 4 * 1024 * 1024) {
      rejection = 'payload_too_large';
    } else if (length > available) {
      rejection = 'payload_truncated';
    } else if (type != 1 && type != 2) {
      rejection = 'unknown_frame_type';
    } else if (type == 2 && length.isOdd) {
      rejection = 'odd_pcm_bytes';
    }
    return StreamFrameInspection(
      rejection: rejection,
      type: type,
      declaredBytes: length,
      availableBytes: available,
      frame: rejection == null
          ? DeviceStreamFrame(
              type,
              header.getUint32(1, Endian.big),
              Uint8List.sublistView(
                  bytes, streamHeaderBytes, streamHeaderBytes + length))
          : null,
    );
  }
}

Uint8List buildTalkFrame(int timestamp, Uint8List pcm) {
  if (pcm.length != devicePcmChunkBytes) throw ArgumentError('对讲每帧必须为 640 字节');
  final bytes = Uint8List(streamHeaderBytes + pcm.length);
  final header = ByteData.sublistView(bytes);
  header.setUint8(0, 3);
  header.setUint32(1, timestamp & 0xffffffff, Endian.big);
  header.setUint32(5, pcm.length, Endian.big);
  bytes.setRange(streamHeaderBytes, bytes.length, pcm);
  return bytes;
}
