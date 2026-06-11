/// 自动打招呼页 — 配置（声音+计划）+ 媒体库
/// 录音最长 10 秒，长按录制，松手结束
library;

import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_fonts.dart';

import '../../shared/utils/oss_uploader.dart';
import '../../shared/widgets/pet_toast.dart';
import 'data/models/capture_model.dart';
import 'data/repository/capture_repository.dart';
import 'widgets/ai_emotion_card.dart';

String _soundDisplayName(SoundPreset sound) =>
    sound.isUserCustom ? '自录音' : sound.name;

String _fmtDurationText(Duration duration) {
  final totalSeconds = duration.inSeconds < 0 ? 0 : duration.inSeconds;
  final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
  final s = (totalSeconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

// ──────────────────────────────────────────────────────────────
class RobotAiGreetingPage extends ConsumerStatefulWidget {
  final String mac;
  final String deviceName;

  const RobotAiGreetingPage({
    super.key,
    required this.mac,
    required this.deviceName,
  });

  @override
  ConsumerState<RobotAiGreetingPage> createState() =>
      _RobotAiGreetingPageState();
}

class _RobotAiGreetingPageState extends ConsumerState<RobotAiGreetingPage> {
  int _selectedPetIndex = 0; // cat / dog
  final _petTypes = const ['cat', 'dog'];
  final _petLabels = const ['猫叫声', '狗叫声'];
  static const Map<String, String> _emotionDisplayNames = {
    'happy': '开心',
    'alert': '警觉',
    'angry': '愤怒',
    'anticipation': '期待',
    'anxiety': '焦虑',
    'appeasement': '安抚',
    'calm': '平静',
    'caution': '谨慎',
    'confident': '自信',
    'curiosity': '好奇',
    'excited': '兴奋',
    'fear': '恐惧',
    'sad': '悲伤',
    'relaxed': '放松',
    'relax': '放松',
    'neutral': '平静',
  };

  // ── 当前每种情绪已选的声音（per petType）────────────────
  // key: 'cat_happy' → SoundPreset?
  final Map<String, SoundPreset?> _selectedSounds = {};
  final Map<String, int> _selectedSoundIds = {};

  // ── 声音列表（从服务器加载）──────────────────────────────
  final Map<String, List<SoundPreset>> _soundsByPetType = {
    'cat': <SoundPreset>[],
    'dog': <SoundPreset>[],
  };
  bool _soundLoading = false;
  bool _soundExpanded = false;

  // ── 计划配置 ─────────────────────────────────────────────
  bool _enabled = false;
  TimeOfDay _startTime = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 18, minute: 0);
  Set<int> _weekdays = {1, 2, 3, 4, 5, 6, 7};
  int _count = 3; // 时间段内触发次数

  // ── 媒体库 ───────────────────────────────────────────────
  final List<GreetingItem> _items = [];
  bool _loading = false;
  bool _hasMore = true;
  int _page = 1;
  final ScrollController _scroll = ScrollController();

  // ── 音频播放（试听预设）──────────────────────────────────
  final AudioPlayer _previewPlayer = AudioPlayer();
  String? _playingUrl;

  String get _prefKey => 'robot_ai_greeting_${widget.mac}';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _loadSounds(); // 进页面并行拉一次猫 + 狗，后续切换只读缓存
    _loadMedia(reset: true);
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _previewPlayer.dispose();
    super.dispose();
  }

  // ── 加载配置 ─────────────────────────────────────────────
  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey);
    if (raw == null) return;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      setState(() {
        _enabled = m['enabled'] == true;
        _startTime = _parseTime(m['start'] ?? '10:00');
        _endTime = _parseTime(m['end'] ?? '18:00');
        _weekdays = ((m['weekdays'] as List?) ?? [1, 2, 3, 4, 5, 6, 7])
            .map((e) => e as int)
            .toSet();
        _count = (m['count'] as int?) ?? 3;
        // 恢复已选声音（只保存 id + emotion + petType）
        final sel = (m['sounds'] as Map<String, dynamic>?) ?? {};
        sel.forEach((k, v) {
          final id = int.tryParse(v?.toString() ?? '');
          if (id != null) {
            _selectedSoundIds[k] = id;
            _selectedSounds[k] = null; // 声音在列表加载后再匹配
          }
        });
        _resolveSelectedSounds();
      });
    } catch (_) {}
  }

  TimeOfDay _parseTime(String s) {
    final p = s.split(':');
    return TimeOfDay(
        hour: int.tryParse(p[0]) ?? 10,
        minute: int.tryParse(p.length > 1 ? p[1] : '0') ?? 0);
  }

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  // ── 加载声音列表（进页面一次拉猫 + 狗）────────────────────
  Future<void> _loadSounds() async {
    setState(() => _soundLoading = true);
    try {
      final repo = ref.read(captureRepositoryProvider);
      final results = await Future.wait([
        repo.fetchSoundList(petType: 'cat', pageSize: 100),
        repo.fetchSoundList(petType: 'dog', pageSize: 100),
      ]);
      if (mounted) {
        setState(() {
          _soundsByPetType['cat'] = _dedupeSounds(results[0]);
          _soundsByPetType['dog'] = _dedupeSounds(results[1]);
          _resolveSelectedSounds();
        });
      }
    } catch (_) {
      if (mounted) PetToast.error(context, '声音列表加载失败');
    } finally {
      if (mounted) setState(() => _soundLoading = false);
    }
  }

  List<SoundPreset> _dedupeSounds(List<SoundPreset> sounds) {
    final seen = <int>{};
    return sounds.where((s) => seen.add(s.id)).toList();
  }

  List<SoundPreset> _soundsForPet(String petType) =>
      _soundsByPetType[petType] ?? const <SoundPreset>[];

  // 返回 (emotion_key, 中文显示名) 列表，去重保序
  List<(String, String)> _emotionPairsForPet(String petType) {
    final seen = <String>{};
    final pairs = <(String, String)>[];
    for (final sound in _soundsForPet(petType)) {
      if (sound.petType != petType && sound.petType.isNotEmpty) continue;
      if (!seen.add(sound.emotion)) continue;
      pairs
          .add((sound.emotion, _displayNameForEmotion(petType, sound.emotion)));
    }
    return pairs;
  }

  // 兼容旧调用：仅返回 emotion key 列表
  List<String> _emotionLabelsForPet(String petType) =>
      _emotionPairsForPet(petType).map((p) => p.$1).toList();

  void _resolveSelectedSounds() {
    for (final entry in _selectedSoundIds.entries) {
      final splitIndex = entry.key.indexOf('_');
      if (splitIndex <= 0) continue;
      final petType = entry.key.substring(0, splitIndex);
      SoundPreset? matched;
      for (final sound in _soundsForPet(petType)) {
        if (sound.id == entry.value) {
          matched = sound;
          break;
        }
      }
      _selectedSounds[entry.key] = matched;
    }
    _selectDefaultUserSounds();
  }

  String _displayNameForEmotion(String petType, String emotion) {
    final mapped = _emotionDisplayNames[emotion];
    if (mapped != null) return mapped;
    for (final sound in _soundsForPet(petType)) {
      if (sound.emotion == emotion && !sound.isUserCustom) return sound.name;
    }
    return emotion;
  }

  SoundPreset? _defaultUserSoundFor(String petType, String emotion) {
    for (final sound in _soundsForPet(petType)) {
      if (sound.emotion == emotion && sound.isUserCustom) return sound;
    }
    return null;
  }

  SoundPreset? _visibleSoundFor(String petType, String emotion) {
    final key = '${petType}_$emotion';
    return _selectedSounds[key] ?? _defaultUserSoundFor(petType, emotion);
  }

  void _selectDefaultUserSounds() {
    for (final petType in _petTypes) {
      for (final sound in _soundsForPet(petType)) {
        if (!sound.isUserCustom) continue;
        final key = '${petType}_${sound.emotion}';
        if (_selectedSoundIds.containsKey(key)) continue;
        _selectedSoundIds[key] = sound.id;
        _selectedSounds[key] = sound;
      }
    }
  }

  // ── 加载媒体库 ────────────────────────────────────────────
  Future<void> _loadMedia({bool reset = false}) async {
    if (_loading) return;
    if (reset) {
      _page = 1;
      _hasMore = true;
      _items.clear();
    }
    setState(() => _loading = true);
    try {
      final res = await ref.read(captureRepositoryProvider).fetchGreetingList(
            deviceId: widget.mac,
            page: _page,
          );
      setState(() {
        _items.addAll(res.list);
        _hasMore = res.hasMore;
        _page++;
      });
    } catch (_) {
      if (mounted) PetToast.error(context, '记录加载失败');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loading) return;
    await _loadMedia();
  }

  // ── 保存配置 ─────────────────────────────────────────────
  Future<void> _persistPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final soundMap = <String, int?>{};
      _selectedSoundIds.forEach((k, v) => soundMap[k] = v);
      _selectedSounds.forEach((k, v) {
        if (v != null) soundMap[k] = v.id;
      });
      await prefs.setString(
          _prefKey,
          jsonEncode({
            'enabled': _enabled,
            'start': _fmtTime(_startTime),
            'end': _fmtTime(_endTime),
            'weekdays': _weekdays.toList()..sort(),
            'count': _count,
            'sounds': soundMap,
          }));
    } catch (_) {
      if (mounted) PetToast.error(context, '保存失败');
    }
  }

  // ── 试听声音 ─────────────────────────────────────────────
  Future<void> _playPreview(String url) async {
    if (_playingUrl == url) {
      await _previewPlayer.stop();
      setState(() => _playingUrl = null);
      return;
    }
    setState(() => _playingUrl = url);
    try {
      await _previewPlayer.setUrl(url);
      await _previewPlayer.play();
      _previewPlayer.playerStateStream.listen((s) {
        if (s.processingState == ProcessingState.completed) {
          if (mounted) setState(() => _playingUrl = null);
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() => _playingUrl = null);
        PetToast.error(context, '试听失败');
      }
    }
  }

  // ── 声音选择底部弹窗 ──────────────────────────────────────
  void _showSoundPicker(String petType, String emotionLabel) {
    final key = '${petType}_$emotionLabel';
    final filtered = _soundsForPet(petType)
        .where((s) =>
            (s.petType == petType || s.petType.isEmpty) &&
            s.emotion == emotionLabel)
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SoundPickerSheet(
        petType: petType,
        emotionLabel: emotionLabel,
        sounds: filtered,
        selectedId: _selectedSounds[key]?.id,
        onSelect: (s) {
          setState(() {
            _selectedSounds[key] = s;
            _selectedSoundIds[key] = s.id;
          });
          unawaited(_persistPrefs());
          Navigator.pop(context);
        },
        onDeleteUser: (id) async {
          try {
            await ref.read(captureRepositoryProvider).deleteUserSound(id);
            setState(() {
              _selectedSoundIds.removeWhere((_, value) => value == id);
              _selectedSounds.removeWhere((_, value) => value?.id == id);
            });
            await _loadSounds();
            await _persistPrefs();
            if (mounted) Navigator.pop(context);
          } catch (_) {
            if (mounted) PetToast.error(context, '删除失败');
          }
        },
        onRecordDone: (sound) {
          setState(() {
            _soundsByPetType[petType] = [..._soundsForPet(petType), sound];
            _selectedSounds[key] = sound;
            _selectedSoundIds[key] = sound.id;
          });
          unawaited(_persistPrefs());
        },
        repo: ref.read(captureRepositoryProvider),
        uploader: ref.read(ossUploaderProvider),
      ),
    );
  }

  // ── 时间选择 ─────────────────────────────────────────────
  Future<void> _pickTime(bool isStart) async {
    final t = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: ColorScheme.light(primary: AppColors.primary)),
        child: child!,
      ),
    );
    if (t != null) {
      setState(() => isStart ? _startTime = t : _endTime = t);
      await _persistPrefs();
    }
  }

  // ── 构建 ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8F6),
      body: Column(children: [
        _buildHeader(),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => _loadMedia(reset: true),
            child: CustomScrollView(
              controller: _scroll,
              slivers: [
                // ── 配置卡片 ──
                SliverToBoxAdapter(child: _buildConfigCard()),
                // ── 媒体库标题 ──
                SliverToBoxAdapter(child: _buildMediaHeader()),
                // ── 媒体列表 ──
                _buildMediaList(),
                if (_hasMore)
                  SliverToBoxAdapter(
                      child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.primary)),
                  )),
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Icon(Icons.arrow_back_ios_rounded,
                  size: 20, color: AppColors.onPrimary),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('自动打招呼',
                  style: TextStyle(
                      fontFamily: AppFonts.primary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.onPrimary)),
              Text(widget.deviceName,
                  style: TextStyle(
                      fontFamily: AppFonts.primary,
                      fontSize: 12,
                      color: AppColors.onPrimary.withValues(alpha: 0.7))),
            ]),
          ]),
        ),
      ),
    );
  }

  // ── 配置卡片 ─────────────────────────────────────────────
  Widget _buildConfigCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildTapRow(
          icon: Icons.schedule_rounded,
          label: '生效时间',
          value: '${_fmtTime(_startTime)} ~ ${_fmtTime(_endTime)}',
          onTap: () async {
            await _pickTime(true);
            if (mounted) await _pickTime(false);
          },
        ),
        const Divider(height: 1, indent: 20, endIndent: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(children: [
            Icon(Icons.repeat_rounded, size: 20, color: AppColors.primary),
            const SizedBox(width: 12),
            Text('重复',
                style: TextStyle(
                    fontFamily: AppFonts.primary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            const Spacer(),
            _buildWeekdayPicker(),
          ]),
        ),
        const Divider(height: 1, indent: 20, endIndent: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(children: [
            Icon(Icons.repeat_one_rounded, size: 20, color: AppColors.primary),
            const SizedBox(width: 12),
            Text('AI分析次数/天',
                style: TextStyle(
                    fontFamily: AppFonts.primary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            const Spacer(),
            _CountPickerButton(
              value: _count.clamp(1, 9),
              onTap: _pickCount,
            ),
          ]),
        ),
        const Divider(height: 1, indent: 20, endIndent: 20),
        _buildSoundSettingsHeader(),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: _soundExpanded
              ? Column(children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                    child: _buildPetTab(),
                  ),
                  _soundLoading
                      ? Padding(
                          padding: const EdgeInsets.all(20),
                          child: Center(
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.primary)),
                        )
                      : _buildSoundList(),
                  const Divider(height: 1, indent: 20, endIndent: 20),
                ])
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: 6),
      ]),
    );
  }

  Widget _buildSoundSettingsHeader() {
    final currentPetType = _petTypes[_selectedPetIndex];
    final currentCount = _emotionLabelsForPet(currentPetType).length;
    final catCount = _emotionLabelsForPet('cat').length;
    final dogCount = _emotionLabelsForPet('dog').length;
    final subtitle = _soundLoading
        ? '正在加载猫狗声音...'
        : _soundExpanded
            ? '${_petLabels[_selectedPetIndex]} $currentCount 个标签'
            : '猫 $catCount 个，狗 $dogCount 个';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _soundExpanded = !_soundExpanded);
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.secondaryContainer.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.graphic_eq_rounded,
                  size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('声音设置',
                      style: TextStyle(
                          fontFamily: AppFonts.primary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.onSurface)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          fontFamily: AppFonts.primary,
                          fontSize: 12,
                          color: AppColors.onSurfaceVariant)),
                ],
              ),
            ),
            _soundLoading && !_soundExpanded
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary),
                  )
                : AnimatedRotation(
                    duration: const Duration(milliseconds: 180),
                    turns: _soundExpanded ? 0.5 : 0,
                    child: Icon(Icons.keyboard_arrow_down_rounded,
                        size: 24, color: AppColors.primary),
                  ),
          ]),
        ),
      ),
    );
  }

  Future<void> _pickCount() async {
    HapticFeedback.selectionClick();
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _CountPickerSheet(initialValue: _count.clamp(1, 9)),
    );
    if (picked != null && mounted) {
      setState(() => _count = picked);
      await _persistPrefs();
    }
  }

  // ── 宠物 Tab ─────────────────────────────────────────────
  Widget _buildPetTab() {
    final tabTexts = List.generate(_petTypes.length, (i) {
      final count = _emotionLabelsForPet(_petTypes[i]).length;
      return '${_petLabels[i]} $count';
    });

    return Container(
      height: 42,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: List.generate(_petTypes.length, (i) {
          final selected = _selectedPetIndex == i;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (_selectedPetIndex == i) return;
                HapticFeedback.selectionClick();
                setState(() => _selectedPetIndex = i);
              },
              child: Container(
                height: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  tabTexts[i],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : Colors.grey.shade600,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── 情绪→声音列表（动态，按当前 petType 从接口数据提取）─────
  Widget _buildSoundList() {
    final petType = _petTypes[_selectedPetIndex];
    final emotionPairs = _emotionPairsForPet(petType); // [(emotion_key, 中文名)]

    if (emotionPairs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text('暂无声音数据',
              style: TextStyle(
                  fontFamily: AppFonts.primary,
                  fontSize: 13,
                  color: Colors.grey.shade500)),
        ),
      );
    }

    return Column(
      children: emotionPairs.map((pair) {
        final emotionKey = pair.$1; // 英文 key（用于匹配/存储）
        final displayName = pair.$2; // 中文显示名
        final sound = _visibleSoundFor(petType, emotionKey);
        return Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(children: [
              // 情绪图标
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.music_note_rounded,
                    size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              // 情绪名（中文） + 声音名
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(displayName, // 中文名如“警觉”“愿怒”
                          style: TextStyle(
                              fontFamily: AppFonts.primary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                      if (sound != null)
                        Text(_soundDisplayName(sound),
                            style: TextStyle(
                                fontFamily: AppFonts.primary,
                                fontSize: 12,
                                color: Colors.grey.shade500)),
                    ]),
              ),
              // 试听按钮
              if (sound != null)
                GestureDetector(
                  onTap: () => _playPreview(sound.url),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _playingUrl == sound.url
                          ? Icons.stop_rounded
                          : Icons.play_arrow_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              // 编辑声音
              GestureDetector(
                onTap: () => _showSoundPicker(petType, emotionKey),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.edit_rounded,
                      size: 17, color: AppColors.primary),
                ),
              ),
            ]),
          ),
          const Divider(height: 1, indent: 68, endIndent: 20),
        ]);
      }).toList(),
    );
  }

  Widget _buildWeekdayPicker() {
    const labels = ['一', '二', '三', '四', '五', '六', '日'];
    return Row(
        children: List.generate(7, (i) {
      final day = i + 1;
      final sel = _weekdays.contains(day);
      return GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            if (sel && _weekdays.length > 1) {
              _weekdays.remove(day);
            } else {
              _weekdays.add(day);
            }
          });
          unawaited(_persistPrefs());
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 26,
          height: 26,
          margin: const EdgeInsets.only(left: 4),
          decoration: BoxDecoration(
            color: sel ? AppColors.primary : Colors.grey.shade100,
            shape: BoxShape.circle,
          ),
          child: Center(
              child: Text(labels[i],
                  style: TextStyle(
                      fontFamily: AppFonts.primary,
                      fontSize: 9,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                      color: sel ? Colors.white : Colors.grey.shade600))),
        ),
      );
    }));
  }

  Widget _buildTapRow({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Text(label,
              style: TextStyle(
                  fontFamily: AppFonts.primary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  fontFamily: AppFonts.primary,
                  fontSize: 14,
                  color: Colors.grey.shade600)),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded,
              size: 18, color: Colors.grey.shade400),
        ]),
      ),
    );
  }

  // ── 媒体库标题 ────────────────────────────────────────────
  Widget _buildMediaHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Row(children: [
        Text('打招呼记录',
            style: TextStyle(
                fontFamily: AppFonts.primary,
                fontSize: 17,
                fontWeight: FontWeight.w800)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('${_items.length}',
              style: TextStyle(
                  fontFamily: AppFonts.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary)),
        ),
      ]),
    );
  }

  // ── 媒体列表（列表式）────────────────────────────────────
  Widget _buildMediaList() {
    if (_loading && _items.isEmpty) {
      return SliverToBoxAdapter(
          child: Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.primary)),
      ));
    }
    if (_items.isEmpty) {
      return SliverToBoxAdapter(
          child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(children: [
          const Text('👋', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text('暂无打招呼记录',
              style: TextStyle(
                  fontFamily: AppFonts.primary,
                  fontSize: 15,
                  color: Colors.grey.shade500)),
          const SizedBox(height: 4),
          Text('开启自动打招呼后，记录将显示在这里',
              style: TextStyle(
                  fontFamily: AppFonts.primary,
                  fontSize: 12,
                  color: Colors.grey.shade400)),
        ]),
      ));
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (ctx, i) => _GreetingCell(
            item: _items[i],
            onTap: () => _openDetail(_items[i]),
          ),
          childCount: _items.length,
        ),
      ),
    );
  }

  void _openDetail(GreetingItem item) {
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _GreetingDetailPage(item: item),
        ));
  }
}

