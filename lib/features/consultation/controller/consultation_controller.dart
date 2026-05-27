/// ════════════════════════════════════════════════════════════
///  宠小伊 AI 问诊 — ConsultationController
///
///  新增功能（v0.4+）：
///    - 历史会话列表（historyList）
///    - 查看历史模式（isViewingHistory）
///    - loadHistory() / showHistorySession() / exitHistoryView()
/// ════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/consultation_models.dart';
import '../data/repository/consultation_repository.dart';

// ══════════════════════════════════════════════════════════
//  状态类
// ══════════════════════════════════════════════════════════

class ConsultationState {
  // ── 当前会话 ──────────────────────────────────────────
  final ConsultationSession? session;
  final List<ChatMessage> messages;
  final bool isInitializing;
  final bool isReplying;
  final bool isGeneratingReport;
  final ConsultationReport? report;
  final String? errorMessage;

  // ── 历史记录 ──────────────────────────────────────────
  /// 当前宠物的历史会话摘要列表（按时间降序）
  final List<ConsultationSessionSummary> historyList;
  final bool isLoadingHistory;

  /// 是否正在查看历史会话（true 时输入栏隐藏，显示历史横幅）
  final bool isViewingHistory;

  /// 正在查看的历史会话标题（用于横幅显示）
  final String? historyViewTitle;

  /// 保存的当前问诊消息（切换到历史模式时暂存，退出后恢复）
  final List<ChatMessage> savedLiveMessages;

  const ConsultationState({
    this.session,
    this.messages = const [],
    this.isInitializing = false,
    this.isReplying = false,
    this.isGeneratingReport = false,
    this.report,
    this.errorMessage,
    this.historyList = const [],
    this.isLoadingHistory = false,
    this.isViewingHistory = false,
    this.historyViewTitle,
    this.savedLiveMessages = const [],
  });

  /// AI 已给出 `<诊断>` 段 → "生成报告"按钮可亮起
  bool get reportReady {
    if (isViewingHistory) return false; // 历史模式下不显示
    for (final m in messages) {
      if (m.role != ChatRole.assistant) continue;
      if (m.isStreaming) continue;
      if (AiOutputParser.hasDiagnosis(m.content)) return true;
    }
    return false;
  }

  bool get hasSession => session != null;

  ConsultationState copyWith({
    ConsultationSession? session,
    List<ChatMessage>? messages,
    bool? isInitializing,
    bool? isReplying,
    bool? isGeneratingReport,
    ConsultationReport? report,
    String? errorMessage,
    bool clearReport = false,
    bool clearError = false,
    List<ConsultationSessionSummary>? historyList,
    bool? isLoadingHistory,
    bool? isViewingHistory,
    String? historyViewTitle,
    bool clearHistoryViewTitle = false,
    List<ChatMessage>? savedLiveMessages,
  }) {
    return ConsultationState(
      session: session ?? this.session,
      messages: messages ?? this.messages,
      isInitializing: isInitializing ?? this.isInitializing,
      isReplying: isReplying ?? this.isReplying,
      isGeneratingReport: isGeneratingReport ?? this.isGeneratingReport,
      report: clearReport ? null : (report ?? this.report),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      historyList: historyList ?? this.historyList,
      isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
      isViewingHistory: isViewingHistory ?? this.isViewingHistory,
      historyViewTitle: clearHistoryViewTitle
          ? null
          : (historyViewTitle ?? this.historyViewTitle),
      savedLiveMessages: savedLiveMessages ?? this.savedLiveMessages,
    );
  }
}

// ══════════════════════════════════════════════════════════
//  控制器
// ══════════════════════════════════════════════════════════

class ConsultationController extends StateNotifier<ConsultationState> {
  final ConsultationRepository _repo;
  final String _petId;

  static const bool _useSyncFallback = false;
  bool _reportFinalized = false;

  ConsultationController(this._repo, this._petId)
      : super(const ConsultationState());

  // ── 1. 初始化 session ──────────────────────────────────

