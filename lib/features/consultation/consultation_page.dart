/// ════════════════════════════════════════════════════════════
///  宠小伊 AI 问诊 — 主聊天页
///
///  入参：petId（来自 GoRouter extra，由首页宠物选择 sheet 传入）
///
///  布局：
///    ┌─ AppBar（返回 + 宠物头像 + 名字 + ≡历史按钮）
///    │  [历史横幅] 查看历史模式时显示，含"返回"按钮
///    │  消息列表（用户右对齐，AI 左对齐+宠小伊头像，流式打字机）
///    │  报告卡片区（reportReady 后显示 3 张卡）
///    │  动作按钮（生成报告 / 设备数据）
///    └─ 输入栏（历史模式下隐藏）
///    endDrawer → _HistoryDrawer（右滑入的历史会话列表）
/// ════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../shared/theme/app_colors.dart';
import '../pet/data/repository/pet_peer_repository.dart';
import 'controller/consultation_controller.dart';
import 'data/models/consultation_models.dart';

class ConsultationPage extends ConsumerStatefulWidget {
  final String petId;
  const ConsultationPage({super.key, required this.petId});

  @override
  ConsumerState<ConsultationPage> createState() => _ConsultationPageState();
}

class _ConsultationPageState extends ConsumerState<ConsultationPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _scrollCtrl = ScrollController();
  final _inputCtrl = TextEditingController();
  final _inputFocus = FocusNode();

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _inputCtrl.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scrollCtrl.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    _inputCtrl.clear();
    HapticFeedback.selectionClick();
    await ref
        .read(consultationControllerProvider(widget.petId).notifier)
        .sendMessage(text);
    _scrollToBottom();
  }

  void _showDeviceDataHint() {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('设备数据接入中 · 敬请期待'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.onSurface.withOpacity(0.9),
        ),
      );
  }

  Future<void> _openReport(String route) async {
    HapticFeedback.mediumImpact();
    final notifier =
        ref.read(consultationControllerProvider(widget.petId).notifier);
    var report = ref.read(consultationControllerProvider(widget.petId)).report;
    if (report == null) {
      await notifier.generateReport();
      report = ref.read(consultationControllerProvider(widget.petId)).report;
    }
    if (!mounted || report == null) return;

    // 获取宠物头像（如果可以拿到）
    final petInfo =
        ref.read(consultationControllerProvider(widget.petId)).session?.petInfo;
    String petAvatar = '';
    try {
      final petModel = await ref
          .read(petPeerRepositoryProvider)
          .fetchPetInfo(deviceId: widget.petId);
      petAvatar = petModel.avatar;
    } catch (_) {}

    if (!mounted) return;
    context.push(route, extra: {
      'report':    report,
      'petInfo':   petInfo,
      'petAvatar': petAvatar,
    });
  }

  void _openHistoryDrawer(ConsultationState state) {
    HapticFeedback.selectionClick();
    _scaffoldKey.currentState?.openEndDrawer();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(consultationControllerProvider(widget.petId), (prev, next) {
      if (prev?.messages.length != next.messages.length) _scrollToBottom();
      if (next.messages.isNotEmpty &&
          prev?.messages.isNotEmpty == true &&
          prev!.messages.last.content != next.messages.last.content) {
        _scrollToBottom();
      }
      if (next.errorMessage != null &&
          prev?.errorMessage != next.errorMessage) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ));
        ref
            .read(consultationControllerProvider(widget.petId).notifier)
            .clearError();
      }
    });

    final state = ref.watch(consultationControllerProvider(widget.petId));

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.surface,
      appBar: _buildAppBar(context, state),
      endDrawer: _HistoryDrawer(
        historyList: state.historyList,
        isLoading: state.isLoadingHistory,
        onSelectSession: (summary) async {
          Navigator.of(context).pop(); // 关闭 drawer
          await ref
              .read(consultationControllerProvider(widget.petId).notifier)
              .restoreHistorySession(summary.sessionId);
          _scrollToBottom();
        },
        onDeleteSession: (sessionId) async {
          await ref
              .read(consultationControllerProvider(widget.petId).notifier)
              .deleteHistorySession(sessionId);
        },
      ),
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            state.isInitializing && state.messages.isEmpty
                ? const _InitLoading()
                : Column(
                    children: [
                      // ── 历史查看横幅 ─────────────────────
                      if (state.isViewingHistory)
                        _HistoryViewBanner(
                          title: state.historyViewTitle ?? '历史问诊',
                          onExit: () {
                            ref
                                .read(consultationControllerProvider(widget.petId)
                                    .notifier)
                                .exitHistoryView();
                            _scrollToBottom();
                          },
                        ),

                      // ── 消息列表 + 报告卡（生成完成后出现）──
                      Expanded(
                        child: ListView.builder(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                          // report != null 时末尾追加报告卡片区
                          itemCount: state.messages.length +
                              (state.report != null ? 1 : 0),
                          itemBuilder: (context, i) {
                            if (i < state.messages.length) {
                              return _MessageBubble(message: state.messages[i]);
                            }
                            return _ReportCardsArea(
                              onTapDiagnosis: () =>
                                  _openReport(AppRoutes.reportDiagnosis),
                              onTapCare: () => _openReport(AppRoutes.reportCare),
                              onTapMedical: () =>
                                  _openReport(AppRoutes.reportMedical),
                              isGenerating: false,
                              hasReport: true,
                            );
                          },
                        ),
                      ),

                      // ── 动作按钮区（历史模式隐藏）────────
                      if (!state.isViewingHistory)
                        _ActionBar(
                          reportReady: state.reportReady,
                          isGenerating: state.isGeneratingReport,
                          hasSession: state.hasSession,
                          onGenerateReport: () async {
                            HapticFeedback.mediumImpact();
                            await ref
                                .read(consultationControllerProvider(widget.petId).notifier)
                                .generateReport();
                            // 生成完成同滕到底部显示卡片
                            _scrollToBottom();
                          },
                        ),

                      // ── 输入栏（历史模式隐藏）────────────
                      if (!state.isViewingHistory)
                        _InputBar(
                          controller: _inputCtrl,
                          focusNode: _inputFocus,
                          enabled: state.hasSession && !state.isReplying,
                          isReplying: state.isReplying,
                          onSend: _send,
                        ),
                    ],
                  ),

            // ── 生成报告全局遮罩 ────────────────────────
            if (state.isGeneratingReport) const _GeneratingOverlay(),
          ],
        ),
      ),
    );
  }

  // ── AppBar ───────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(BuildContext context, ConsultationState s) {
    final pet = s.session?.petInfo;
    return AppBar(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      titleSpacing: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        color: AppColors.onSurface,
        onPressed: () => Navigator.maybePop(context),
      ),
      title: pet == null
          ? const SizedBox.shrink()
          : Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.secondaryContainer,
                  child: Text(
                    _emojiForGender(pet.gender),
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        pet.name.isEmpty ? '宠物' : pet.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ),
                      ),
                      if (pet.breed.isNotEmpty || pet.age.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            [pet.breed, pet.age]
                                .where((e) => e.isNotEmpty)
                                .join(' · '),
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
      // ── 右侧历史按钮 ─────────────────────────────────
      actions: [
        Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.menu_rounded, size: 22),
              color: AppColors.onSurface,
              tooltip: '历史问诊',
              onPressed: () => _openHistoryDrawer(s),
            ),
            // 有历史记录时显示小红点
            if (s.historyList.isNotEmpty)
              Positioned(
                right: 10,
                top: 10,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  String _emojiForGender(String gender) {
    if (gender == '公' || gender.toLowerCase() == 'male') return '🐾';
    if (gender == '母' || gender.toLowerCase() == 'female') return '🐾';
    return '🐾';
  }
}