class _CountPickerButton extends StatelessWidget {
  final int value;
  final VoidCallback onTap;

  const _CountPickerButton({
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 7, 10, 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$value 次',
                style: TextStyle(
                  fontFamily: AppFonts.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountPickerSheet extends StatefulWidget {
  final int initialValue;

  const _CountPickerSheet({required this.initialValue});

  @override
  State<_CountPickerSheet> createState() => _CountPickerSheetState();
}

class _CountPickerSheetState extends State<_CountPickerSheet> {
  late int _selected;
  late final FixedExtentScrollController _controller;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialValue.clamp(1, 9);
    _controller = FixedExtentScrollController(initialItem: _selected - 1);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 24,
              spreadRadius: -8,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outlineVariant.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Text(
                  'AI 分析次数',
                  style: TextStyle(
                    fontFamily: AppFonts.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onSurface,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context, _selected),
                  child: Text(
                    '完成',
                    style: TextStyle(
                      fontFamily: AppFonts.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(
              height: 180,
              child: CupertinoPicker(
                scrollController: _controller,
                itemExtent: 42,
                useMagnifier: true,
                magnification: 1.08,
                squeeze: 1.08,
                backgroundColor: Colors.transparent,
                selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
                  background: AppColors.primary.withValues(alpha: 0.06),
                ),
                onSelectedItemChanged: (index) {
                  HapticFeedback.selectionClick();
                  setState(() => _selected = index + 1);
                },
                children: List.generate(
                  9,
                  (index) => Center(
                    child: Text(
                      '${index + 1} 次',
                      style: TextStyle(
                        fontFamily: AppFonts.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 打招呼记录格子（列表式）──────────────────────────────────
class _GreetingCell extends StatelessWidget {
  final GreetingItem item;
  final VoidCallback onTap;
  const _GreetingCell({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final top = item.aiResult?.top;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(children: [
          // 封面图
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 64,
              height: 64,
              child: item.coverUrl.isNotEmpty || item.responseUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: item.coverUrl.isNotEmpty
                          ? item.coverUrl
                          : item.responseUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.pets_rounded,
                              color: Colors.grey, size: 28)),
                    )
                  : Container(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      child: const Center(
                          child: Text('👋', style: TextStyle(fontSize: 28)))),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (top != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                        '${top.emoji} ${top.name} ${(top.confidence * 100).round()}%',
                        style: TextStyle(
                            fontFamily: AppFonts.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary)),
                  ),
                const SizedBox(height: 6),
                Text(_fmtFull(item.createdAt),
                    style: TextStyle(
                        fontFamily: AppFonts.primary,
                        fontSize: 13,
                        color: Colors.grey.shade600)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: Colors.grey.shade300),
        ]),
      ),
    );
  }

  String _fmtFull(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ── 打招呼详情页 ─────────────────────────────────────────────
class _GreetingDetailPage extends StatefulWidget {
  final GreetingItem item;
  const _GreetingDetailPage({required this.item});

  @override
  State<_GreetingDetailPage> createState() => _GreetingDetailPageState();
}

class _GreetingDetailPageState extends State<_GreetingDetailPage> {
  VideoPlayerController? _videoCtrl;
  bool _videoReady = false;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _audioPlaying = false;

  @override
  void initState() {
    super.initState();
    if (widget.item.responseUrl.isNotEmpty) {
      _videoCtrl =
          VideoPlayerController.networkUrl(Uri.parse(widget.item.responseUrl))
            ..initialize().then((_) {
              if (mounted) setState(() => _videoReady = true);
            });
    }
    _audioPlayer.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed) {
        if (mounted) setState(() => _audioPlaying = false);
      }
    });
  }

  @override
  void dispose() {
    _videoCtrl?.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _toggleAudio() async {
    if (_audioPlaying) {
      await _audioPlayer.stop();
      setState(() => _audioPlaying = false);
    } else {
      try {
        await _audioPlayer.setUrl(widget.item.resourceUrl);
        await _audioPlayer.play();
        setState(() => _audioPlaying = true);
      } catch (_) {
        if (mounted) PetToast.error(context, '播放失败');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('打招呼详情',
            style: TextStyle(
                fontFamily: AppFonts.primary,
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700)),
      ),
      body: SingleChildScrollView(
        child: Column(children: [
          // 宠物响应视频
          if (widget.item.responseUrl.isNotEmpty)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: _videoReady
                  ? GestureDetector(
                      onTap: () {
                        _videoCtrl!.value.isPlaying
                            ? _videoCtrl!.pause()
                            : _videoCtrl!.play();
                        setState(() {});
                      },
                      child: Stack(children: [
                        AspectRatio(
                            aspectRatio: _videoCtrl!.value.aspectRatio,
                            child: VideoPlayer(_videoCtrl!)),
                        if (!_videoCtrl!.value.isPlaying)
                          const Center(
                              child: Icon(Icons.play_circle_fill_rounded,
                                  size: 60, color: Colors.white70)),
                        Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: VideoProgressIndicator(_videoCtrl!,
                                allowScrubbing: true,
                                colors: VideoProgressColors(
                                  playedColor: AppColors.primary,
                                  bufferedColor: Colors.white30,
                                  backgroundColor: Colors.white10,
                                ))),
                      ]),
                    )
                  : Container(
                      color: Colors.grey.shade900,
                      child: const Center(
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))),
            ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 招呼音频播放
                if (widget.item.resourceUrl.isNotEmpty) _buildAudioRow(),
                const SizedBox(height: 16),
                // 时间
                Row(children: [
                  const Text('📅', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Text(_fmtFull(widget.item.createdAt),
                      style: TextStyle(
                          fontFamily: AppFonts.primary,
                          fontSize: 14,
                          color: Colors.grey.shade700)),
                ]),
                // AI 情绪卡片
                if (widget.item.aiResult != null &&
                    widget.item.aiResult!.emotions.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  AiEmotionCard(
                      result: widget.item.aiResult!,
                      time: widget.item.createdAt),
                ],
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildAudioRow() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        GestureDetector(
          onTap: _toggleAudio,
          child: Container(
            width: 42,
            height: 42,
            decoration:
                BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
            child: Icon(
                _audioPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 24),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('招呼音频',
                style: TextStyle(
                    fontFamily: AppFonts.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
            Text(_audioPlaying ? '播放中...' : '点击播放招呼声',
                style: TextStyle(
                    fontFamily: AppFonts.primary,
                    fontSize: 12,
                    color: Colors.grey.shade500)),
          ],
        )),
        if (_audioPlaying)
          SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.primary)),
      ]),
    );
  }

  String _fmtFull(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ── 声音选择底部弹窗 ─────────────────────────────────────────
class _SoundPickerSheet extends StatefulWidget {
  final String petType;
  final String emotionLabel;
  final List<SoundPreset> sounds;
  final int? selectedId;
  final ValueChanged<SoundPreset> onSelect;
  final ValueChanged<int> onDeleteUser;
  final ValueChanged<SoundPreset> onRecordDone;
  final CaptureRepository repo;
  final OssUploader uploader;

  const _SoundPickerSheet({
    required this.petType,
    required this.emotionLabel,
    required this.sounds,
    required this.selectedId,
    required this.onSelect,
    required this.onDeleteUser,
    required this.onRecordDone,
    required this.repo,
    required this.uploader,
  });

  @override
  State<_SoundPickerSheet> createState() => _SoundPickerSheetState();
}

class _SoundPickerSheetState extends State<_SoundPickerSheet> {
  int? _localSelectedId;
  bool _showRecorder = false;
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<PlayerState>? _stateSub;
  String? _playingUrl;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _localSelectedId = widget.selectedId;
    _positionSub = _player.positionStream.listen((position) {
      if (mounted) setState(() => _position = position);
    });
    _durationSub = _player.durationStream.listen((duration) {
      if (mounted) setState(() => _duration = duration ?? Duration.zero);
    });
    _stateSub = _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed && mounted) {
        setState(() {
          _playingUrl = null;
          _position = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggleSound(SoundPreset sound) async {
    if (_playingUrl == sound.url) {
      await _player.stop();
      if (mounted) {
        setState(() {
          _playingUrl = null;
          _position = Duration.zero;
        });
      }
      return;
    }
    try {
      setState(() {
        _playingUrl = sound.url;
        _position = Duration.zero;
        _duration = Duration.zero;
      });
      await _player.setUrl(sound.url);
      await _player.play();
    } catch (_) {
      if (mounted) {
        setState(() => _playingUrl = null);
        PetToast.error(context, '试听失败');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showRecorder) {
      return _RecorderSheet(
        petType: widget.petType,
        emotion: widget.emotionLabel,
        repo: widget.repo,
        uploader: widget.uploader,
        onBack: () => setState(() => _showRecorder = false),
        onSaved: (sound) {
          Navigator.pop(context);
          widget.onRecordDone(sound);
        },
      );
    }

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 14),
          Row(children: [
            _SheetIconButton(
              icon: Icons.close_rounded,
              onTap: () => Navigator.pop(context),
            ),
            Expanded(
              child: Center(
                child: Text('声音',
                    style: TextStyle(
                        fontFamily: AppFonts.primary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onSurface)),
              ),
            ),
            _SheetIconButton(
              icon: Icons.mic_rounded,
              color: AppColors.primary,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              onTap: () => setState(() => _showRecorder = true),
            ),
          ]),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5),
            child: widget.sounds.isEmpty
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(12, 26, 12, 18),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(Icons.graphic_eq_rounded,
                            color: AppColors.primary, size: 26),
                      ),
                      const SizedBox(height: 12),
                      Text('暂无声音',
                          style: TextStyle(
                              fontFamily: AppFonts.primary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSurface)),
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: () => setState(() => _showRecorder = true),
                        icon: const Icon(Icons.mic_rounded, size: 18),
                        label: const Text('录音'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          textStyle: TextStyle(
                            fontFamily: AppFonts.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ]),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: widget.sounds.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final sound = widget.sounds[i];
                      final selected = _localSelectedId == sound.id;
                      final playing = _playingUrl == sound.url;
                      final progress = _duration.inMilliseconds > 0
                          ? (_position.inMilliseconds /
                                  _duration.inMilliseconds)
                              .clamp(0.0, 1.0)
                          : 0.0;
                      final remaining = _duration - _position;
                      return Material(
                        color: selected
                            ? AppColors.primary.withValues(alpha: 0.08)
                            : AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: selected
                                  ? AppColors.primary.withValues(alpha: 0.28)
                                  : Colors.transparent,
                            ),
                          ),
                          child: Column(children: [
                            Row(children: [
                              Expanded(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () {
                                    setState(() => _localSelectedId = sound.id);
                                    widget.onSelect(sound);
                                  },
                                  child: Row(children: [
                                    Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: sound.isUserCustom
                                            ? AppColors.primary
                                                .withValues(alpha: 0.12)
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Icon(
                                        sound.isUserCustom
                                            ? Icons.mic_rounded
                                            : Icons.music_note_rounded,
                                        color: AppColors.primary,
                                        size: 21,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(_soundDisplayName(sound),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                  fontFamily: AppFonts.primary,
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w800,
                                                  color: AppColors.onSurface)),
                                          if (sound.isUserCustom) ...[
                                            const SizedBox(height: 2),
                                            Text('我的录音',
                                                style: TextStyle(
                                                    fontFamily:
                                                        AppFonts.primary,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors.primary)),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ]),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _SheetIconButton(
                                icon: playing
                                    ? Icons.stop_rounded
                                    : Icons.play_arrow_rounded,
                                onTap: () => _toggleSound(sound),
                              ),
                              if (sound.isUserCustom) ...[
                                const SizedBox(width: 6),
                                _SheetIconButton(
                                  icon: Icons.delete_outline_rounded,
                                  color: Colors.red.shade500,
                                  backgroundColor:
                                      Colors.red.withValues(alpha: 0.07),
                                  onTap: () => widget.onDeleteUser(sound.id),
                                ),
                              ],
                            ]),
                            if (playing) ...[
                              const SizedBox(height: 10),
                              Row(children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(999),
                                    child: LinearProgressIndicator(
                                      value: progress,
                                      minHeight: 5,
                                      backgroundColor: Colors.white,
                                      valueColor: AlwaysStoppedAnimation(
                                          AppColors.primary),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  '${_fmtDurationText(remaining)}',
                                  style: TextStyle(
                                    fontFamily: AppFonts.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ]),
                            ],
                          ]),
                        ),
                      );
                    },
                  ),
          ),
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
        ]),
      ),
    );
  }
}

class _SheetIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  final Color? backgroundColor;

  const _SheetIconButton({
    required this.icon,
    required this.onTap,
    this.color,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor ?? AppColors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 21, color: color ?? AppColors.onSurface),
        ),
      ),
    );
  }
}

