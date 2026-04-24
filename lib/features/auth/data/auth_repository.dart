/// ════════════════════════════════════════════════════════════
///  认证 Repository — 纯业务层
///
///  职责：
///    ✅ 调用登录接口，解析响应
///    ✅ 把 Token 持久化到 SecureStorage
///    ✅ 启动时从 SecureStorage 恢复 Token（自动登录）
///    ✅ 退出登录时清除本地数据
///    ❌ 不包含 UI 逻辑（由 Controller 负责）
///    ❌ 不知道路由（路由在 Controller 或 View 里处理）
///
///  上下游关系：
///    AuthRepository ← AuthController ← LoginPage / ProfilePage
/// ════════════════════════════════════════════════════════════

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/api/result.dart';
import 'models/auth_model.dart';

// ── Storage 键名常量（统一管理，防止拼写错误）──────────────────
const _kToken      = 'auth_token';
const _kAccount    = 'auth_account';
const _kName       = 'auth_name';
const _kMerchantId = 'auth_merchant_id';

/// 登录接口地址（独立服务器，与主 API 不同）
const _loginUrl = 'http://49.234.39.11:8008/admin/sys/index/login';

class AuthRepository {
  final ApiClient _client;
  final FlutterSecureStorage _storage;

  AuthRepository(this._client, this._storage);

  // ── 登录 ────────────────────────────────────────────────
  /// 调用登录接口，返回 Result<UserInfo>
  ///
  /// 成功后自动：
  ///   1. 把 token 注入 ApiClient（后续请求自动携带）
  ///   2. 持久化 UserInfo 到 SecureStorage（下次启动自动恢复）
  Future<Result<UserInfo>> login({
    required String account,
    required String password,
  }) async {
    try {
      // 登录接口用独立 Dio（BaseURL 不同，且不需要 Auth Token）
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
      ));

      // 开发阶段：完整打印 进/出 参数
      if (kDebugMode) {
        dio.interceptors.add(InterceptorsWrapper(
          onRequest: (options, handler) {
            debugPrint('\n┌─── [登录 API 请求] ──────────────────────────');
            debugPrint('│ ${options.method} ${options.uri}');
            debugPrint('│ Body: ${options.data}');
            debugPrint('└─────────────────────────────────────────────');
            handler.next(options);
          },
          onResponse: (response, handler) {
            debugPrint('\n┌─── [登录 API 响应] ──────────────────────────');
            debugPrint('│ ${response.statusCode} ${response.requestOptions.uri}');
            debugPrint('│ Body: ${response.data}');
            debugPrint('└─────────────────────────────────────────────');
            handler.next(response);
          },
          onError: (err, handler) {
            debugPrint('\n┌─── [登录 API 错误] ──────────────────────────');
            debugPrint('│ ${err.requestOptions.method} ${err.requestOptions.uri}');
            debugPrint('│ Status: ${err.response?.statusCode}');
            debugPrint('│ Body: ${err.response?.data}');
            debugPrint('│ Msg: ${err.message}');
            debugPrint('└─────────────────────────────────────────────');
            handler.next(err);
          },
        ));
      }

      final res = await dio.post(
        _loginUrl,
        data: FormData.fromMap({
          'account':  account,
          'password': password,
        }),
      );

      final body = res.data as Map<String, dynamic>;
      debugPrint('[AuthRepo] ← code=${body['code']} msg=${body['msg']}');

      // 服务端 code != 0 表示业务错误（如密码错误）
      if (body['code'] != 0) {
        return Failure(ApiException(
          message: (body['msg'] as String?) ?? '登录失败',
        ));
      }

      final loginResp = LoginResponse.fromJson(body);
      final user = UserInfo.fromLoginResponse(loginResp);

      // ① 注入 token 到 ApiClient（后续所有请求自动携带）
      _client.setToken(user.token);

      // ② 持久化到安全存储
      await _persist(user);

      debugPrint('[AuthRepo] ✅ 登录成功: ${user.name} (${user.account})');
      return Success(user);
    } on DioException catch (e) {
      final ex = e.error is ApiException
          ? e.error as ApiException
          : ApiException(message: e.message ?? '网络错误');
      debugPrint('[AuthRepo] ✗ 登录失败: ${ex.message}');
      return Failure(ex);
    } catch (e) {
      debugPrint('[AuthRepo] ✗ 意外错误: $e');
      return Failure(ApiException(message: '登录异常，请重试'));
    }
  }

  // ── 启动恢复（自动登录）───────────────────────────────────
  /// App 启动时从 SecureStorage 读取已保存的 UserInfo
  ///
  /// 返回 null 表示未登录（游客状态）
  Future<UserInfo?> restoreSession() async {
    final token = await _storage.read(key: _kToken);
    if (token == null || token.isEmpty) {
      debugPrint('[AuthRepo] 无已保存会话，进入游客模式');
      return null;
    }

    final user = UserInfo.fromStorageMap({
      'token':      token,
      'account':    await _storage.read(key: _kAccount),
      'name':       await _storage.read(key: _kName),
      'merchantId': await _storage.read(key: _kMerchantId),
    });

    // 恢复 token 到 ApiClient
    _client.setToken(user.token);
    debugPrint('[AuthRepo] ✅ 会话恢复: ${user.name}');
    return user;
  }

  // ── 退出登录 ────────────────────────────────────────────
  /// 清除本地 Token + ApiClient Token
  Future<void> logout() async {
    await _storage.deleteAll();
    _client.clearToken();
    debugPrint('[AuthRepo] 已退出登录，Token 已清除');
  }

  // ── 私有：持久化 ─────────────────────────────────────────
  Future<void> _persist(UserInfo user) async {
    await Future.wait([
      _storage.write(key: _kToken,      value: user.token),
      _storage.write(key: _kAccount,    value: user.account),
      _storage.write(key: _kName,       value: user.name),
      _storage.write(key: _kMerchantId, value: user.merchantId.toString()),
    ]);
  }
}

// ── Riverpod Provider ─────────────────────────────────────
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.read(apiClientProvider),
    const FlutterSecureStorage(),
  );
});