// ══════════════════════════════════════════════════════════
//  历史查看横幅
// ══════════════════════════════════════════════════════════

class _HistoryViewBanner extends StatelessWidget {
  final String title;
  final VoidCallback onExit;
  const _HistoryViewBanner({required this.title, required this.onExit});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.secondaryContainer.withOpacity(0.8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.history_rounded,
              size: 16, color: AppColors.secondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '历史记录：$title',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.secondary,
              ),
            ),
          ),
          GestureDetector(
            onTap: onExit,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.secondary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                '返回问诊',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  右侧历史抽屉
// ══════════════════════════════════════════════════════════

class _HistoryDrawer extends StatelessWidget {
  final List<ConsultationSessionSummary> historyList;
  final bool isLoading;
  final void Function(ConsultationSessionSummary) onSelectSession;
  final void Function(String sessionId) onDeleteSession;

  const _HistoryDrawer({
    required this.historyList,
    required this.isLoading,
    required this.onSelectSession,
    required this.onDeleteSession,
  });


  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.82,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          bottomLeft: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 标题栏 ───────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
              child: Row(
                children: [
                  Icon(Icons.history_rounded,
                      size: 22, color: AppColors.secondary),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      '历史问诊',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: AppColors.onSurfaceVariant,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Divider(color: AppColors.outline.withOpacity(0.2), height: 1),
            const SizedBox(height: 8),

            // ── 内容区 ───────────────────────────────
            Expanded(
              child: isLoading
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            color: AppColors.secondary,
                            strokeWidth: 2.5,
                          ),
                          SizedBox(height: 12),
                          Text('加载历史记录…',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.onSurfaceVariant)),
                        ],
                      ),
                    )
                  : historyList.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.chat_bubble_outline_rounded,
                                  size: 48,
                                  color: AppColors.onSurfaceVariant
                                      .withOpacity(0.4)),
                              const SizedBox(height: 12),
                              Text(
                                '暂无历史问诊记录',
                                style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.onSurfaceVariant),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          itemCount: historyList.length,
                          separatorBuilder: (_, __) => Divider(
                            color: AppColors.outline.withOpacity(0.12),
                            height: 1,
                            indent: 16,
                            endIndent: 16,
                          ),
                          itemBuilder: (context, i) {
                            final s = historyList[i];
                            return _HistorySessionTile(
                              summary: s,
                              index: i,
                              onRestore: () => onSelectSession(s),
                              onDelete: () => onDeleteSession(s.sessionId),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistorySessionTile extends StatelessWidget {
  final ConsultationSessionSummary summary;
  final int index;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  const _HistorySessionTile({
    required this.summary,
    required this.index,
    required this.onRestore,
    required this.onDelete,
  });

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '删除问诊记录',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        content: Text(
          '确定删除「${summary.displayTitle}」？\n删除后无法恢复。',
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('取消',
                style: TextStyle(color: AppColors.onSurfaceVariant)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除',
                style: TextStyle(
                    color: AppColors.error, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed == true) onDelete();
  }

  @override
  Widget build(BuildContext context) {
    // 单行：[🩺] [标题 + 日期]（点击 = 恢复）  [🗑]
    return InkWell(
      onTap: onRestore,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        child: Row(
          children: [
            // 左侧图标
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.secondaryContainer.withOpacity(0.6),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: const Text('🩺', style: TextStyle(fontSize: 17)),
            ),
            const SizedBox(width: 10),
            // 标题 + 日期
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    summary.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    summary.dateOnly,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            // 右侧删除按钮
            IconButton(
              icon: Icon(Icons.delete_outline_rounded,
                  size: 18, color: AppColors.onSurfaceVariant),
              splashRadius: 20,
              tooltip: '删除',
              onPressed: () => _confirmDelete(context),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  子组件
// ══════════════════════════════════════════════════════════

// ── 启动加载 ──────────────────────────────────────────────
class _InitLoading extends StatelessWidget {
  const _InitLoading();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            color: AppColors.secondary,
            strokeWidth: 2.5,
          ),
          SizedBox(height: 14),
          Text(
            '宠小伊正在调阅档案…',
            style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// ── 消息气泡 ──────────────────────────────────────────────

/// 单条消息：用户气泡 | AI 气泡（可能含多个视觉块）
class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;
    if (isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, left: 50),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.secondary,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Text(
            message.content,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.4,
            ),
          ),
        ),
      );
    }

    // AI 消息 — 分离出 <追问> 段，作为独立气泡
    // 流式时用 parseStreaming 处理未闭合标签，完成后用 parse
    final segments = message.isStreaming
        ? AiOutputParser.parseStreaming(message.content)
        : AiOutputParser.parse(message.content);
    final askSegs = segments.where((s) => s.tag == '追问').toList();
    final mainSegs = segments.where((s) => s.tag != '追问').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _AiBubble(segments: mainSegs, isStreaming: message.isStreaming),
        // 追问内容 — 独立聊天气泡
        for (final ask in askSegs)
          _FollowUpBubble(
              content: ask.content, isStreaming: message.isStreaming),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────
//  主 AI 气泡
// ─────────────────────────────────────────────────────────
class _AiBubble extends StatelessWidget {
  final List<TaggedSegment> segments;
  final bool isStreaming;
  const _AiBubble({required this.segments, required this.isStreaming});

  BoxDecoration get _bubbleDeco => BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 12,
            spreadRadius: -4,
            offset: const Offset(0, 2),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    // 还没有任何内容 → 只显示打字指示
    if (segments.isEmpty && isStreaming) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8, right: 40),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _AiAvatar(),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: _bubbleDeco,
              child: const _TypingIndicator(),
            ),
          ],
        ),
      );
    }

    // 构建内容块列表
    final children = <Widget>[];
    for (final seg in segments) {
      final w = _buildSegment(seg);
      if (w != null) children.add(w);
    }
    if (isStreaming) children.add(const _TypingIndicator());
    if (children.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 40),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _AiAvatar(),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              decoration: _bubbleDeco,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: children,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildSegment(TaggedSegment seg) {
    switch (seg.tag) {
      // ── 普通文本 → Markdown ──────────────────────────
      case null:
        final text = seg.content.trim();
        if (text.isEmpty) return null;
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: MarkdownBody(
            data: text,
            styleSheet: _mdStyle,
            shrinkWrap: true,
            selectable: false,
          ),
        );

      // ── 思考过程 → 可折叠块 ──────────────────────────
      case '整体思考':
        return _ThinkingSection(
            content: seg.content, isStreaming: isStreaming);

      // ── 医疗图谱分析 → 彩色疾病卡片 ────────────────
      case 'RelationRAG分析':
        return _MedicalAnalysisSection(content: seg.content);

      // ── 初步诊断 → 小卡片 ────────────────────────────
      case '诊断':
        return _DiagnosisCard(content: seg.content);

      // ── 其他未知 tag → Markdown ──────────────────────
      default:
        final text = seg.content.trim();
        if (text.isEmpty) return null;
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: MarkdownBody(
            data: text,
            styleSheet: _mdStyle,
            shrinkWrap: true,
          ),
        );
    }
  }

  static final _mdStyle = MarkdownStyleSheet(
    p: const TextStyle(
        fontSize: 15, height: 1.55, color: AppColors.onSurface),
    strong: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.onSurface),
    em: const TextStyle(
        fontSize: 15,
        fontStyle: FontStyle.italic,
        color: AppColors.onSurface),
    h1: const TextStyle(
        fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.onSurface),
    h2: const TextStyle(
        fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.onSurface),
    h3: const TextStyle(
        fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.onSurface),
    listBullet: const TextStyle(fontSize: 15, color: AppColors.onSurface),
    blockSpacing: 6,
    listIndent: 16,
  );
}

