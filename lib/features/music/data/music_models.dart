// ── 宠物音乐 数据模型 ─────────────────────────────────────

class MusicItem {
  final int    id;
  final String name;
  final String url;
  final String category;
  final String? iconUrl;
  final String? artist;
  final int?   duration; // 秒

  const MusicItem({
    required this.id,
    required this.name,
    required this.url,
    required this.category,
    this.iconUrl,
    this.artist,
    this.duration,
  });

  factory MusicItem.fromJson(Map<String, dynamic> j) => MusicItem(
    id:       j['id'] as int,
    name:     (j['name'] ?? j['title'] ?? '') as String,
    url:      (j['url'] ?? j['audio_url'] ?? '') as String,
    category: (j['category'] ?? j['category_name'] ?? '') as String,
    iconUrl:  j['icon_url'] as String?,
    artist:   j['artist'] as String?,
    duration: j['duration'] as int?,
  );

  String get durationText {
    if (duration == null) return '';
    final m = duration! ~/ 60;
    final s = duration! % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

class MusicCategory {
  final String           name;
  final List<MusicItem>  songs;
  const MusicCategory({required this.name, required this.songs});
}

class Playlist {
  final int    id;
  final String name;
  final String? coverUrl;
  final int    songCount;

  const Playlist({
    required this.id,
    required this.name,
    this.coverUrl,
    required this.songCount,
  });

  factory Playlist.fromJson(Map<String, dynamic> j) => Playlist(
    id:        j['id'] as int,
    name:      (j['name'] ?? '') as String,
    coverUrl:  j['cover_url'] as String?,
    songCount: (j['song_count'] ?? j['music_count'] ?? 0) as int,
  );
}
