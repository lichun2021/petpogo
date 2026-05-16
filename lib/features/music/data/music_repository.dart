import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import 'music_models.dart';

class MusicRepository {
  final ApiClient _api;
  MusicRepository(this._api);

  /// GET /sdkapi/music/list — 所有音乐（按分类聚合）
  /// [petType]: 'dog' | 'cat' | null（不传返回全部）
  Future<List<MusicCategory>> fetchAllMusic({String? petType}) async {
    final params = <String, dynamic>{};
    if (petType != null) params['petType'] = petType;
    final data = await _api.get<dynamic>('/sdkapi/music/list', params: params);
    final list = data is List ? data : (data['data'] ?? data['list'] ?? []) as List;
    // 后端可能直接返回分类数组或歌曲数组，适配两种格式
    if (list.isNotEmpty && (list.first as Map).containsKey('songs')) {
      // 分类聚合格式: [{name, songs:[...]}]
      return list.map((c) {
        final map = c as Map<String, dynamic>;
        final songs = (map['songs'] as List? ?? [])
            .map((s) => MusicItem.fromJson(s as Map<String, dynamic>))
            .toList();
        return MusicCategory(name: map['name'] as String? ?? '其他', songs: songs);
      }).toList();
    } else {
      // 平铺格式: [{id, name, category, ...}]
      final items = list
          .map((s) => MusicItem.fromJson(s as Map<String, dynamic>))
          .toList();
      final Map<String, List<MusicItem>> grouped = {};
      for (final item in items) {
        grouped.putIfAbsent(item.category.isEmpty ? '全部' : item.category, () => []).add(item);
      }
      return grouped.entries
          .map((e) => MusicCategory(name: e.key, songs: e.value))
          .toList();
    }
  }

  /// GET /sdkapi/music/playlists — 我的歌单列表 🔒
  Future<List<Playlist>> fetchPlaylists() async {
    final data = await _api.get<dynamic>('/sdkapi/music/playlists');
    final list = data is List ? data : (data['data'] ?? data['list'] ?? []) as List;
    return list.map((e) => Playlist.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// POST /sdkapi/music/playlists — 创建歌单 🔒
  Future<void> createPlaylist({required String name, String? coverUrl}) async {
    await _api.post<dynamic>('/sdkapi/music/playlists', data: {
      'name': name,
      if (coverUrl != null) 'cover_url': coverUrl,
    });
  }

  /// DELETE /sdkapi/music/playlist/[id] — 删除歌单 🔒
  Future<void> deletePlaylist(int id) async {
    await _api.delete('/sdkapi/music/playlist/$id');
  }

  /// POST /sdkapi/music/playlist/[id]/add — 添加歌曲到歌单 🔒
  Future<void> addToPlaylist({required int playlistId, required int musicId}) async {
    await _api.post<dynamic>('/sdkapi/music/playlist/$playlistId/add',
        data: {'music_id': musicId});
  }

  /// DELETE /sdkapi/music/playlist/[id]/item/[musicId] — 移除歌曲 🔒
  Future<void> removeFromPlaylist({required int playlistId, required int musicId}) async {
    await _api.delete('/sdkapi/music/playlist/$playlistId/item/$musicId');
  }
}

final musicRepositoryProvider = Provider<MusicRepository>((ref) {
  return MusicRepository(ref.read(apiClientProvider));
});