// ─────────────────────────────────────────────────────────
//  AI 头像（宠小伊形象）
// ─────────────────────────────────────────────────────────
class _AiAvatar extends StatelessWidget {
  const _AiAvatar();
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.asset(
        'assets/images/chongxiaoyi.png',
        width: 32,
        height: 32,
        fit: BoxFit.cover,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  可折叠「思考」块
//  - 流式输出时：始终展开，标题显示 loading 旋转
//  - 输出完成后：默认展开，用户可手动折叠
// ─────────────────────────────────────────────────────────
class _ThinkingSection extends StatefulWidget {
  final String content;
  final bool isStreaming;
  const _ThinkingSection(
      {required this.content, required this.isStreaming});

  @override
  State<_ThinkingSection> createState() => _ThinkingSectionState();
}

class _ThinkingSectionState extends State<_ThinkingSection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final canCollapse = !widget.isStreaming;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer.withOpacity(0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.outlineVariant.withOpacity(0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── 标题行 ──────────────────────────────────────
          InkWell(
            onTap: canCollapse
                ? () => setState(() => _expanded = !_expanded)
                : null,
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(12),
              bottom: _expanded ? Radius.zero : const Radius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 🧠 emoji 图标
                  Text('🧠', style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 5),
                  Text(
                    widget.isStreaming ? '思考中…' : '思考',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (widget.isStreaming)
                    SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.2,
                        color:
                            AppColors.onSurfaceVariant.withOpacity(0.5),
                      ),
                    )
                  else
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 15,
                      color: AppColors.onSurfaceVariant,
                    ),
                ],
              ),
            ),
          ),
          // ── 内容（展开时）────────────────────────────────
          if (_expanded) ...[
            Container(
              height: 1,
              color: AppColors.outlineVariant.withOpacity(0.25),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: MarkdownBody(
                data: widget.content.trim(),
                shrinkWrap: true,
                selectable: false,
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(
                      fontSize: 12,
                      height: 1.55,
                      color: AppColors.onSurfaceVariant),
                  strong: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurfaceVariant),
                  listBullet: TextStyle(
                      fontSize: 12,
                      color: AppColors.onSurfaceVariant),
                  blockSpacing: 4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  医疗图谱分析（RelationRAG分析） — 彩色疾病概率卡片
// ─────────────────────────────────────────────────────────
class _MedicalAnalysisSection extends StatelessWidget {
  final String content;
  const _MedicalAnalysisSection({required this.content});

  /// 解析 **疾病名【患病概率：X%】** + 分析：...
  static List<({String name, int prob, String analysis})> _parse(
      String text) {
    final result = <({String name, int prob, String analysis})>[];
    // 匹配 **...**【患病概率：数字%】 然后紧跟分析内容
    final pattern = RegExp(
      r'\*{0,2}([^\n\*]+?)(?:【患病概率[：:](\d+)%】)\*{0,2}[\n\s]*(?:分析[：:]\s*)?([\s\S]+?)(?=(?:\n[\n\s]*\*{0,2}[^\n]+?(?:【患病概率)|$))',
      multiLine: true,
    );
    for (final m in pattern.allMatches(text)) {
      final name = m.group(1)?.trim() ?? '';
      final prob = int.tryParse(m.group(2) ?? '0') ?? 0;
      final analysis = m.group(3)?.trim() ?? '';
      if (name.isNotEmpty) {
        result.add((name: name, prob: prob, analysis: analysis));
      }
    }
    // 若正则没匹配到，fallback：直接显示原文 Markdown
    return result;
  }

  /// 根据概率返回颜色
  static Color _cardColor(int prob) {
    if (prob >= 50) return const Color(0xFFFFEBEE); // 高风险 - 淡红
    if (prob >= 25) return const Color(0xFFFFF3E0); // 中风险 - 淡橙
    return const Color(0xFFE8F5E9);                 // 低风险 - 淡绿
  }

  static Color _headerColor(int prob) {
    if (prob >= 50) return const Color(0xFFE53935);
    if (prob >= 25) return const Color(0xFFEF6C00);
    return const Color(0xFF2E7D32);
  }

  @override
  Widget build(BuildContext context) {
    final entries = _parse(content);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── 标题行 ──────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 4),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                '医疗图谱分析',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
            ],
          ),
        ),
        // ── 疾病卡片列表 ────────────────────────────────
        if (entries.isEmpty)
          // fallback：原文 markdown
          MarkdownBody(
            data: content.trim(),
            shrinkWrap: true,
            styleSheet: MarkdownStyleSheet(
              p: const TextStyle(
                  fontSize: 13, height: 1.5, color: AppColors.onSurface),
            ),
          )
        else
          ...entries.map((e) => _DiseaseCard(entry: e)),
        const SizedBox(height: 6),
      ],
    );
  }
}

