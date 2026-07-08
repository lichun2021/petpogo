// ════════════════════════════════════════════════════════════
//  积分 / 会员 / 签到 Repository
//
//  所有接口走业务后端 ApiClient（/sdkapi/*），响应统一为
//  {code:int, info:object|null, tip:string}。code==0 取 info，
//  code!=0 抛 ApiException。
//
//  对应接口契约见 lib/features/profile/*_page.dart 顶部注释。
// ════════════════════════════════════════════════════════════
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/api/api_exception.dart';

class PointsRepository {
  final ApiClient _client;
  PointsRepository(this._client);

  /// 统一响应解包
  /// {code, info, tip} → code==0 返回 info，否则抛 ApiException
  /// 若 info 不是 Map（可能为 null），返回空 Map
  Map<String, dynamic> _unwrap(Map<String, dynamic> data) {
    final code = data['code'] as int? ?? 0;
    if (code != 0) {
      final tip = (data['tip'] as String?) ?? '请求失败';
      throw ApiException(message: tip, type: ApiErrorType.server);
    }
    final info = data['info'];
    if (info is Map) return info.cast<String, dynamic>();
    return const {};
  }

  /// 保留原始响应（不抛异常），用于需要判断特定业务码的场景
  /// 例如 makeup 的 402 配额用尽
  Map<String, dynamic> _unwrapRaw(Map<String, dynamic> data) => data;

  // ── 积分 ────────────────────────────────────────────────

  /// GET /sdkapi/points/balance → { weekly, permanent, total }
  Future<Map<String, dynamic>> fetchBalance() async {
    final res = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.pointsBalance,
    );
    return _unwrap(res);
  }

  /// GET /sdkapi/points/list?page=&limit= → { list:[...], page, limit }
  Future<List<Map<String, dynamic>>> fetchTransactions({
    int page = 1,
    int limit = 20,
  }) async {
    final res = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.pointsList,
      params: {'page': page, 'limit': limit},
    );
    final info = _unwrap(res);
    final list = info['list'] as List<dynamic>? ?? const [];
    return list
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList(growable: false);
  }

  /// GET /sdkapi/points/rules → { list:[{consume_type,name,unit_points,unit_basis}] }
  Future<List<Map<String, dynamic>>> fetchRules() async {
    final res = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.pointsRules,
    );
    final info = _unwrap(res);
    final list = info['list'] as List<dynamic>? ?? const [];
    return list
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList(growable: false);
  }

  // ── 购买计划（会员）──────────────────────────────────────

  /// GET /sdkapi/plan/list → { list:[{id,plan_type,name,price,duration_days,...}] }
  Future<List<Map<String, dynamic>>> fetchPlans() async {
    final res = await _client.get<Map<String, dynamic>>(ApiEndpoints.planList);
    final info = _unwrap(res);
    final list = info['list'] as List<dynamic>? ?? const [];
    return list
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList(growable: false);
  }

  /// POST /sdkapi/plan/order { planId } → { orderId, planId, amount, status }
  Future<Map<String, dynamic>> createOrder({required String planId}) async {
    final res = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.planOrder,
      data: {'planId': planId},
    );
    return _unwrap(res);
  }

  /// GET /sdkapi/plan/order/:orderId → { orderId, planId, planName, amount, status, createdAt, paidAt }
  /// status: 0=待支付 1=已支付 2=已取消
  Future<Map<String, dynamic>> fetchOrder(String orderId) async {
    final res = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.planOrderDetail(orderId),
    );
    return _unwrap(res);
  }

  // ── 签到 ────────────────────────────────────────────────

  /// GET /sdkapi/checkin/calendar?month=YYYY-MM
  /// → { month, calendar:[...], currentStreak, signedInToday, monthlyMakeupQuota,
  ///     usedMakeupCount, remainingMakeupQuota, rewardButtons:[...] }
  Future<Map<String, dynamic>> fetchCalendar({String? month}) async {
    final params = <String, dynamic>{};
    if (month != null && month.isNotEmpty) params['month'] = month;
    final res = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.checkInCalendar,
      params: params.isEmpty ? null : params,
    );
    return _unwrap(res);
  }

  /// GET /sdkapi/checkin/status → { today, signedInToday, currentStreak, rules:[...] }
  Future<Map<String, dynamic>> fetchStatus() async {
    final res = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.checkInStatus,
    );
    return _unwrap(res);
  }

  /// POST /sdkapi/checkin/signin → { checkinDate, streakCount }
  Future<Map<String, dynamic>> signIn() async {
    final res = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.checkInSignIn,
    );
    return _unwrap(res);
  }

  /// POST /sdkapi/checkin/claim { ruleId }
  /// → { success, pointsAmount, pointsType, balance }
  Future<Map<String, dynamic>> claim({required String ruleId}) async {
    final res = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.checkInClaim,
      data: {'ruleId': ruleId},
    );
    return _unwrap(res);
  }

  /// POST /sdkapi/checkin/makeup { date }
  /// → { success, date, streakCount, usedMakeupCount, remainingQuota }
  ///
  /// 错误：
  ///   400 — date 格式无效 / 只能补过去 3 天 / 已签到
  ///   402 — 本月配额用尽（前端引导看广告）
  ///
  /// 抛出 ApiException（含 statusCode），调用方按 statusCode 判断。
  Future<Map<String, dynamic>> makeup({required String date}) async {
    try {
      final res = await _client.post<Map<String, dynamic>>(
        ApiEndpoints.checkInMakeup,
        data: {'date': date},
      );
      return _unwrap(res);
    } on ApiException {
      rethrow;
    } catch (e) {
      // DioException 经 _ErrorInterceptor 转 ApiException，含 statusCode
      throw ApiException(message: '补签失败，请重试');
    }
  }
}

final pointsRepositoryProvider = Provider<PointsRepository>((ref) {
  return PointsRepository(ref.watch(apiClientProvider));
});
