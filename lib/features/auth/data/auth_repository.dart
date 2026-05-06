/// ════════════════════════════════════════════════════════════
///  认证 Repository — 纯业务层
///
///  会话有效期（由服务端驱动，App 侧被动响应）：
///
///  JWT Token (30天)：
///    - 本地永久保存，无需本地计时
///    - 服务端过期返回 401 → _ErrorInterceptor 捕获 → 清 Token
///      → AuthController 切换到 guest 状态 → UI 引导重新登录
///
///  IM UserSig (6天 Redis缓存)：
///    - 本地永久保存，无需本地计时
///    - 腾讯 IM SDK 触发 onUserSigExpired 回调
///      → ImController 调用 refreshImUserSig()
///      → GET /sdkapi/im/sign 获取新的 UserSig → 重新 IM 登录
///      → 不需要用户重新输入验证码
/// ════════════════════════════════════════════════════════════

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/api/result.dart';
import 'models/auth_model.dart';

// ── Storage 键名常量 ─────────────────────────────────────────
const _kToken      = 'auth_token';
const _kId         = 'auth_id';
const _kAccount    = 'auth_account';    // phone
const _kName       = 'auth_name';       // nickname
const _kAvatar     = 'auth_avatar';
const _kMerchantId = 'auth_merchant_id';
const _kImUserSig  = 'auth_im_user_sig';

class AuthRepository {
  final ApiClient _client;
  final FlutterSecureStorage _storage;

  AuthRepository(this._client, this._storage);

  // ── 发送短信验证码 ────────────────────────────────────────
  Future<Result<bool>> sendSms(String phone) async {
    try {
      await _client.post('/sdkapi/auth/sms', data: {'phone': phone});
      return const Success(true);
    } on DioException catch (e) {
      final ex = e.error is ApiException
          ? e.error as ApiException
          : ApiException(message: e.message ?? '网络错误');
      return Failure(ex);
    } catch (e) {
      return Failure(ApiException(message: '发送失败，请重试'));
    }
  }

  // ── 短信验证码登录（不存在则自动注册）───────────────────────
  Future<Result<UserInfo>> loginWithSms({
    required String phone,
    required String code,
  }) async {
    return _doLogin('/sdkapi/auth/login', {'phone': phone, 'code': code});
  }

  // ── 密码登录 ─────────────────────────────────────────────
  Future<Result<UserInfo>> loginWithPwd({
    required String phone,
    required String password,
  }) async {
    return _doLogin('/sdkapi/auth/login-pwd', {'phone': phone, 'password': password});
  }

  // legacy compatibility
  Future<Result<UserInfo>> login({
    required String account,
    required String password,
  }) async {
    return loginWithPwd(phone: account, password: password);
  }

  Future<Result<UserInfo>> _doLogin(String path, Map<String, dynamic> data) async {
    try {
      final res = await _client.post<Map<String, dynamic>>(path, data: data);
      final loginResp = LoginResponse.fromJson(res);
      final user = UserInfo.fromLoginResponse(loginResp);

      _client.setToken(user.token);
      await _persist(user);

      debugPrint('[AuthRepo] ✅ 登录成功: ${user.name} (id=${user.id})');
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

  // ── 刷新 IM UserSig（UserSig 过期时调用，无需重新登录）──────
  /// 调用 GET /sdkapi/im/sign 获取新的 UserSig
  /// 成功后更新本地存储，返回新的 UserSig 字符串
  Future<Result<String>> refreshImUserSig() async {
    try {
      final res = await _client.get<Map<String, dynamic>>('/sdkapi/im/sign');
      final newSig = (res['userSig'] as String?) ?? '';
      if (newSig.isEmpty) {
        return Failure(ApiException(message: '获取 UserSig 失败'));
      }
      // 更新本地存储
      await _storage.write(key: _kImUserSig, value: newSig);
      debugPrint('[AuthRepo] ✅ IM UserSig 已刷新');
      return Success(newSig);
    } on DioException catch (e) {
      final ex = e.error is ApiException
          ? e.error as ApiException
          : ApiException(message: e.message ?? '网络错误');
      debugPrint('[AuthRepo] ✗ 刷新 UserSig 失败: ${ex.message}');
      return Failure(ex);
    } catch (e) {
      return Failure(ApiException(message: '刷新 UserSig 失败'));
    }
  }

  // ── 启动恢复（App 冷启动自动登录）────────────────────────
  /// 从 SecureStorage 读取已保存的 UserInfo
  /// 返回 null → 从未登录过，进入游客模式
  ///
  /// 注意：不做本地过期校验
  ///   - JWT 过期由服务端 401 → _ErrorInterceptor → 清 Token 通知上层
  ///   - UserSig 过期由 IM SDK 回调 → refreshImUserSig()
  Future<UserInfo?> restoreSession() async {
    final token = await _storage.read(key: _kToken);
    if (token == null || token.isEmpty) {
      debugPrint('[AuthRepo] 无已保存会话，进入游客模式');
      return null;
    }

    final user = UserInfo.fromStorageMap({
      'token':      token,
      'id':         await _storage.read(key: _kId),
      'account':    await _storage.read(key: _kAccount),
      'name':       await _storage.read(key: _kName),
      'avatar':     await _storage.read(key: _kAvatar),
      'merchantId': await _storage.read(key: _kMerchantId),
      'imUserSig':  await _storage.read(key: _kImUserSig),
    });

    _client.setToken(user.token);
    debugPrint('[AuthRepo] ✅ 会话恢复: ${user.name} (id=${user.id})');
    return user;
  }

  // ── 退出登录 ────────────────────────────────────────────
  Future<void> logout() async {
    await _storage.deleteAll();
    _client.clearToken();
    debugPrint('[AuthRepo] 已退出登录，Token 已清除');
  }

  // ── 获取最新用户资料（改昵称后刷新）──────────────────────
  Future<UserInfo?> fetchProfile() async {
    try {
      final res = await _client.get<Map<String, dynamic>>('/sdkapi/user/profile');
      final current = await restoreSession();
      if (current == null) return null;
      final updated = current.copyWith(
        name:   (res['nickname'] as String?) ?? current.name,
        avatar: (res['avatar']   as String?) ?? current.avatar,
      );
      await _storage.write(key: _kName,   value: updated.name);
      await _storage.write(key: _kAvatar, value: updated.avatar);
      return updated;
    } catch (_) { return null; }
  }

  // ── 私有：持久化 ─────────────────────────────────────────
  Future<void> _persist(UserInfo user) async {
    await Future.wait([
      _storage.write(key: _kToken,      value: user.token),
      _storage.write(key: _kId,         value: user.id),
      _storage.write(key: _kAccount,    value: user.account),
      _storage.write(key: _kName,       value: user.name),
      _storage.write(key: _kAvatar,     value: user.avatar),
      _storage.write(key: _kMerchantId, value: user.merchantId.toString()),
      _storage.write(key: _kImUserSig,  value: user.imUserSig),
    ]);
    debugPrint('[AuthRepo] 会话已持久化');
  }
}

// ── Riverpod Provider ─────────────────────────────────────
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(apiClientProvider),
    const FlutterSecureStorage(),
  );
});
