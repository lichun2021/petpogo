import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'stream_diagnostics.dart';

/// 顺序解码，忙时只保留最新帧；不把每帧 JPEG 加入全局 ImageCache。
class JpegStreamView extends StatefulWidget {
  final ValueNotifier<Uint8List?> frames;
  final StreamDiagnostics? diagnostics;
  final String view;
  const JpegStreamView(
      {super.key,
      required this.frames,
      this.diagnostics,
      this.view = 'inline'});
  @override
  State<JpegStreamView> createState() => _JpegStreamViewState();
}

class _JpegStreamViewState extends State<JpegStreamView> {
  ui.Image? _image;
  Uint8List? _pending;
  StreamVideoStamp? _displayedStamp, _scheduledPaint;
  bool _decoding = false;
  int _sourceGeneration = 0;
  @override
  void initState() {
    super.initState();
    widget.diagnostics?.log('view.attach', '视频视图', '视频视图已挂载，监听最新图片帧',
        fields: {'view': widget.view});
    widget.frames.addListener(_frame);
    _frame();
  }

  @override
  void didUpdateWidget(JpegStreamView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.frames != widget.frames) {
      _sourceGeneration++;
      oldWidget.frames.removeListener(_frame);
      widget.frames.addListener(_frame);
      _frame();
    }
  }

  void _frame() {
    if (_pending != null) widget.diagnostics?.decodeDropped++;
    _pending = widget.frames.value;
    if (!_decoding) _decode();
  }

  Future<void> _decode() async {
    if (_pending == null) return;
    _decoding = true;
    while (mounted && _pending != null) {
      final bytes = _pending!;
      _pending = null;
      final diagnostics = widget.diagnostics;
      final stamp = diagnostics?.stamp(bytes);
      final view = widget.view;
      final generation = _sourceGeneration;
      final watch = Stopwatch()..start();
      diagnostics?.decodeBegin(stamp, view, bytes.length);
      ui.Codec? codec;
      try {
        codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        if (!mounted || generation != _sourceGeneration) {
          frame.image.dispose();
          continue;
        }
        diagnostics?.decoded(stamp, view, frame.image.width, frame.image.height,
            watch.elapsedMilliseconds);
        final previous = _image;
        setState(() {
          _image = frame.image;
          _displayedStamp = stamp;
        });
        if (previous != null) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => previous.dispose());
        }
      } catch (error) {
        if (mounted) {
          diagnostics?.decodeFailed(
              stamp, view, error, watch.elapsedMilliseconds);
        }
      } finally {
        codec?.dispose();
      }
    }
    _decoding = false;
  }

  void _painted(Size size) {
    final stamp = _displayedStamp;
    final image = _image;
    if (stamp == null || image == null || identical(_scheduledPaint, stamp)) {
      return;
    }
    _scheduledPaint = stamp;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.diagnostics
            ?.painted(stamp, widget.view, size.width, size.height);
      }
    });
  }

  @override
  void dispose() {
    widget.diagnostics?.log('view.detach', '视频视图', '视频视图已卸载，停止绘制；不等于设备停止推流',
        fields: {'view': widget.view});
    widget.frames.removeListener(_frame);
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _PaintProbe(
      onPaint: _painted, child: RawImage(image: _image, fit: BoxFit.contain));
}

/// 只在 RenderObject 实际执行 paint 后上报，不把 setState 当作画面已显示。
class _PaintProbe extends SingleChildRenderObjectWidget {
  final void Function(Size) onPaint;
  const _PaintProbe({required this.onPaint, required super.child});
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _PaintProbeRender(onPaint);
  @override
  void updateRenderObject(
      BuildContext context, covariant _PaintProbeRender renderObject) {
    renderObject.onPaint = onPaint;
  }
}

class _PaintProbeRender extends RenderProxyBox {
  void Function(Size) onPaint;
  _PaintProbeRender(this.onPaint);
  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    if (!size.isEmpty) onPaint(size);
  }
}