// ── 录音面板（长按录制，最长 10 秒）────────────────────────────
class _RecorderSheet extends StatefulWidget {
  final String petType;
  final String emotion;
  final CaptureRepository repo;
  final OssUploader uploader;
  final VoidCallback onBack;
  final ValueChanged<SoundPreset> onSaved;

  const _RecorderSheet({
    required this.petType,
    required this.emotion,
    required this.repo,
    required this.uploader,
    required this.onBack,
    required this.onSaved,
  });

  @override
  State<_RecorderSheet> createState() => _RecorderSheetState();
}

class _RecorderSheetState extends State<_RecorderSheet>
    with SingleTickerProviderStateMixin {
  // ── 状态枚举 ─────────────────────────────────────────────
  // idle → recording → done → uploading
  _RecState _state = _RecState.idle;

  // ── 录音 ─────────────────────────────────────────────────
  final AudioRecorder _recorder = AudioRecorder();
  String? _recordPath;
  int _seconds = 0;
  Timer? _timer;
  static const _maxSec = 10;

  // ── 播放（录音完成后预览）────────────────────────────────
  final AudioPlayer _player = AudioPlayer();
  bool _playing = false;
  double _playPos = 0; // 0.0~1.0
  double _totalSecs = 0;

  // ── 动画（圆形进度）──────────────────────────────────────
  late AnimationController _anim;

  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        vsync: this, duration: const Duration(seconds: _maxSec));
    _player.positionStream.listen((pos) {
      if (_totalSecs > 0 && mounted) {
        setState(() => _playPos = pos.inMilliseconds / (_totalSecs * 1000));
      }
    });
    _player.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed && mounted) {
        setState(() {
          _playing = false;
          _playPos = 0;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    _player.dispose();
    _anim.dispose();
    super.dispose();
  }

  // ── 开始录音（长按）──────────────────────────────────────
  Future<void> _startRecording() async {
    final granted = await Permission.microphone.request();
    if (!granted.isGranted) {
      if (mounted) PetToast.error(context, '需要麦克风权限');
      return;
    }
    final dir = await getTemporaryDirectory();
    _recordPath = '${dir.path}/rec_${const Uuid().v4()}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000),
      path: _recordPath!,
    );
    _seconds = 0;
    _anim.forward(from: 0);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _seconds++);
      if (_seconds >= _maxSec) _stopRecording();
    });
    setState(() => _state = _RecState.recording);
    HapticFeedback.mediumImpact();
  }

  // ── 停止录音（松手 或 超时）───────────────────────────────
  Future<void> _stopRecording() async {
    _timer?.cancel();
    _anim.stop();
    await _recorder.stop();
    HapticFeedback.lightImpact();

    // 加载时长
    if (_recordPath != null) {
      try {
        await _player.setFilePath(_recordPath!);
        _totalSecs = (_player.duration?.inMilliseconds ?? 0) / 1000.0;
      } catch (_) {}
    }
    setState(() => _state = _RecState.done);
  }

  // ── 重录 ─────────────────────────────────────────────────
  void _reRecord() {
    _player.stop();
    _anim.reset();
    setState(() {
      _state = _RecState.idle;
      _seconds = 0;
      _playing = false;
      _playPos = 0;
    });
  }

  // ── 播放/暂停预览 ─────────────────────────────────────────
  Future<void> _togglePlay() async {
    if (_playing) {
      await _player.pause();
      setState(() => _playing = false);
    } else {
      await _player.setFilePath(_recordPath!);
      await _player.play();
      setState(() => _playing = true);
    }
  }

  // ── 上传并保存 ────────────────────────────────────────────
  Future<void> _upload() async {
    if (_recordPath == null) return;
    setState(() => _uploading = true);
    try {
      final bytes = await File(_recordPath!).readAsBytes();
      final sign = await widget.uploader.getSign(
        folder: 'greeting-sounds',
        mimeType: 'audio/m4a',
      );
      await widget.uploader.uploadBytes(
        uploadUrl: sign.uploadUrl,
        bytes: bytes,
      );
      final id = await widget.repo.saveUserSound(
        name: '自录音 ${DateTime.now().month}/${DateTime.now().day} '
            '${DateTime.now().hour.toString().padLeft(2, '0')}:'
            '${DateTime.now().minute.toString().padLeft(2, '0')}',
        url: sign.cdnUrl,
        emotion: widget.emotion,
        petType: widget.petType,
        duration: _seconds,
      );
      final sound = SoundPreset(
        id: id,
        emotion: widget.emotion,
        name: '自录音',
        url: sign.cdnUrl,
        petType: widget.petType,
        source: 'user',
      );
      widget.onSaved(sound);
    } catch (_) {
      if (mounted) PetToast.error(context, '保存失败，请重试');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRecording = _state == _RecState.recording;
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 14),
          Row(children: [
            _SheetIconButton(
              icon: Icons.chevron_left_rounded,
              onTap: widget.onBack,
            ),
            Expanded(
              child: Center(
                child: Text('录音',
                    style: TextStyle(
                        fontFamily: AppFonts.primary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onSurface)),
              ),
            ),
            const SizedBox(width: 40),
          ]),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(children: [
              Text(
                '${(_seconds ~/ 60).toString().padLeft(2, '0')}:'
                '${(_seconds % 60).toString().padLeft(2, '0')}',
                style: TextStyle(
                  fontFamily: AppFonts.primary,
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                  color: AppColors.onSurface,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              Text(isRecording ? '松手结束' : '长按录音',
                  style: TextStyle(
                      fontFamily: AppFonts.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurfaceVariant)),
              const SizedBox(height: 20),
              if (_state == _RecState.idle || isRecording)
                GestureDetector(
                  onLongPressStart: (_) {
                    if (_state == _RecState.idle) _startRecording();
                  },
                  onLongPressEnd: (_) {
                    if (_state == _RecState.recording) _stopRecording();
                  },
                  child: AnimatedBuilder(
                    animation: _anim,
                    builder: (_, __) => Column(
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            color:
                                isRecording ? AppColors.primary : Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color:
                                    AppColors.primary.withValues(alpha: 0.18),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Icon(Icons.mic_rounded,
                              size: 38,
                              color: isRecording
                                  ? Colors.white
                                  : AppColors.primary),
                        ),
                        if (isRecording) ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            width: 148,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: _anim.value,
                                minHeight: 5,
                                backgroundColor: Colors.white,
                                valueColor:
                                    AlwaysStoppedAnimation(AppColors.primary),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              else
                Column(children: [
                  SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 4,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 7),
                      activeTrackColor: AppColors.primary,
                      inactiveTrackColor: Colors.white,
                      thumbColor: AppColors.primary,
                      overlayColor: AppColors.primary.withValues(alpha: 0.16),
                    ),
                    child: Slider(
                      value: _playPos.clamp(0.0, 1.0),
                      onChanged: (v) async {
                        setState(() => _playPos = v);
                        final pos = Duration(
                            milliseconds: (v * _totalSecs * 1000).round());
                        await _player.seek(pos);
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    Text(_fmtDur(_seconds),
                        style: TextStyle(
                            fontFamily: AppFonts.primary,
                            fontSize: 12,
                            color: AppColors.onSurfaceVariant)),
                    const Spacer(),
                    _SheetIconButton(
                      icon: _playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      backgroundColor: AppColors.primary,
                      onTap: _togglePlay,
                    ),
                    const Spacer(),
                    Text(_fmtDur(_seconds),
                        style: TextStyle(
                            fontFamily: AppFonts.primary,
                            fontSize: 12,
                            color: AppColors.onSurfaceVariant)),
                  ]),
                ]),
            ]),
          ),
          if (_state == _RecState.done) ...[
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _uploading ? null : _reRecord,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('重录'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.onSurface,
                    minimumSize: const Size.fromHeight(46),
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    side: BorderSide(color: Colors.grey.shade300),
                    textStyle: TextStyle(
                      fontFamily: AppFonts.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _uploading ? null : _upload,
                  icon: _uploading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_rounded, size: 18),
                  label: Text(_uploading ? '保存中' : '保存'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(46),
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                    textStyle: TextStyle(
                      fontFamily: AppFonts.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ]),
          ],
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
        ]),
      ),
    );
  }

  String _fmtDur(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

enum _RecState { idle, recording, done }