class _DiseaseCard
    extends StatelessWidget {
  final ({String name, int prob, String analysis}) entry;
  const _DiseaseCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final bg = _MedicalAnalysisSection._cardColor(entry.prob);
    final hc = _MedicalAnalysisSection._headerColor(entry.prob);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: hc.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题行（疾病名 + 概率徽章）
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: hc.withOpacity(0.12),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(10),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    entry.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: hc,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: hc,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${entry.prob}%',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 分析内容
          if (entry.analysis.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
              child: Text(
                entry.analysis,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.55,
                  color: AppColors.onSurface.withOpacity(0.85),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  初步诊断卡片
// ─────────────────────────────────────────────────────────
class _DiagnosisCard extends StatelessWidget {
  final String content;
  const _DiagnosisCard({required this.content});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.tertiaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: AppColors.tertiary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: const [
            Icon(Icons.check_circle_outline_rounded,
                size: 14, color: AppColors.tertiary),
            SizedBox(width: 4),
            Text('初步诊断',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.tertiary)),
          ]),
          const SizedBox(height: 4),
          MarkdownBody(
            data: content.trim(),
            shrinkWrap: true,
            styleSheet: MarkdownStyleSheet(
              p: const TextStyle(
                  fontSize: 14, height: 1.5, color: AppColors.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  追问 — 独立聊天气泡（带 AI 头像，浅绿色背景）
// ─────────────────────────────────────────────────────────
class _FollowUpBubble extends StatelessWidget {
  final String content;
  final bool isStreaming;
  const _FollowUpBubble(
      {required this.content, required this.isStreaming});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, right: 40),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _AiAvatar(),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color:
                    AppColors.secondaryContainer.withOpacity(0.45),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                border: Border.all(
                    color: AppColors.secondary.withOpacity(0.2)),
              ),
              child: isStreaming
                  ? const _TypingIndicator()
                  : MarkdownBody(
                      data: content.trim(),
                      shrinkWrap: true,
                      selectable: false,
                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(
                            fontSize: 15,
                            height: 1.5,
                            color: AppColors.onSurface),
                        strong: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurface),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}


// 打字机光标动画
class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final t = (_c.value * 3 - i).clamp(0.0, 1.0);
            final opacity = 0.3 + (0.7 * (t < 0.5 ? t * 2 : 2 - t * 2));
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(opacity),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}

// ── 报告卡片区 ─────────────────────────────────────────────
class _ReportCardsArea extends StatelessWidget {
  final VoidCallback onTapDiagnosis;
  final VoidCallback onTapCare;
  final VoidCallback onTapMedical;
  final bool isGenerating;
  final bool hasReport;

  const _ReportCardsArea({
    required this.onTapDiagnosis,
    required this.onTapCare,
    required this.onTapMedical,
    required this.isGenerating,
    required this.hasReport,
  });

  @override
  Widget build(BuildContext context) {
    // 统一的副标题 & 可点击状态逻辑
    String diagSubtitle;
    String careSubtitle;
    String medSubtitle;
    VoidCallback? diagTap;
    VoidCallback? careTap;
    VoidCallback? medTap;

    if (isGenerating) {
      // 正在生成中：所有卡片显示加载，禁用点击
      diagSubtitle = '正在生成报告，请稍候…';
      careSubtitle = '正在生成报告，请稍候…';
      medSubtitle  = '正在生成报告，请稍候…';
      diagTap = careTap = medTap = null;
    } else if (!hasReport) {
      // 还没生成：只有诊断卡可点击（触发生成），另外两张提示
      diagSubtitle = '点击生成完整诊断报告';
      careSubtitle = '生成报告后解锁';
      medSubtitle  = '生成报告后解锁';
      diagTap = onTapDiagnosis;
      careTap = null;
      medTap  = null;
    } else {
      // 报告已生成：三张全部可用
      diagSubtitle = '宠小伊智能宠医已开出诊断，点击查看';
      careSubtitle = '已生成在家处理建议，点击查看';
      medSubtitle  = '已生成医疗检测方案，点击查看';
      diagTap = onTapDiagnosis;
      careTap = onTapCare;
      medTap  = onTapMedical;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: Column(
        children: [
          _ReportCard(
            icon: Icons.medical_information_outlined,
            title: '宠小伊问诊报告',
            subtitle: hasReport
                ? '宠小伊智能宠医已开出诊断，请点击查看详情'
                : isGenerating
                    ? '正在生成…'
                    : '点击生成诊断报告',
            onTap: isGenerating ? null : onTapDiagnosis,
            showLoading: isGenerating,
          ),
          const SizedBox(height: 12),
          _ReportCard(
            icon: Icons.home_outlined,
            title: '治疗养护建议',
            subtitle: '已生成在家处理建议，请点击查看详情',
            onTap: onTapCare,
          ),
          const SizedBox(height: 12),
          _ReportCard(
            icon: Icons.science_outlined,
            title: '医疗检测方案',
            subtitle: '已生成医疗处理建议，请点击查看详情',
            onTap: onTapMedical,
          ),
          const SizedBox(height: 12),
          // Container(
          //   padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          //   decoration: BoxDecoration(
          //     color: AppColors.secondaryContainer.withOpacity(0.3),
          //     borderRadius: BorderRadius.circular(12),
          //   ),
          //   child: Column(
          //     crossAxisAlignment: CrossAxisAlignment.start,
          //     children: [
          //       Row(children: const [
          //         Icon(Icons.image_search_outlined,
          //             size: 15, color: AppColors.secondary),
          //         SizedBox(width: 6),
          //         Text('本次问诊将加入宠物全景画像，可提高准确率',
          //             style: TextStyle(
          //                 fontSize: 13,
          //                 fontWeight: FontWeight.w700,
          //                 color: AppColors.secondary)),
          //       ]),
          //       const SizedBox(height: 4),
          //       Text('默认保存，如需关闭，可在全景画像或二维码中进行管理',
          //           style: TextStyle(
          //               fontSize: 11, color: AppColors.onSurfaceVariant)),
          //     ],
          //   ),
          // ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool showLoading;
  const _ReportCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.showLoading = false,
  });
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.secondary.withOpacity(0.18),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 12,
              spreadRadius: -4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.secondaryContainer.withOpacity(0.6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 22, color: AppColors.secondary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.secondary,
                      )),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant,
                      )),
                ],
              ),
            ),
            if (showLoading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.secondary,
                ),
              )
            else
              Icon(Icons.chevron_right_rounded,
                  color: AppColors.onSurfaceVariant, size: 22),
          ],
        ),
      ),
    );
  }
}

