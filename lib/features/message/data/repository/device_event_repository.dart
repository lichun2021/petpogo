import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';
import '../models/device_event_model.dart';

/// 设备事件 Repository
///
/// 数据源：业务后端 /sdkapi/device-event/*（后端已就绪）
/// 架构：PeerApi(事件源) → 业务后端(落库+推送) → App(本 repository 查询)
/// App 不直接调 PeerApi 拿事件历史（详见 change design.md 决策 2）。
class DeviceEventRepository {
  final ApiClient _client;
  DeviceEventRepository(this._client);

  /// 统一响应解包（兼容 {code, info, tip} 包装与直接数据对象）
  Map<String, dynamic> _unwrap(Map<String, dynamic> data) {
    if (!data.containsKey('code')) return data;
    final rawCode = data['code'];
    final code = rawCode is num ? rawCode.toInt() : int.tryParse('$rawCode') ?? 0;
    if (code != 0) {
      // 抛出由调用方 try/catch 处理（result.when failure）
      throw Exception(data['tip']?.toString().trim() ?? '请求失败');
    }
    final info = data['info'];
    if (info is Map) return info.cast<String, dynamic>();
    return const {};
  }

  /// 获取设备事件历史列表（分页）
  /// GET /sdkapi/device-event/list?type=&page=&page_size=
  Future<List<DeviceEvent>> fetchEvents({
    String? type,
    int page = 1,
    int pageSize = 20,
  }) async {
    final res = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.deviceEventList,
      params: {
        if (type != null) 'type': type,
        'page': page,
        'page_size': pageSize,
      },
    );
    final data = _unwrap(res);
    final list = data['list'] as List<dynamic>? ?? const [];
    return list
        .whereType<Map>()
        .map((e) => DeviceEvent.fromJson(e.cast<String, dynamic>()))
        .toList(growable: false);
  }

  /// 标记单条事件已读
  /// POST /sdkapi/device-event/read  body: { event_id }
  Future<void> markRead(String eventId) async {
    await _client.post<Map<String, dynamic>>(
      ApiEndpoints.deviceEventRead,
      data: {'event_id': eventId},
    );
  }

  /// 标记当前用户全部未读事件为已读
  /// POST /sdkapi/device-event/read-all  body: {}
  /// 返回 affected count
  Future<int> markAllRead() async {
    final res = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.deviceEventReadAll,
      data: const {},
    );
    final data = _unwrap(res);
    final count = data['count'];
    if (count is int) return count;
    if (count is num) return count.toInt();
    return 0;
  }
}

final deviceEventRepositoryProvider = Provider<DeviceEventRepository>((ref) {
  return DeviceEventRepository(ref.watch(apiClientProvider));
});
