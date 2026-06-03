import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/enum/V2TimAdvancedMsgListener.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/pet_avatar.dart';
import '../../shared/widgets/pet_toast.dart';
import 'controller/im_controller.dart';
import 'data/repository/im_repository.dart';
import 'package:petpogo_app/shared/theme/app_fonts.dart';


// ─────────────────────────────────────────────────────────────────────────────
//  ChatPage
// ─────────────────────────────────────────────────────────────────────────────
class ChatPage extends ConsumerStatefulWidget {
  final String userId;
  const ChatPage({super.key, required this.userId});
  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _textCtrl   = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _picker     = ImagePicker();
  List<V2TimMessage> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  String _peerName = '';
  String? _myAvatarUrl;
  V2TimAdvancedMsgListener? _msgListener;

  // 好友状态
  bool _isFriend       = false;
  bool _checkingFriend = true;
  bool _addingFriend   = false;
  bool _requestSent    = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _registerListener();
    _fetchPeerName();
    _fetchSelfAvatar();
    _checkFriendship();
    ref.read(imControllerProvider.notifier).markRead(widget.userId);
  }

  Future<void> _checkFriendship() async {
    final ok = await ref
        .read(imControllerProvider.notifier)
        .checkIsFriend(widget.userId);
    if (!mounted) return;
    setState(() {
      _isFriend       = ok;
      _checkingFriend = false;
    });
  }

  Future<void> _sendFriendRequest() async {
    if (_addingFriend || _requestSent) return;
    setState(() => _addingFriend = true);
    final ok = await ref.read(imControllerProvider.notifier).addFriend(
      toUserId: widget.userId,
      wording: '我在 PetPogo 遇见了你，想加个好友～',
    );
    if (!mounted) return;
    setState(() { _addingFriend = false; _requestSent = ok; });
    if (ok) {
      PetToast.success(context, '好友申请已发送，等对方同意后可私信 🐾');
    } else {
      PetToast.error(context, '发送失败，请稍后重试');
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    if (_msgListener != null) {
      ref.read(imRepositoryProvider).removeMessageListener(_msgListener!);
    }
    super.dispose();
  }

  Future<void> _fetchSelfAvatar() async {
    try {
      final r = await TencentImSDKPlugin.v2TIMManager.getLoginUser();
      if ((r.data ?? '').isEmpty) return;
      final info = await TencentImSDKPlugin.v2TIMManager
          .getUsersInfo(userIDList: [r.data!]);
      final url = info.data?.firstOrNull?.faceUrl ?? '';
      if (mounted && url.isNotEmpty) setState(() => _myAvatarUrl = url);
    } catch (_) {}
  }

  Future<void> _fetchPeerName() async {
    try {
      final r = await TencentImSDKPlugin.v2TIMManager
          .getUsersInfo(userIDList: [widget.userId]);
      final nick = r.data?.firstOrNull?.nickName ??
          r.data?.firstOrNull?.userID ?? widget.userId;
      if (mounted && nick.isNotEmpty) setState(() => _peerName = nick);
    } catch (_) {}
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    final res = await ref
        .read(imRepositoryProvider)
        .fetchMessages(userId: widget.userId);
    res.when(
      success: (msgs) {
        setState(() { _messages = msgs; _isLoading = false; });
        _scrollToBottom();
      },
      failure: (_) => setState(() => _isLoading = false),
    );
  }

  void _registerListener() {
    _msgListener = V2TimAdvancedMsgListener(onRecvNewMessage: (msg) {
      if (!mounted) return;
      if (msg.userID == widget.userId || msg.isSelf == true) {
        setState(() => _messages.add(msg));
        _scrollToBottom();
      }
    });
    ref.read(imRepositoryProvider).addMessageListener(_msgListener!);
  }

  Future<void> _sendText() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || !ref.read(imControllerProvider).isLoggedIn) return;
    HapticFeedback.lightImpact();
    _textCtrl.clear();
    setState(() => _isSending = true);
    final res = await ref.read(imRepositoryProvider)
        .sendText(toUserId: widget.userId, text: text);
    setState(() => _isSending = false);
    res.when(success: (_) => _loadMessages(), failure: (e) => _showErr(e.userMessage));
  }

  Future<void> _sendImage() async {
    final f = await _picker.pickImage(source: ImageSource.gallery);
    if (f == null) return;
    setState(() => _isSending = true);
    final res = await ref.read(imRepositoryProvider)
        .sendImage(toUserId: widget.userId, imagePath: f.path);
    setState(() => _isSending = false);
    res.when(success: (_) => _loadMessages(), failure: (e) => _showErr(e.userMessage));
  }

  Future<void> _sendVoice(String path, int duration) async {
    if (!ref.read(imControllerProvider).isLoggedIn) {
      _showErr('IM 连接中，请稍候');
      return;
    }
    setState(() => _isSending = true);
    final res = await ref.read(imRepositoryProvider).sendSound(
      toUserId: widget.userId, soundPath: path, duration: duration,
    );
    setState(() => _isSending = false);
    res.when(success: (_) => _loadMessages(), failure: (e) => _showErr(e.userMessage));
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showErr(String msg) {
    if (!mounted) return;
    PetToast.error(context, msg);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: AppColors.surface.withOpacity(0.95),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          color: AppColors.onSurface,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(children: [
          PetAvatar(imageUrl: null, size: 36, fallbackEmoji: '🐾'),
          const SizedBox(width: 10),
          Expanded(child: Text(
            _peerName.isNotEmpty ? _peerName : widget.userId,
            style: const TextStyle(fontFamily: AppFonts.primary, fontSize: 16,
                fontWeight: FontWeight.w700, color: AppColors.onSurface),
            overflow: TextOverflow.ellipsis,
          )),
        ]),
        actions: [
          IconButton(
            icon: Icon(Icons.more_horiz_rounded, color: AppColors.onSurfaceVariant),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(
                  color: AppColors.primary, strokeWidth: 2.5))
              : _messages.isEmpty
                  ? _buildEmpty()
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      // 非好友且有历史消息时，顶部额外插入一条提示
                      itemCount: _messages.length + (!_isFriend && !_checkingFriend && _messages.isNotEmpty ? 1 : 0),
                      itemBuilder: (_, i) {
                        // 第 0 项 = 提示条（非好友时）
                        if (!_isFriend && !_checkingFriend && _messages.isNotEmpty && i == 0) {
                          return _buildRemovedTip();
                        }
                        final msgIdx = (!_isFriend && !_checkingFriend && _messages.isNotEmpty) ? i - 1 : i;
                        return _MessageBubble(
                          message: _messages[msgIdx],
                           myAvatarUrl: _myAvatarUrl,
                        );
                      },
                    ),
        ),
        // 好友才能发送消息
        if (_checkingFriend || _isFriend)
          _ChatInputSection(
            controller: _textCtrl,
            isSending: _isSending || _checkingFriend,
            onSend: _isFriend ? _sendText : () {},
            onPickImage: _isFriend ? _sendImage : () {},
            onSendVoice: _isFriend ? _sendVoice : (_, __) async {},
          )
        else
          _buildNotFriendBanner(),
      ]),
    );
  }

  Widget _buildEmpty() => const Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text('🐾', style: TextStyle(fontSize: 48)),
      SizedBox(height: 12),
      Text('发送第一条消息，开始聊天吧！',
        style: TextStyle(fontFamily: AppFonts.primary, fontSize: 14,
            color: AppColors.onSurfaceVariant)),
    ]),
  );

  // 有历史消息但非好友时顶部提示
  Widget _buildRemovedTip() => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.errorContainer.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          '⚠️ 对方已将你移除或拉黑，消息将无法送达',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: AppFonts.primary, fontSize: 12,
              color: AppColors.onSurfaceVariant),
        ),
      ),
    ),
  );

  // ── 非好友拦截横幅 ───────────────────────────────────
  Widget _buildNotFriendBanner() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        border: Border(
            top: BorderSide(color: AppColors.outlineVariant, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Row(children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('还不是好友',
                  style: TextStyle(fontFamily: AppFonts.primary,
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: AppColors.onSurfaceVariant)),
              Text('成为好友后才能发送私信',
                  style: TextStyle(fontFamily: AppFonts.primary,
                      fontSize: 11, color: AppColors.onSurfaceVariant)),
            ],
          )),
          const SizedBox(width: 12),
          _checkingFriend
              ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primary))
              : _requestSent
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('申请已发送',
                          style: TextStyle(fontFamily: AppFonts.primary,
                              fontSize: 13, fontWeight: FontWeight.w700,
                              color: AppColors.primary)),
                    )
                  : GestureDetector(
                      onTap: _addingFriend ? null : _sendFriendRequest,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: _addingFriend
                              ? AppColors.surfaceContainerHigh
                              : AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: _addingFriend ? null : [
                            BoxShadow(color: AppColors.primaryGlow,
                                blurRadius: 8, offset: const Offset(0, 3)),
                          ],
                        ),
                        child: _addingFriend
                            ? const SizedBox(width: 14, height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: AppColors.primary))
                            : const Text('加好友',
                                style: TextStyle(fontFamily: AppFonts.primary,
                                    fontSize: 13, fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                      ),
                    ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  消息气泡
// ─────────────────────────────────────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final V2TimMessage message;
  final String? myAvatarUrl;
  const _MessageBubble({required this.message, this.myAvatarUrl});

  @override
  Widget build(BuildContext context) {
    final isSelf = message.isSelf ?? false;
    final imgUrl  = message.imageElem?.imageList?.firstOrNull?.url;
    final sound   = message.soundElem;
    final text    = message.textElem?.text;
    final custom  = message.customElem?.data;

    // ── 自定义系统通知（居中展示，无气泡）──────────────────────
    if (custom != null && custom.isNotEmpty) {
      try {
        final json = jsonDecode(custom) as Map<String, dynamic>;
        final type = json['type'] as String? ?? '';
        final content = json['content'] as String? ?? '';
        final fromName = json['fromName'] as String? ?? '';
        if (type == 'friend_accepted') {
          final label = '$fromName $content';
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontFamily: AppFonts.primary, fontSize: 12,
                        color: AppColors.primary, fontWeight: FontWeight.w600)),
              ),
            ),
          );
        }
        if (type == 'friend_rejected') {
          final label = '$fromName $content';
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.errorContainer.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontFamily: AppFonts.primary, fontSize: 12,
                        color: AppColors.onSurfaceVariant,
                        fontWeight: FontWeight.w500)),
              ),
            ),
          );
        }
      } catch (_) {}
    }

    Widget content;
    if (sound != null) {
      content = _VoiceBubble(
        url: sound.url ?? '', duration: sound.duration ?? 0, isSelf: isSelf);
    } else if (imgUrl != null) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: imgUrl,
          width: 180, fit: BoxFit.cover,
          placeholder: (_, __) => Container(
            width: 180, height: 120,
            color: Colors.grey.withOpacity(0.15),
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          errorWidget: (_, __, ___) => Container(
            width: 120, height: 80,
            color: Colors.grey.withOpacity(0.1),
            child: const Icon(Icons.broken_image_rounded, color: Colors.grey),
          ),
        ),
      );
    } else {
      content = Text(text ?? '[消息]',
        style: TextStyle(fontFamily: AppFonts.primary, fontSize: 14,
            color: isSelf ? Colors.white : AppColors.onSurface));
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isSelf ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isSelf) ...[
            PetAvatar(imageUrl: null, size: 32, fallbackEmoji: '🐾'),
            const SizedBox(width: 8),
          ],
          Flexible(child: Column(
            crossAxisAlignment:
                isSelf ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (sound == null)
                Container(
                  padding: imgUrl != null
                      ? EdgeInsets.zero
                      : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.65),
                  decoration: imgUrl == null ? BoxDecoration(
                    color: isSelf
                        ? AppColors.primary
                        : AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isSelf ? 18 : 4),
                      bottomRight: Radius.circular(isSelf ? 4 : 18),
                    ),
                  ) : null,
                  child: content,
                )
              else
                content,
              const SizedBox(height: 4),
              Text(_fmt(message.timestamp),
                style: const TextStyle(fontFamily: AppFonts.primary,
                    fontSize: 10, color: AppColors.onSurfaceVariant)),
            ],
          )),
          if (isSelf) ...[
            const SizedBox(width: 8),
            PetAvatar(imageUrl: myAvatarUrl, size: 32, fallbackEmoji: '😊'),
          ],
        ],
      ),
    );
  }

  String _fmt(int? ts) {
    if (ts == null) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  语音气泡（可播放）
// ─────────────────────────────────────────────────────────────────────────────
class _VoiceBubble extends StatefulWidget {
  final String url;
  final int duration;
  final bool isSelf;
  const _VoiceBubble(
      {required this.url, required this.duration, required this.isSelf});
  @override
  State<_VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends State<_VoiceBubble> {
  final _player = AudioPlayer();
  bool _playing = false;

  @override
  void dispose() { _player.dispose(); super.dispose(); }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.stop();
      if (mounted) setState(() => _playing = false);
      return;
    }
    setState(() => _playing = true);
    try {
      await _player.setUrl(widget.url);
      await _player.play();
      await _player.processingStateStream
          .firstWhere((s) => s == ProcessingState.completed)
          .timeout(const Duration(seconds: 120),
              onTimeout: () => ProcessingState.idle);
    } catch (_) {}
    if (mounted) setState(() => _playing = false);
  }

  @override
  Widget build(BuildContext context) {
    final w = (80.0 + widget.duration * 6).clamp(80.0, 180.0);
    return GestureDetector(
      onTap: _toggle,
      child: Container(
        width: w,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: widget.isSelf ? AppColors.primary : AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(widget.isSelf ? 18 : 4),
            bottomRight: Radius.circular(widget.isSelf ? 4 : 18),
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(
            _playing ? Icons.pause_rounded : Icons.graphic_eq_rounded,
            color: widget.isSelf ? Colors.white : AppColors.primary,
            size: 20,
          ),
          const SizedBox(width: 6),
          Text('${widget.duration}"',
            style: TextStyle(fontFamily: AppFonts.primary, fontSize: 13,
                color: widget.isSelf ? Colors.white : AppColors.onSurface)),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  输入区（语音 + EmojiPicker + 文字）
// ─────────────────────────────────────────────────────────────────────────────
class _ChatInputSection extends StatefulWidget {
  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;
  final VoidCallback onPickImage;
  final Future<void> Function(String path, int seconds) onSendVoice;
  const _ChatInputSection({
    required this.controller,
    required this.isSending,
    required this.onSend,
    required this.onPickImage,
    required this.onSendVoice,
  });
  @override
  State<_ChatInputSection> createState() => _ChatInputSectionState();
}

class _ChatInputSectionState extends State<_ChatInputSection> {
  bool _showEmoji   = false;
  bool _isVoiceMode = false;
  bool _isRecording = false;
  bool _cancelZone  = false;
  int  _recSecs     = 0;
  Timer? _recTimer;
  OverlayEntry? _overlayEntry;
  final _cancelNotifier    = ValueNotifier<bool>(false);
  // 实时音量单值（VU 计量仪：0.0 无声 → 1.0 最大）
  final _ampNotifier       = ValueNotifier<double>(0.0);
  StreamSubscription<Amplitude>? _ampSub;
  final _recorder          = AudioRecorder();
  final _focus             = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (_focus.hasFocus && _showEmoji) setState(() => _showEmoji = false);
    });
    widget.controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    _recTimer?.cancel();
    _ampSub?.cancel();
    _recorder.dispose();
    _overlayEntry?.remove();
    _cancelNotifier.dispose();
    _ampNotifier.dispose();
    super.dispose();
  }

  bool get _hasText => widget.controller.text.trim().isNotEmpty;

  // ── 通用权限工具 ────────────────────────────────────────────────────────────
  /// 请求 [perm] 权限，若拒绝则显示引导对话框。
  /// 返回 true 表示已授权，false 表示拒绝。
  Future<bool> _requestPermission(
    Permission perm, {
    required String title,
    required String reason,
    required IconData icon,
  }) async {
    // undetermined → 直接弹系统授权框
    // denied / permanentlyDenied → request() 在 iOS 上不再弹框，直接引导设置
    var status = await perm.status;
    if (status.isGranted) return true;

    if (status.isDenied || status.isRestricted) {
      // 还可以弹系统授权框
      status = await perm.request();
      if (status.isGranted) return true;
    }

    // 永久拒绝 or 请求失败 → 引导打开设置
    if (!mounted) return false;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(icon, color: const Color(0xFFFF6B6B)),
          const SizedBox(width: 8),
          Flexible(child: Text(title,
            style: const TextStyle(fontFamily: AppFonts.primary,
                fontSize: 17, fontWeight: FontWeight.w700))),
        ]),
        content: Text(reason,
          style: const TextStyle(fontFamily: AppFonts.primary,
              fontSize: 14, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消',
              style: TextStyle(color: AppColors.onSurfaceVariant)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('去设置',
              style: TextStyle(color: Colors.white,
                  fontFamily: AppFonts.primary,
                  fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    return false;
  }

  // ── 录音 ──────────────────────────────────────────────────────────────────
  Future<void> _startRecord() async {
    // 权限已在切换到语音模式时提前申请完毕，这里直接开始录音
    final dir  = await getTemporaryDirectory();
    final path =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.aac';
    await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, numChannels: 1),
        path: path);
    _recSecs  = 0;
    _cancelZone = false;
    _cancelNotifier.value = false;
    _recTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {
        _recSecs++;
        if (_recSecs >= 30) {
          // 30 秒自动发送
          _stopRecord(cancel: false, autoSend: true);
        }
      });
    });
    HapticFeedback.mediumImpact();
    setState(() { _isRecording = true; _cancelZone = false; });

    // 订阅实时音量，80ms 更新一次声波条
    _ampSub = _recorder.onAmplitudeChanged(
      const Duration(milliseconds: 80),
    ).listen((amp) {
      // 用 -40dBFS 作为基准（比 -60 更灵敏，正常说话可到 50%+ 量程）
      final v = ((amp.current + 40) / 40).clamp(0.0, 1.0);
      _ampNotifier.value = v;
    });

    _showRecordingOverlay();
  }

  Future<void> _stopRecord({required bool cancel, bool autoSend = false}) async {
    _recTimer?.cancel();
    _ampSub?.cancel();
    _ampSub = null;
    _ampNotifier.value = 0.0; // 重置计量仪
    _removeRecordingOverlay();
    final path = await _recorder.stop();
    setState(() { _isRecording = false; _cancelZone = false; });

    if (cancel) {
      if (path != null) try { File(path).deleteSync(); } catch (_) {}
      return;
    }
    if (path == null) return;
    if (_recSecs < 2) {
      // 时间太短
      try { File(path).deleteSync(); } catch (_) {}
      if (mounted) PetToast.warning(context, '时间太短，请至少录制 2 秒');
      return;
    }
    HapticFeedback.lightImpact();
    if (autoSend && mounted) PetToast.success(context, '已自动发送（最长 30 秒）');
    widget.onSendVoice(path, _recSecs);
  }

  void _onRecordDrag(Offset local) {
    // 向左滑动超过 70px 进入取消区（微信风格：左侧取消按钮）
    final cancel = local.dx < -70;
    _cancelNotifier.value = cancel;
    if (cancel != _cancelZone) {
      if (cancel) HapticFeedback.lightImpact();
      setState(() => _cancelZone = cancel);
    }
  }

  void _toggleVoiceMode() async {
    if (!_isVoiceMode) {
      // 切换到语音模式时提前申请权限，避免按住说话时卡顿等待权限弹框
      final ok = await _requestPermission(
        Permission.microphone,
        title: '需要麦克风权限',
        reason: '发送语音消息需要使用麦克风。\n请在「设置 → PetPogo」中开启麦克风权限。',
        icon: Icons.mic_off_rounded,
      );
      if (!ok) return; // 权限被拒，不切换到语音模式
    }
    setState(() {
      _isVoiceMode = !_isVoiceMode;
      _showEmoji = false;
    });
    if (_isVoiceMode) _focus.unfocus();
    else Future.delayed(const Duration(milliseconds: 100), () => _focus.requestFocus());
  }

  void _showRecordingOverlay() {
    _overlayEntry = OverlayEntry(
      builder: (_) => _RecordingOverlay(
        cancelNotifier:    _cancelNotifier,
        amplitudeNotifier: _ampNotifier,
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeRecordingOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  // ── 表情面板 ──────────────────────────────────────────────────────────────
  void _toggleEmoji() {
    if (!_showEmoji) {
      _focus.unfocus();
      setState(() => _showEmoji = true);
    } else {
      setState(() => _showEmoji = false);
      _focus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).viewInsets.bottom > 0
        ? MediaQuery.of(context).viewInsets.bottom
        : MediaQuery.of(context).padding.bottom;

    return Column(mainAxisSize: MainAxisSize.min, children: [
      const Divider(height: 1, thickness: 0.5, color: Color(0x10000000)),

      // ── 输入栏（微信风格）──────────────────────────────────────────────
      Container(
        color: AppColors.surface,
        padding: EdgeInsets.fromLTRB(10, 8, 10, safeBottom + 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          // ── 左：语音 ⇄ 键盘 切换 ──
          GestureDetector(
            onTap: _toggleVoiceMode,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                key: ValueKey(_isVoiceMode),
                _isVoiceMode ? Icons.keyboard_rounded : Icons.mic_none_rounded,
                size: 24,
                color: AppColors.onSurfaceVariant.withOpacity(0.7),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // ── 中：文字输入框 或「按住 说话」按钮 ──
          Expanded(
            child: _isVoiceMode
              ? GestureDetector(
                  onLongPressStart:      (_) => _startRecord(),
                  onLongPressEnd:        (_) => _stopRecord(cancel: _cancelZone),
                  onLongPressMoveUpdate: (d) => _onRecordDrag(d.localOffsetFromOrigin),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: 40,
                    decoration: BoxDecoration(
                      color: _isRecording
                          ? AppColors.primary.withOpacity(0.12)
                          : AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _isRecording
                            ? AppColors.primary.withOpacity(0.4)
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _isRecording ? '正在录音…' : '按住 说话',
                      style: TextStyle(
                        fontFamily: AppFonts.primary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _isRecording
                            ? AppColors.primary
                            : AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              : Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focus,
                    minLines: 1, maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => widget.onSend(),
                    style: const TextStyle(fontFamily: AppFonts.primary,
                        fontSize: 15, color: AppColors.onSurface),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 10, vertical: 9),
                      hintText: '发条消息…',
                      hintStyle: TextStyle(
                        fontFamily: AppFonts.primary,
                        fontSize: 15,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
          ),
          const SizedBox(width: 8),

          // ── 右：图片 + 表情（或发送按钮）──
          if (_hasText && !_isVoiceMode)
            GestureDetector(
              onTap: widget.isSending ? null : widget.onSend,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 36, height: 36,
                decoration: BoxDecoration(
                  gradient: widget.isSending ? null : AppColors.primaryGradient,
                  color: widget.isSending ? AppColors.surfaceContainerLow : null,
                  shape: BoxShape.circle,
                ),
                child: widget.isSending
                    ? Center(child: SizedBox(width: 15, height: 15,
                        child: CircularProgressIndicator(strokeWidth: 2,
                            color: AppColors.primary.withOpacity(0.5))))
                    : const Icon(Icons.arrow_upward_rounded,
                        color: Colors.white, size: 17),
              ),
            )
          else ...[ 
            IconButton(
              onPressed: widget.isSending ? null : widget.onPickImage,
              icon: Icon(Icons.image_outlined, size: 22,
                  color: AppColors.onSurfaceVariant.withOpacity(0.5)),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 2),
            IconButton(
              onPressed: _toggleEmoji,
              icon: Icon(
                _showEmoji ? Icons.keyboard_rounded : Icons.emoji_emotions_outlined,
                size: 22,
                color: _showEmoji
                    ? AppColors.primary
                    : AppColors.onSurfaceVariant.withOpacity(0.6)),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ]),
      ),



      // ── EmojiPicker 面板（Offstage 避免反复创建）──────────────────────
      Offstage(
        offstage: !_showEmoji,
        child: SizedBox(
          height: 300,
          child: EmojiPicker(
            textEditingController: widget.controller,
            onEmojiSelected: (_, __) {},
            config: Config(
              height: 300,
              emojiViewConfig: EmojiViewConfig(
                columns: 8,
                emojiSizeMax: 28,
                backgroundColor: AppColors.surface,
              ),
              categoryViewConfig: CategoryViewConfig(
                initCategory: Category.SMILEYS,
                backgroundColor: AppColors.surface,
                iconColorSelected: AppColors.primary,
                indicatorColor: AppColors.primary,
                iconColor: AppColors.onSurfaceVariant,
              ),
              bottomActionBarConfig: const BottomActionBarConfig(
                backgroundColor: Colors.transparent,
                buttonColor: Colors.transparent,
                buttonIconColor: Colors.transparent,
                enabled: false,
              ),
              searchViewConfig: SearchViewConfig(
                backgroundColor: AppColors.surface,
                buttonIconColor: AppColors.primary,
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 全屏录音遮罩（通过 OverlayEntry 插入，覆盖整个屏幕）
// ValueNotifier<bool> cancelNotifier: true = 进入取消区
// ══════════════════════════════════════════════════════════════════════════════
class _RecordingOverlay extends StatefulWidget {
  final ValueNotifier<bool>   cancelNotifier;
  final ValueNotifier<double> amplitudeNotifier;  // 单值 VU 计量仪
  const _RecordingOverlay({
    required this.cancelNotifier,
    required this.amplitudeNotifier,
  });
  @override
  State<_RecordingOverlay> createState() => _RecordingOverlayState();
}

class _RecordingOverlayState extends State<_RecordingOverlay> {
  @override
  void initState() {
    super.initState();
    widget.cancelNotifier.addListener(_rebuild);
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    widget.cancelNotifier.removeListener(_rebuild);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCancel = widget.cancelNotifier.value;
    final mq       = MediaQuery.of(context);
    final safeBot  = mq.padding.bottom;

    return Material(
      type: MaterialType.transparency,
      child: Stack(children: [

        // ① 半透明背景（不完全遮住，聊天内容隐约可见）
        Positioned.fill(
          child: Container(color: Colors.black.withOpacity(0.42)),
        ),

        // ② 中心声波气泡（品牌主色圆角矩形 + 尾巴）
        Align(
          alignment: const Alignment(0, -0.15), // 略偏上，让底部面板不遮挡
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // 气泡主体
            Container(
              width: 220, height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.4),
                    blurRadius: 24, offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              // 真实振幅声波（ValueListenableBuilder 驱动）
              child: ValueListenableBuilder<double>(
                valueListenable: widget.amplitudeNotifier,
                builder: (_, amp, __) => _WaveformMeter(amplitude: amp),
              ),
            ),
            // 小三角尾巴
            CustomPaint(
              size: const Size(20, 11),
              painter: _BubbleTailPainter(color: AppColors.primary),
            ),
          ]),
        ),

        // ③ 取消按钮 —— 浮在两弧上方（不在弧形区域内）
        Positioned(
          bottom: 130 + safeBot + 12, // 弧形面板顶部 + 12px 间距
          left: -12,                  // 向屏幕外延伸，左边直边不可见
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 130, height: 56,
            decoration: BoxDecoration(
              color: isCancel
                  ? AppColors.error.withOpacity(0.20)
                  : AppColors.surfaceContainerLow,
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(28), // 只有右侧是圆角
              ),
              border: isCancel
                  ? Border.all(color: AppColors.error.withOpacity(0.6), width: 1.5)
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Center(
                child: Text('取消',
                  style: TextStyle(
                    fontFamily: AppFonts.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isCancel ? AppColors.error : AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ),

        // ④ 双层弧形底部面板（两弧相同弧度 arcH=50，相距 3px）
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: SizedBox(
            height: 130 + safeBot,
            child: Stack(
              children: [

                // 外层弧（深色 surfaceContainerHigh，arcH=50，完整高度）
                Positioned.fill(
                  child: ClipPath(
                    clipper: _ArcTopClipper(arcH: 50),
                    child: Container(
                      color: isCancel
                          ? AppColors.error.withOpacity(0.10)
                          : AppColors.surfaceContainerHigh,
                    ),
                  ),
                ),

                // 内层弧（浅色 surface，相同 arcH=50，top:3 → 两弧间距 3px）
                Positioned(
                  top: 3, left: 0, right: 0, bottom: 0,
                  child: ClipPath(
                    clipper: _ArcTopClipper(arcH: 50),
                    child: Container(
                      color: AppColors.surface,
                      alignment: Alignment.center,
                      padding: EdgeInsets.only(bottom: safeBot),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.expand_less_rounded,
                          size: 18,
                          color: AppColors.onSurfaceVariant.withOpacity(0.4)),
                        const SizedBox(height: 2),
                        Text(
                          isCancel ? '< 滑回来发送' : '松开  发送',
                          style: TextStyle(
                            fontFamily: AppFonts.primary,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: isCancel
                                ? AppColors.onSurfaceVariant
                                : AppColors.onSurface,
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),

              ],
            ),
          ),
        ),
      ]),
    );
  }
}


// ── VU 计量仪声波（不规则分布 + 轻微抖动，更自然）────────────────────────────
class _WaveformMeter extends StatefulWidget {
  final double amplitude;
  const _WaveformMeter({required this.amplitude});
  @override
  State<_WaveformMeter> createState() => _WaveformMeterState();
}

class _WaveformMeterState extends State<_WaveformMeter>
    with SingleTickerProviderStateMixin {
  late AnimationController _jitter;

  // 不规则分布（非对称拱形），每根柱有自己的响应倍率
  static const _mult = [
    0.30, 0.68, 0.45, 0.88, 0.58, 0.82, 0.50, 0.95, 0.73, 0.90,
    0.85, 0.67, 0.92, 0.55, 0.78, 0.42, 0.72, 0.60, 0.38, 0.65,
  ];

  @override
  void initState() {
    super.initState();
    _jitter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _jitter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _jitter,
      builder: (_, __) {
        const maxH = 50.0;
        const minH =  3.0;
        final amp = widget.amplitude;

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(_mult.length, (i) {
            // 奇偶柱抖动方向相反，形成更有机的波动感
            final phase = i.isEven ? _jitter.value : (1 - _jitter.value);
            // 有声时加 ±8% 抖动，无声时几乎不动
            final jitter = phase * 0.08 * amp;
            final level  = (amp * _mult[i] + jitter).clamp(0.0, 1.0);
            final h      = minH + (maxH - minH) * level;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 80),
              width: 4,
              height: h,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity((0.45 + 0.55 * level).clamp(0.0, 1.0)),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}


// ── 气泡小三角尾巴 ───────────────────────────────────────────────────────────
class _BubbleTailPainter extends CustomPainter {
  final Color color;
  const _BubbleTailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(size.width / 2 - 8, 0)
        ..lineTo(size.width / 2,     size.height)
        ..lineTo(size.width / 2 + 8, 0)
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_BubbleTailPainter o) => o.color != color;
}

// ── 底部面板顶部单一凸弧裁剪器 ─────────────────────────────────────────────
class _ArcTopClipper extends CustomClipper<Path> {
  final double arcH; // 弧的起始高度（两端距顶）
  const _ArcTopClipper({this.arcH = 40});

  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, arcH);
    path.quadraticBezierTo(
      size.width / 2, -arcH * 0.35, // 中央向上拱起
      size.width, arcH,
    );
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_ArcTopClipper old) => old.arcH != arcH;
}
