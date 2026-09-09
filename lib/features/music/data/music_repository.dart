import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import 'music_models.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/api/result.dart';

class MusicRepository {
  final ApiClient _api;
  MusicRepository(this._api);

  // Result 接口供新版音乐主页使用；原接口保留兼容播放器与分类页。
  Future<Result<List<MusicCategory>>> fetchCatalogResult() =>
      guardResult(() => fetchAllMusic());
  Future<Result<List<Playlist>>> fetchPlaylistsResult() =>
      guardResult(fetchPlaylists);
  Future<Result<void>> createPlaylistResult({required String name}) =>
      guardResult(() => createPlaylist(name: name));

  /// GET /sdkapi/music/list — 所有音乐（按分类聚合）
  /// [petType]: 'dog' | 'cat' | null（不传返回全部）
  ///
  /// 实际 API 返回格式：
  ///   { categories: [{ id, name, iconUrl, sortOrder, music: [{...}] }] }
  Future<List<MusicCategory>> fetchAllMusic({String? petType}) async {
    final params = <String, dynamic>{};
    if (petType != null) params['petType'] = petType;
    final data =
        await _api.get<dynamic>(ApiEndpoints.musicList, params: params);

    // ① 后端返回 { categories: [...] }
    if (data is Map && data['categories'] is List) {
      final cats = data['categories'] as List;
      return cats.map((c) {
        final map = c as Map<String, dynamic>;
        // 分类内歌曲字段名是 music（不是 songs）
        final music = (map['music'] as List? ?? [])
            .map((s) => MusicItem.fromJson(s as Map<String, dynamic>))
            .toList();
        return MusicCategory(
          name: (map['name'] ?? '其他') as String,
          iconUrl: (map['iconUrl'] ?? map['icon_url']) as String?,
          songs: music,
        );
      }).toList();
    }

    // ② 兼容：直接返回分类数组 [{name, songs/music:[...]}]
    final list =
        data is List ? data : (data['data'] ?? data['list'] ?? []) as List;
    if (list.isEmpty) return [];

    final firstItem = list.first as Map;
    if (firstItem.containsKey('songs') || firstItem.containsKey('music')) {
      return list.map((c) {
        final map = c as Map<String, dynamic>;
        final raw = (map['songs'] ?? map['music']) as List? ?? [];
        final music = raw
            .map((s) => MusicItem.fromJson(s as Map<String, dynamic>))
            .toList();
        return MusicCategory(
          name: (map['name'] ?? '其他') as String,
          iconUrl: (map['iconUrl'] ?? map['icon_url']) as String?,
          songs: music,
        );
      }).toList();
    }

    // ③ 平铺格式：[{id, name, category, musicUrl, ...}]
    final items =
        list.map((s) => MusicItem.fromJson(s as Map<String, dynamic>)).toList();
    final grouped = <String, List<MusicItem>>{};
    for (final item in items) {
      grouped
          .putIfAbsent(item.category.isEmpty ? '全部' : item.category, () => [])
          .add(item);
    }
    return grouped.entries
        .map((e) => MusicCategory(name: e.key, songs: e.value))
        .toList();
  }

  /// GET /sdkapi/music/playlists — 我的歌单列表 🔒
  Future<List<Playlist>> fetchPlaylists() async {
    final data = await _api.get<dynamic>(ApiEndpoints.musicPlaylists);
    final list =
        data is List ? data : (data['data'] ?? data['list'] ?? []) as List;
    return list
        .map((e) => Playlist.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /sdkapi/music/playlists — 创建歌单 🔒
  Future<void> createPlaylist({required String name, String? coverUrl}) async {
    await _api.post<dynamic>(ApiEndpoints.musicPlaylists, data: {
      'name': name,
      if (coverUrl != null) 'cover_url': coverUrl,
    });
  }

  /// DELETE /sdkapi/music/playlist/[id] — 删除歌单 🔒
  Future<void> deletePlaylist(int id) async {
    await _api.delete(ApiEndpoints.musicPlaylist(id));
  }

  /// POST /sdkapi/music/playlist/[id]/add — 添加歌曲到歌单 🔒
  Future<void> addToPlaylist(
      {required int playlistId, required int musicId}) async {
    await _api.post<dynamic>(ApiEndpoints.musicPlaylistAdd(playlistId),
        data: {'music_id': musicId});
  }

  /// DELETE /sdkapi/music/playlist/[id]/item/[musicId] — 移除歌曲 🔒
  Future<void> removeFromPlaylist(
      {required int playlistId, required int musicId}) async {
    await _api.delete(ApiEndpoints.musicPlaylistItem(playlistId, musicId));
  }
}

final musicRepositoryProvider = Provider<MusicRepository>((ref) {
  return MusicRepository(ref.read(apiClientProvider));
});
