/// ════════════════════════════════════════════════════════════
///  AI 配额 Repository & Provider
///
///  职责：
///    ✅ 调用 POST /sdkapi/ai/use-once — App 大模型调用成功后扣减一次配额
///    ✅ 调用 GET  /api/user/ai-quota  — 查询今日剩余配额
///    ❌ 不做本地缓存（每次从服务端取最新数据）
///
///  使用方式（在 AI 分析成功回调后）：
///    final quota = await ref.read(aiQuotaRepositoryProvider).useOnce();
///    if (quota != null) {
///      // quota.used / quota.limit / quota.remaining
///    }
/// ════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';

// ── 配额数据类 ────────────────────────────────────────────
class AiQuotaInfo {
  final int  used;       // 今日已用次数
  final int  limit;      // 总额度（-1 = VIP 无限）
  final int  remaining;  // 剩余次数（-1 = VIP 无限）
  final bool vip;        // 是否 VIP

  const AiQuotaInfo({
    required this.used,
    required this.limit,
    required this.remaining,
    required this.vip,
  });

  /// limit == -1 表示 VIP 无限次
  bool get isUnlimited => limit == -1;

  factory AiQuotaInfo.fromJson(Map<String, dynamic> json) => AiQuotaInfo(
    used:      (json['used']      as int?) ?? 0,
    limit:     (json['limit']     as int?) ?? 10,
    remaining: (json['remaining'] as int?) ?? 0,
    vip:       (json['vip']       as bool?) ?? false,
  );
}

// ── Repository ────────────────────────────────────────────
class AiQuotaRepository {
  final ApiClient _client;

  AiQuotaRepository(this._client);

  /// App 调用大模型成功后调用此接口扣减一次配额
  ///
  /// 返回扣减后的最新配额信息
  /// 若请求失败（如网络错误），返回 null，不影响 App 正常功能
  Future<AiQuotaInfo?> useOnce() async {
    try {
      final res = await _client.post<Map<String, dynamic>>(
        '/sdkapi/ai/use-once',
        data: {},
      );
      final info = AiQuotaInfo.fromJson(res);
      debugPrint('[AiQuota] 扣减成功: used=${info.used}, limit=${info.limit}, remaining=${info.remaining}');
      return info;
    } catch (e) {
      debugPrint('[AiQuota] ⚠️ 扣减配额失败（不影响功能）: $e');
      return null;
    }
  }

  /// 查询当前用户今日 AI 配额（不扣减）
  Future<AiQuotaInfo?> getQuota() async {
    try {
      final res = await _client.get<Map<String, dynamic>>('/api/user/ai-quota');
      return AiQuotaInfo.fromJson(res);
    } catch (e) {
      debugPrint('[AiQuota] ⚠️ 查询配额失败: $e');
      return null;
    }
  }
}

// ── Providers ─────────────────────────────────────────────
final aiQuotaRepositoryProvider = Provider<AiQuotaRepository>((ref) {
  return AiQuotaRepository(ref.watch(apiClientProvider));
});

/// 当前用户 AI 配额（异步 Provider，用于 UI 展示）
final aiQuotaProvider = FutureProvider<AiQuotaInfo?>((ref) async {
  return ref.read(aiQuotaRepositoryProvider).getQuota();
});