// ── 生成报告全局遮罩 loading ───────────────────────────────
class _GeneratingOverlay extends StatelessWidget {
  const _GeneratingOverlay();
  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.45),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 宠小伊形象 + 右下角 loading 徽章
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(40),
                      child: Image.asset(
                        'assets/images/chongxiaoyi.png',
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.surface,
                          width: 2,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.secondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  '正在生成诊断报告…',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '宠小伊正在分析问诊记录，请稍候…',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


// ── 动作按鈕区 ───────────────────────────────────────────
class _ActionBar extends StatelessWidget {
  final bool reportReady;
  final bool isGenerating;
  final bool hasSession;
  final VoidCallback onGenerateReport;
  const _ActionBar({
    required this.reportReady,
    required this.isGenerating,
    required this.hasSession,
    required this.onGenerateReport,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          _ActionPill(
            icon: Icons.summarize_outlined,
            label: '生成报告',    // 文字始终不变，loading 由全局遮罩展示
            highlight: reportReady,
            onTap: hasSession && !isGenerating ? onGenerateReport : null,
          ),
          // 「设备数据」按鈕已隐藏
        ],
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool highlight;
  final VoidCallback? onTap;
  const _ActionPill({
    required this.icon,
    required this.label,
    this.highlight = false,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: highlight && enabled
              ? AppColors.secondary
              : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: highlight && enabled
                ? AppColors.secondary
                : AppColors.outlineVariant.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color: highlight && enabled
                    ? Colors.white
                    : AppColors.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: highlight && enabled
                      ? Colors.white
                      : enabled
                          ? AppColors.onSurface
                          : AppColors.onSurfaceVariant,
                )),
          ],
        ),
      ),
    );
  }
}