  Future<void> initSession(String petId) async {
    if (state.session != null) return;
    state = state.copyWith(isInitializing: true, clearError: true);

    debugPrint('[宠小伊] initSession petId=$petId');
    final result = await _repo.createSession(petId: petId);

    result.when(
      success: (sess) {
        debugPrint(
            '[宠小伊] initSession OK sessionId=${sess.sessionId} petName=${sess.petInfo.name}');
        state = state.copyWith(
          session: sess,
          isInitializing: false,
          messages: [
            ChatMessage(
              role: ChatRole.assistant,
              content: _welcomeText(sess.petInfo),
              createdAt: DateTime.now(),
            ),
          ],
        );
      },
      failure: (e) {
        debugPrint('[宠小伊] initSession FAIL: $e');
        state = state.copyWith(
          isInitializing: false,
          errorMessage: '连接宠小伊失败，请检查网络后重试',
        );
      },
    );
  }

  // ── 2. 发送消息 ────────────────────────────────────────

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final session = state.session;
    if (session == null) return;
    if (state.isReplying) return;

    // 若处于历史模式，先退出
    if (state.isViewingHistory) exitHistoryView();

    final userMsg = ChatMessage(
      role: ChatRole.user,
      content: trimmed,
      createdAt: DateTime.now(),
    );
    final aiPlaceholder = ChatMessage(
      role: ChatRole.assistant,
      content: '',
      isStreaming: true,
      createdAt: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMsg, aiPlaceholder],
      isReplying: true,
      clearError: true,
    );

    if (_useSyncFallback) {
      await _sendSync(session.sessionId, trimmed);
    } else {
      await _sendStream(session.sessionId, trimmed);
    }
  }

  Future<void> _sendStream(String sessionId, String text) async {
    final buf = StringBuffer();
    try {
      debugPrint('[宠小伊] _sendStream sessionId=$sessionId');
      await for (final ev in _repo.sendMessageStream(
        sessionId: sessionId,
        text: text,
      )) {
        switch (ev) {
          case StreamStart():
            break;
          case StreamDelta(text: final t):
            buf.write(t);
            _updateLastAssistant(buf.toString(), streaming: true);
          case StreamDone(fullText: final full):
            final bufText = buf.toString();
            String finalText;
            if (bufText.isEmpty && full.isNotEmpty) {
              finalText = full;
              debugPrint('[宠小伊] done: buf为空，用full_text兜底 len=${full.length}');
            } else {
              finalText = bufText;
              if (full.isNotEmpty && full.length > bufText.length + 50) {
                debugPrint(
                    '[宠小伊] done: full(${full.length}) > buf(${bufText.length})，可能有delta丢包');
              }
            }
            _updateLastAssistant(finalText, streaming: false);
          case StreamUnknown(event: final e, data: final d):
            debugPrint('[宠小伊] 未知SSE事件 $e: $d');
        }
      }
      if (state.messages.isNotEmpty && state.messages.last.isStreaming) {
        _updateLastAssistant(buf.toString(), streaming: false);
      }
      state = state.copyWith(isReplying: false);
      debugPrint('[宠小伊] _sendStream DONE len=${buf.length}');
    } catch (e) {
      debugPrint('[宠小伊] _sendStream ERROR: $e');
      _markLastAssistantFailed(e.toString());
      state = state.copyWith(
        isReplying: false,
        errorMessage: '发送失败，请重试',
      );
    }
  }

  Future<void> _sendSync(String sessionId, String text) async {
    debugPrint('[宠小伊] _sendSync sessionId=$sessionId');
    final result = await _repo.sendMessageSync(
      sessionId: sessionId,
      text: text,
    );
    result.when(
      success: (turn) {
        _updateLastAssistant(turn.consultation, streaming: false);
        state = state.copyWith(isReplying: false);
      },
      failure: (e) {
        _markLastAssistantFailed(e.toString());
        state = state.copyWith(
          isReplying: false,
          errorMessage: '发送失败，请重试',
        );
      },
    );
  }

  void _updateLastAssistant(String content, {required bool streaming}) {
    final msgs = state.messages;
    if (msgs.isEmpty) return;
    final last = msgs.last;
    if (last.role != ChatRole.assistant) return;
    state = state.copyWith(messages: [
      ...msgs.sublist(0, msgs.length - 1),
      last.copyWith(content: content, isStreaming: streaming),
    ]);
  }

  void _markLastAssistantFailed(String errMsg) {
    final msgs = state.messages;
    if (msgs.isEmpty) return;
    final last = msgs.last;
    if (last.role != ChatRole.assistant) return;
    state = state.copyWith(messages: [
      ...msgs.sublist(0, msgs.length - 1),
      last.copyWith(
        content: last.content.isEmpty ? '[发送失败：$errMsg]' : last.content,
        isStreaming: false,
      ),
    ]);
  }

  // ── 3. 生成报告 ────────────────────────────────────────

  Future<void> generateReport() async {
    final sess = state.session;
    if (sess == null) return;
    if (state.isGeneratingReport) return;
    if (state.report != null) return;

    state = state.copyWith(isGeneratingReport: true, clearError: true);
    debugPrint('[宠小伊] generateReport sessionId=${sess.sessionId}');

    final result = await _repo.generateReport(sessionId: sess.sessionId);
    result.when(
      success: (report) {
        debugPrint('[宠小伊] generateReport OK disease=${report.primaryDisease}');
        _reportFinalized = true;
        state = state.copyWith(isGeneratingReport: false, report: report);
      },
      failure: (e) {
        debugPrint('[宠小伊] generateReport FAIL: $e');
        state = state.copyWith(
          isGeneratingReport: false,
          errorMessage: '生成报告失败，请重试',
        );
      },
    );
  }

  // ── 4. 历史记录 ────────────────────────────────────────

  /// 加载当前宠物的历史会话列表（页面打开时调用一次）
  ///
  /// 过滤规则：仅过滤 title==null 的空会话（0条对话）。
  /// 不过滤当前活跃 session，避免恢复后历史列表清空。
  Future<void> loadHistory() async {
    if (state.isLoadingHistory) return;
    state = state.copyWith(isLoadingHistory: true);
    debugPrint('[宠小伊] loadHistory petId=$_petId');

    final result = await _repo.getSessionsByPet(petId: _petId);
    result.when(
      success: (list) {
        // 仅过滤 title==null 的空会话（用户未发送任何消息）
        final filtered = list
            .where((s) => s.title != null && s.title!.isNotEmpty)
            .toList();
        debugPrint('[宠小伊] loadHistory OK 原始=${list.length} 过滤后=${filtered.length}');
        state = state.copyWith(
          historyList: filtered,
          isLoadingHistory: false,
        );
      },
      failure: (e) {
        debugPrint('[宠小伊] loadHistory FAIL: $e');
        state = state.copyWith(isLoadingHistory: false);
      },
    );
  }

  /// 恢复历史会话（真正切换 session_id，后续消息走历史 session）
  ///
  /// 完整流程：
  ///   1. 从 /session/messages 获取历史 turns
  ///   2. 删除当前自动创建的空 Session A（从未发送过消息）
  ///   3. 把活跃 session 的 sessionId 替换为历史 sessionId
  ///   4. 把历史 turns 加载为当前消息列表
  ///   5. 从 historyList 移除已恢复的条目（它现在是活跃 session）
  Future<void> restoreHistorySession(String sessionId) async {
    debugPrint('[宠小伊] restoreHistorySession sessionId=$sessionId');

    final result = await _repo.getSessionMessages(sessionId: sessionId);
    result.when(
      success: (history) {
        final historyMsgs = <ChatMessage>[];
        for (final turn in history.turns) {
          historyMsgs.add(ChatMessage(
            role: ChatRole.user,
            content: turn.userInput,
            createdAt: DateTime.now(),
          ));
          historyMsgs.add(ChatMessage(
            role: ChatRole.assistant,
            content: turn.consultation,
            createdAt: DateTime.now(),
          ));
        }

        if (historyMsgs.isEmpty) {
          state = state.copyWith(errorMessage: '该历史记录暂无对话内容');
          return;
        }

        final currentSession = state.session;

        // ① 删除当前空 Session A（若从未发送消息）
        if (currentSession != null &&
            currentSession.sessionId != sessionId) {
          final hasUserMsgs =
              state.messages.any((m) => m.role == ChatRole.user);
          if (!hasUserMsgs) {
            unawaited(
                _repo.deleteSession(sessionId: currentSession.sessionId));
            debugPrint(
                '[宠小伊] restoreHistorySession — 删除空 Session A ${currentSession.sessionId}');
          }
        }

        // ② 构建以历史 sessionId 为 id 的 session 对象
        final restoredSession = currentSession != null
            ? ConsultationSession(
                sessionId: sessionId, // ← 切换为历史 session_id
                petId: currentSession.petId,
                petInfo: currentSession.petInfo,
              )
            : null;

        // ③ 更新状态：切换 session + 替换消息 + 退出只读
        // 保持 historyList 不变（历史列表不移除已恢复的条目）
        state = state.copyWith(
          session: restoredSession,
          messages: historyMsgs,
          isViewingHistory: false,
          clearHistoryViewTitle: true,
          savedLiveMessages: const [],
        );
        debugPrint(
            '[宠小伊] restoreHistorySession OK turns=${history.turns.length} newSessionId=$sessionId');
      },
      failure: (e) {
        debugPrint('[宠小伊] restoreHistorySession FAIL: $e');
        state = state.copyWith(errorMessage: '恢复历史记录失败，请重试');
      },
    );
  }


  /// 退出历史模式，恢复当前问诊会话
  void exitHistoryView() {
    if (!state.isViewingHistory) return;
    state = state.copyWith(
      messages: state.savedLiveMessages,
      savedLiveMessages: const [],
      isViewingHistory: false,
      clearHistoryViewTitle: true,
    );
  }

  /// 删除某条历史会话（仅在历史列表中操作）
  Future<void> deleteHistorySession(String sessionId) async {
    debugPrint('[宠小伊] deleteHistorySession sessionId=$sessionId');
    final result = await _repo.deleteSession(sessionId: sessionId);
    result.when(
      success: (_) {
        // 从本地列表移除
        state = state.copyWith(
          historyList: state.historyList
              .where((s) => s.sessionId != sessionId)
              .toList(),
        );
        // 若正在查看被删除的历史，退出历史模式
        if (state.isViewingHistory && state.historyViewTitle != null) {
          exitHistoryView();
        }
        debugPrint('[宠小伊] deleteHistorySession OK');
      },
      failure: (e) {
        debugPrint('[宠小伊] deleteHistorySession FAIL: $e');
        state = state.copyWith(errorMessage: '删除失败，请重试');
      },
    );
  }


  // ── 5. 工具方法 ────────────────────────────────────

  void clearError() {
    if (state.errorMessage != null) {
      state = state.copyWith(clearError: true);
    }
  }

  Future<void> cleanup() async {
    final sess = state.session;
    if (sess == null) return;

    // 判断用户是否发送过任何消息
    final hasUserMessages = state.messages.any((m) => m.role == ChatRole.user);
    if (!hasUserMessages) {
      // 未发过消息 → 自动删除空 session（不保留在历史中）
      debugPrint('[宠小伊] cleanup() — 无对话，删除空 session ${sess.sessionId}');
      unawaited(_repo.deleteSession(sessionId: sess.sessionId));
    } else {
      // 有对话记录 → 保留在数据库（用户可从历史查看）
      debugPrint('[宠小伊] cleanup() — 保留 session，用户消息数=${state.messages.where((m) => m.role == ChatRole.user).length}');
    }
  }

  String _welcomeText(PetInfoSnapshot pet) {
    final name = pet.name.isEmpty ? '你的宝贝' : pet.name;
    final breed = pet.breed.isNotEmpty ? '（${pet.breed}）' : '';
    return '你好！我是宠小伊 🩺\n\n我已了解 **$name**$breed 的健康档案。\n请告诉我它最近有哪些不适症状，我来帮你分析～';
  }
}

void unawaited(Future future) {
  // ignore: unawaited_futures
  future;
}

// ── Riverpod Provider ─────────────────────────────────────
final consultationControllerProvider = StateNotifierProvider.autoDispose
    .family<ConsultationController, ConsultationState, String>(
        (ref, petId) {
  final ctrl = ConsultationController(
    ref.read(consultationRepositoryProvider),
    petId,
  );
  ctrl.initSession(petId);
  ctrl.loadHistory(); // 页面打开时预加载历史列表
  ref.onDispose(ctrl.cleanup);
  return ctrl;
});
