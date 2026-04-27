import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/enum/V2TimAdvancedMsgListener.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/pet_avatar.dart';
import 'controller/im_controller.dart';
import 'data/repository/im_repository.dart';

/// 单聊页面
///
/// 路由参数：userId（对方的 IM userID = merchantId 字符串）
class ChatPage extends ConsumerStatefulWidget {
  final String userId; // 对方 IM userID

  const ChatPage({super.key, required this.userId});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollCtrl   = ScrollController();
  final ImagePicker _picker            = ImagePicker();

  List<V2TimMessage> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;

  /// 实时消息监听器（进入页面注册，离开时注销）
  V2TimAdvancedMsgListener? _msgListener;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _registerMessageListener();
    // 标记会话已读
    ref.read(imControllerProvider.notifier).markRead(widget.userId);
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    // 离开时注销监听器
    if (_msgListener != null) {
      ref.read(imRepositoryProvider).removeMessageListener(_msgListener!);
    }
    super.dispose();
  }

  // ── 拉取历史消息 ─────────────────────────────────────────
  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    final result = await ref.read(imRepositoryProvider).fetchMessages(
      userId: widget.userId,
    );
    result.when(
      success: (msgs) {
        setState(() {
          _messages = msgs;
          _isLoading = false;
        });
        _scrollToBottom();
      },
      failure: (err) => setState(() => _isLoading = false),
    );
  }

  // ── 注册实时消息监听 ─────────────────────────────────────
  void _registerMessageListener() {
    _msgListener = V2TimAdvancedMsgListener(
      onRecvNewMessage: (msg) {
        if (!mounted) return;
        // 只显示本对话的消息
        if (msg.userID == widget.userId || msg.isSelf == true) {
          setState(() => _messages.add(msg));
          _scrollToBottom();
        }
      },
    );
    ref.read(imRepositoryProvider).addMessageListener(_msgListener!);
  }

  // ── 发送文本 ─────────────────────────────────────────────
  Future<void> _sendText() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;

    HapticFeedback.lightImpact();
    _textCtrl.clear();
    setState(() => _isSending = true);

    final result = await ref.read(imRepositoryProvider).sendText(
      toUserId: widget.userId,
      text: text,
    );

    setState(() => _isSending = false);
    result.when(
      success: (_) => _loadMessages(), // 重新拉取以显示自己发的消息
      failure: (err) => _showError(err.userMessage),
    );
  }

  // ── 发送图片 ─────────────────────────────────────────────
  Future<void> _sendImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() => _isSending = true);
    final result = await ref.read(imRepositoryProvider).sendImage(
      toUserId: widget.userId,
      imagePath: picked.path,
    );
    setState(() => _isSending = false);
    result.when(
      success: (_) => _loadMessages(),
      failure: (err) => _showError(err.userMessage),
    );
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

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface.withOpacity(0.95),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          color: AppColors.onSurface,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            PetAvatar(imageUrl: null, size: 36, fallbackEmoji: '🐾'),
            const SizedBox(width: 10),
            Text(
              widget.userId,
              style: const TextStyle(
                fontFamily: 'Plus Jakarta Sans', fontSize: 16,
                fontWeight: FontWeight.w700, color: AppColors.onSurface,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.more_horiz_rounded, color: AppColors.onSurfaceVariant),
            onPressed: () {/* TODO: 聊天设置（拉黑/举报/查看资料） */},
          ),
        ],
      ),

      body: Column(
        children: [
          // 消息列表
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5))
                : _messages.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) => _MessageBubble(message: _messages[i]),
                      ),
          ),

          // 底部输入栏
          _InputBar(
            controller: _textCtrl,
            isSending: _isSending,
            onSend: _sendText,
            onPickImage: _sendImage,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('🐾', style: TextStyle(fontSize: 48)),
        SizedBox(height: 12),
        Text('还没有消息', style: TextStyle(
          fontFamily: 'Plus Jakarta Sans', fontSize: 16,
          fontWeight: FontWeight.w700, color: AppColors.onSurfaceVariant,
        )),
        SizedBox(height: 4),
        Text('发送第一条消息，开始聊天吧！', style: TextStyle(
          fontFamily: 'Plus Jakarta Sans', fontSize: 12,
          color: AppColors.onSurfaceVariant,
        )),
      ]),
    );
  }
}