// ── 输入栏 ────────────────────────────────────────────────
class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final bool isReplying;
  final VoidCallback onSend;
  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.isReplying,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        4,
        16,
        MediaQuery.of(context).viewInsets.bottom > 0
            ? 8
            : MediaQuery.of(context).padding.bottom + 8,
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                enabled: enabled,
                minLines: 1,
                maxLines: 3,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => enabled ? onSend() : null,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: isReplying ? '宠小伊正在回复…' : '请输入问题',
                  hintStyle: TextStyle(
                    fontSize: 14,
                    color: AppColors.onSurfaceVariant,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: enabled
                ? AppColors.secondary
                : AppColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: enabled ? onSend : null,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                child: Text(
                  '发送',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: enabled
                        ? Colors.white
                        : AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  报告选择底部面板
// ══════════════════════════════════════════════════════════
class _ReportPickerSheet extends StatelessWidget {
  final ConsultationReport report;
  final PetInfoSnapshot? petInfo;
  final String petAvatar;
  final VoidCallback onTapDiagnosis;
  final VoidCallback onTapCare;
  final VoidCallback onTapMedical;

  const _ReportPickerSheet({
    required this.report,
    required this.petInfo,
    required this.petAvatar,
    required this.onTapDiagnosis,
    required this.onTapCare,
    required this.onTapMedical,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 24,
            spreadRadius: -4,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 拖动条
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // ── 宠物信息头部 ────────────────────────────
            if (petInfo != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    // 头像
                    _SheetAvatar(avatarUrl: petAvatar, name: petInfo!.name),
                    const SizedBox(width: 12),
                    // 名字 + 主疾病
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            petInfo!.name.isEmpty ? '宠物' : petInfo!.name,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppColors.onSurface,
                            ),
                          ),
                          if (report.primaryDisease.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Row(children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFEF4444),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  '疑似 ${report.primaryDisease}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFFEF4444),
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ]),
                          ],
                        ],
                      ),
                    ),
                    // 关闭按钮
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      color: AppColors.onSurfaceVariant,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // ── 3 张报告卡 ──────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _SheetCard(
                    icon: Icons.medical_information_outlined,
                    title: '宠小伊问诊报告',
                    subtitle: '综合诊断 · 可能疾病分析',
                    accentColor: const Color(0xFF6366F1),
                    onTap: onTapDiagnosis,
                  ),
                  const SizedBox(height: 10),
                  _SheetCard(
                    icon: Icons.home_outlined,
                    title: '治疗养护建议',
                    subtitle: '居家护理指南',
                    accentColor: const Color(0xFF10B981),
                    onTap: onTapCare,
                  ),
                  const SizedBox(height: 10),
                  _SheetCard(
                    icon: Icons.science_outlined,
                    title: '医疗检测方案',
                    subtitle: '推荐医院检查与治疗',
                    accentColor: const Color(0xFF0EA5E9),
                    onTap: onTapMedical,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _SheetAvatar extends StatelessWidget {
  final String avatarUrl;
  final String name;
  const _SheetAvatar({required this.avatarUrl, required this.name});

  @override
  Widget build(BuildContext context) {
    final emoji = name.contains('猫') ? '🐱' : name.contains('狗') ? '🐶' : '🐾';
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF6366F1).withOpacity(0.08),
        border: Border.all(
          color: const Color(0xFF6366F1).withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: ClipOval(
        child: avatarUrl.isNotEmpty
            ? Image.network(avatarUrl, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Center(child: Text(emoji, style: const TextStyle(fontSize: 24))))
            : Center(child: Text(emoji, style: const TextStyle(fontSize: 24))),
      ),
    );
  }
}

class _SheetCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final VoidCallback onTap;
  const _SheetCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accentColor.withOpacity(0.15), width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 22, color: accentColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: accentColor,
                        )),
                    Text(subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.onSurfaceVariant,
                        )),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: accentColor.withOpacity(0.5)),
            ],
          ),
        ),
      ),
    );
  }
}