// ── 消息气泡 ──────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final V2TimMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isSelf = message.isSelf ?? false;
    final text   = message.textElem?.text;
    final imgUrl = message.imageElem?.imageList?.firstOrNull?.url;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isSelf ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isSelf) ...[
            PetAvatar(imageUrl: null, size: 32, fallbackEmoji: '🐾'),
            const SizedBox(width: 8),
          ],

          Flexible(
            child: Column(
              crossAxisAlignment: isSelf ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: imgUrl != null
                      ? EdgeInsets.zero
                      : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.65,
                  ),
                  decoration: BoxDecoration(
                    color: isSelf
                        ? AppColors.primary
                        : AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.only(
                      topLeft:     const Radius.circular(18),
                      topRight:    const Radius.circular(18),
                      bottomLeft:  Radius.circular(isSelf ? 18 : 4),
                      bottomRight: Radius.circular(isSelf ? 4 : 18),
                    ),
                  ),
                  child: imgUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(imgUrl, width: 180, fit: BoxFit.cover),
                        )
                      : Text(
                          text ?? '[消息]',
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans', fontSize: 14,
                            color: isSelf ? Colors.white : AppColors.onSurface,
                          ),
                        ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTime(message.timestamp),
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans', fontSize: 10,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          if (isSelf) ...[
            const SizedBox(width: 8),
            // 自己头像（用本地存储的 userInfo 里的信息）
            PetAvatar(imageUrl: null, size: 32, fallbackEmoji: '😊'),
          ],
        ],
      ),
    );
  }

  String _formatTime(int? ts) {
    if (ts == null) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ── 输入栏（重设计：更简洁）────────────────────────────────
class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;
  final VoidCallback onPickImage;

  const _InputBar({
    required this.controller,
    required this.isSending,
    required this.onSend,
    required this.onPickImage,
  });

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).viewInsets.bottom > 0
        ? MediaQuery.of(context).viewInsets.bottom
        : MediaQuery.of(context).padding.bottom;

    return Container(
      color: AppColors.surface,
      padding: EdgeInsets.fromLTRB(8, 8, 12, safeBottom + 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 图片按钮
          IconButton(
            onPressed: isSending ? null : onPickImage,
            icon: Icon(
              Icons.image_outlined,
              size: 22,
              color: isSending
                  ? AppColors.onSurfaceVariant.withOpacity(0.25)
                  : AppColors.onSurfaceVariant.withOpacity(0.5),
            ),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),

          // 输入框（矩形小圆角，无 pill 形）
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                style: const TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 15,
                  color: AppColors.onSurface,
                ),
                decoration: const InputDecoration(
                  border:             InputBorder.none,
                  enabledBorder:      InputBorder.none,
                  focusedBorder:      InputBorder.none,
                  errorBorder:        InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  disabledBorder:     InputBorder.none,
                  filled:             false,
                  isDense:            true,
                  contentPadding:     EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                  hintText:           '发条消息…',
                  hintStyle: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 15,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // 发送按钮
          GestureDetector(
            onTap: isSending ? null : onSend,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 36, height: 36,
              decoration: BoxDecoration(
                gradient: isSending ? null : AppColors.primaryGradient,
                color: isSending ? AppColors.surfaceContainerLow : null,
                shape: BoxShape.circle,
              ),
              child: isSending
                  ? Center(
                      child: SizedBox(
                        width: 15, height: 15,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary.withOpacity(0.5),
                        ),
                      ),
                    )
                  : const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 17),
            ),
          ),
        ],
      ),
    );
  }
}

