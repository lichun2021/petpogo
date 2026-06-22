/// 自动打招呼页 — 配置（声音+计划）+ 媒体库
/// 录音最长 10 秒，长按录制，松手结束
library;

import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:gal/gal.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import '../../shared/utils/wechat_share.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:media_kit/media_kit.dart'
    hide PlayerState; // hide避免与just_audio.PlayerState冲突
import 'package:media_kit_video/media_kit_video.dart';

import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_fonts.dart';
import '../../features/consultation/data/repository/consultation_repository.dart';

import '../../shared/utils/oss_uploader.dart';
import '../../shared/widgets/pet_toast.dart';
import '../share/data/repository/share_repository.dart';
import 'data/models/capture_model.dart';
import 'data/repository/capture_repository.dart';
import 'widgets/ai_emotion_card.dart';
import 'widgets/date_filter_bar.dart';
import 'widgets/date_picker_sheet.dart';

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
  int _soundTabDirection = 1;

  // ── 计划配置 ─────────────────────────────────────────────
  bool _enabled = false;
  TimeOfDay _startTime = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 18, minute: 0);
  Set<int> _weekdays = {1, 2, 3, 4, 5, 6, 7};
  int _count = 3; // 时间段内触发次数

  // ── 媒体库 ───────────────────────────────────────────────
  // 全量记录（首次进入即拉取全部，供按日期分组/筛选）
  final List<GreetingItem> _allItems = [];
  // 有记录的日期（降序，日历 / 日期条仅这些天可选）
  List<DateTime> _availableDates = [];
  // 当前选中日期；null = 还没加载完成或无记录
  DateTime? _selectedDate;
  bool _loading = false;
  final ScrollController _scroll = ScrollController();

  /// 当前选中日期下的记录（按时间倒序）
  List<GreetingItem> get _visibleItems {
    if (_selectedDate == null) return const [];
    final s = _selectedDate!;
    return _allItems
        .where((i) =>
            i.createdAt.year == s.year &&
            i.createdAt.month == s.month &&
            i.createdAt.day == s.day)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  // ── 服务端状态 ───────────────────────────────────────────
  String _account = '';
  bool _apiSaving = false;
  bool _settingExists = false;

  // ── 音频播放（试听预设）──────────────────────────────────
  final AudioPlayer _previewPlayer = AudioPlayer();
  String? _playingUrl;

  String get _prefKey => 'robot_ai_greeting_${widget.mac}';

  @override
  void initState() {
    super.initState();
    _loadAccount();
    _loadPrefs();
    _loadSounds(); // 进页面并行拉一次猫 + 狗，后续切换只读缓存
    _loadMedia();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _previewPlayer.dispose();
    super.dispose();
  }

  // ── 加载账号 ─────────────────────────────────────────────
  Future<void> _loadAccount() async {
    const storage = FlutterSecureStorage();
    final account = await storage.read(key: 'auth_account') ?? '';
    if (mounted) setState(() => _account = account);
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

  // ── 加载媒体库（全量拉取，用于按日期分组/筛选）─────────────
  Future<void> _loadMedia() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final repo = ref.read(captureRepositoryProvider);
      final all = <GreetingItem>[];
      var page = 1;
      const pageSize = 100;
      // 循环分页拉取，直到没有更多
      while (true) {
        final res = await repo.fetchGreetingList(
          deviceId: widget.mac,
          page: page,
          pageSize: pageSize,
        );
        all.addAll(res.list);
        if (!res.hasMore) break;
        page++;
      }
      if (!mounted) return;
      // 按时间倒序排序，便于「最新一天」计算
      all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final dates = _computeAvailableDates(all);
      setState(() {
        _allItems
          ..clear()
          ..addAll(all);
        _availableDates = dates;
        // 默认选中最新有记录的一天；若当前选中天仍存在则保留
        if (_selectedDate == null ||
            !dates.any((d) =>
                d.year == _selectedDate!.year &&
                d.month == _selectedDate!.month &&
                d.day == _selectedDate!.day)) {
          _selectedDate = dates.isNotEmpty ? dates.first : null;
        }
      });
    } catch (_) {
      if (mounted) PetToast.error(context, '记录加载失败');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 从记录列表提取有记录的天（DateTime(y,m,d)，降序去重）
  List<DateTime> _computeAvailableDates(List<GreetingItem> items) {
    final set = <String>{};
    final list = <DateTime>[];
    for (final i in items) {
      final d = DateTime(i.createdAt.year, i.createdAt.month, i.createdAt.day);
      final key = '${d.year}-${d.month}-${d.day}';
      if (set.add(key)) list.add(d);
    }
    list.sort((a, b) => b.compareTo(a));
    return list;
  }

  // ── 保存配置（本地）────────────────────────────────────────
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

  // ── 保存并开启服务端设置（save + toggle 双重保障）──────────
  Future<void> _saveToServer() async {
    if (_account.isEmpty) {
      PetToast.error(context, '无法获取账户信息，请重新登录');
      return;
    }
    final startMin = _startTime.hour * 60 + _startTime.minute;
    final endMin = _endTime.hour * 60 + _endTime.minute;
    if (startMin >= endMin) {
      PetToast.error(context, '结束时间必须晚于开始时间');
      return;
    }
    setState(() => _apiSaving = true);
    final result =
        await ref.read(consultationRepositoryProvider).saveVoiceAnalysisSetting(
              account: _account,
              deviceNo: widget.mac,
              effectiveStartTime: _fmtTime(_startTime),
              effectiveEndTime: _fmtTime(_endTime),
              repeatWeekdays: _weekdays.toList()..sort(),
              dailyAnalysisCount: _count,
              enabled: true,
            );
    if (!mounted) return;
    setState(() => _apiSaving = false);
    result.when(
      success: (_) async {
        // 保存后额外调用 enable 确保开启
        await ref
            .read(consultationRepositoryProvider)
            .toggleVoiceAnalysisSetting(
              account: _account,
              deviceNo: widget.mac,
              enabled: true,
            );
        if (!mounted) return;
        setState(() {
          _settingExists = true;
          _enabled = true;
        });
        await _persistPrefs();
        PetToast.success(context, '设置已保存并开启');
      },
      failure: (e) => PetToast.error(context, e.message),
    );
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
          child: SafeArea(
            top: false,
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () => _loadMedia(),
              child: CustomScrollView(
                controller: _scroll,
                slivers: [
                  // ── 配置卡片 ──
                  SliverToBoxAdapter(child: _buildConfigCard()),
                  // ── 媒体库标题 ──
                  SliverToBoxAdapter(child: _buildMediaHeader()),
                  // ── 日期筛选条 ──
                  if (_availableDates.isNotEmpty)
                    SliverToBoxAdapter(child: _buildDateFilterBar()),
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  // ── 媒体列表 ──
                  _buildMediaList(),
                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              ),
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
        _buildSoundSettingsBody(),
        const SizedBox(height: 6),
        // ── 保存设置按钮 ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _apiSaving ? null : _saveToServer,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
                textStyle: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
              child: _apiSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(
                      _settingExists ? '更新设置' : '保存设置',
                      maxLines: 1,
                    ),
            ),
          ),
        ),
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

  Widget _buildSoundSettingsBody() {
    return ClipRect(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        reverseDuration: const Duration(milliseconds: 200),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          return SizeTransition(
            sizeFactor: animation,
            axisAlignment: -1,
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        child: !_soundExpanded
            ? const SizedBox.shrink(key: ValueKey('sound-collapsed'))
            : Column(
                key: const ValueKey('sound-expanded'),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                    child: _buildPetTab(),
                  ),
                  _soundLoading
                      ? Padding(
                          padding: const EdgeInsets.all(20),
                          child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          ),
                        )
                      : _buildSoundListSwitcher(),
                  const Divider(height: 1, indent: 20, endIndent: 20),
                ],
              ),
      ),
    );
  }

  Widget _buildSoundListSwitcher() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 240),
        reverseDuration: const Duration(milliseconds: 180),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (currentChild, previousChildren) {
          return Stack(
            alignment: Alignment.topCenter,
            children: [
              ...previousChildren,
              if (currentChild != null) currentChild,
            ],
          );
        },
        transitionBuilder: (child, animation) {
          final begin = Offset(_soundTabDirection * 0.08, 0);
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: begin,
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: KeyedSubtree(
          key: ValueKey(_petTypes[_selectedPetIndex]),
          child: _buildSoundList(),
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
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: _selectedPetIndex == 0
                ? Alignment.centerLeft
                : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
          Row(
            children: List.generate(_petTypes.length, (i) {
              final selected = _selectedPetIndex == i;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (_selectedPetIndex == i) return;
                    HapticFeedback.selectionClick();
                    setState(() {
                      _soundTabDirection = i > _selectedPetIndex ? 1 : -1;
                      _selectedPetIndex = i;
                    });
                  },
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOutCubic,
                      style: TextStyle(
                        fontFamily: AppFonts.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: selected ? Colors.white : Colors.grey.shade600,
                        height: 1.0,
                      ),
                      child: Text(
                        tabTexts[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
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
  Widget _buildDateFilterBar() {
    return DateFilterBar(
      availableDates: _availableDates,
      selectedDate: _selectedDate,
      onChanged: (d) => setState(() => _selectedDate = d),
    );
  }

  Future<void> _openCalendar() async {
    final picked = await showRecordDatePickerSheet(
      context: context,
      availableDates: _availableDates,
      initialDate: _selectedDate,
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  Widget _buildMediaHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 12, 8),
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
          child: Text('${_visibleItems.length}',
              style: TextStyle(
                  fontFamily: AppFonts.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary)),
        ),
        const Spacer(),
        CalendarIconButton(onTap: _openCalendar),
      ]),
    );
  }

  // ── 媒体列表（列表式）────────────────────────────────────
  Widget _buildMediaList() {
    if (_loading && _visibleItems.isEmpty) {
      return SliverToBoxAdapter(
          child: Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.primary)),
      ));
    }
    if (_visibleItems.isEmpty) {
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
          (ctx, i) {
            if (i >= _visibleItems.length) return null;
            final item = _visibleItems[i];
            return _GreetingCell(
              item: item,
              onTap: () => _openDetail(item),
            );
          },
          childCount: _visibleItems.length,
        ),
      ),
    );
  }

  void _openDetail(GreetingItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GreetingDetailSheet(
        item: item,
        onDeleted: () {
          setState(() {
            _allItems.removeWhere((e) => e.id == item.id);
            _availableDates = _computeAvailableDates(_allItems);
            // 若选中天已无记录，自动切换到最新有记录天
            if (_selectedDate != null &&
                !_availableDates.any((d) =>
                    d.year == _selectedDate!.year &&
                    d.month == _selectedDate!.month &&
                    d.day == _selectedDate!.day)) {
              _selectedDate =
                  _availableDates.isNotEmpty ? _availableDates.first : null;
            }
          });
        },
      ),
    );
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

// ── 打招呼横排卡片 ────────────────────────────────────────
class _GreetingCell extends StatelessWidget {
  final GreetingItem item;
  final VoidCallback onTap;
  const _GreetingCell({required this.item, required this.onTap});

  // 根据情绪生成左侧渐变色，没有情绪则用品牌主色
  static const List<List<Color>> _emotionPalettes = [
    [Color(0xFF43E97B), Color(0xFF38F9D7)], // 兴奋 / 开心
    [Color(0xFF4FACFE), Color(0xFF00F2FE)], // 平静
    [Color(0xFFFA709A), Color(0xFFFEE140)], // 疼痛 / 担忧
    [Color(0xFF667EEA), Color(0xFF764BA2)], // 其他
  ];

  List<Color> get _gradient {
    final name = item.aiResult?.top?.name ?? '';
    if (name.contains('兴') || name.contains('开') || name.contains('喜')) {
      return _emotionPalettes[0];
    } else if (name.contains('静') || name.contains('安')) {
      return _emotionPalettes[1];
    } else if (name.contains('痛') || name.contains('担') || name.contains('焦')) {
      return _emotionPalettes[2];
    }
    return _emotionPalettes[3];
  }

  @override
  Widget build(BuildContext context) {
    final top = item.aiResult?.top;
    final hasCover = item.coverUrl.isNotEmpty;
    final hasVideo = item.responseUrl.isNotEmpty;
    final hasAudio = item.resourceUrl.isNotEmpty;
    final grad = _gradient;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        height: 88,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: grad[0].withValues(alpha: 0.18),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: grad[0].withValues(alpha: 0.28),
            width: 1.2,
          ),
        ),
        child: Row(children: [
          // ── 左侧：渐变色封面图 ──
          ClipRRect(
            borderRadius:
                const BorderRadius.horizontal(left: Radius.circular(15)),
            child: SizedBox(
              width: 88,
              height: 88,
              child: Stack(fit: StackFit.expand, children: [
                // 封面图 or 渐变占位
                if (hasCover || hasVideo)
                  CachedNetworkImage(
                    imageUrl: hasCover ? item.coverUrl : item.responseUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => _buildCoverPlaceholder(grad),
                    errorWidget: (_, __, ___) => _buildCoverPlaceholder(grad),
                  )
                else
                  _buildCoverPlaceholder(grad),
                // 视频图标角标
                if (hasVideo)
                  Positioned(
                    bottom: 5,
                    right: 5,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                          color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 14),
                    ),
                  ),
              ]),
            ),
          ),
          // ── 右侧：内容 ──
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 情绪标签
                  if (top != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            grad[0].withValues(alpha: 0.15),
                            grad[1].withValues(alpha: 0.08)
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: grad[0].withValues(alpha: 0.35), width: 0.8),
                      ),
                      child: Text(
                        '${top.emoji} ${top.name}  ${(top.confidence * 100).round()}%',
                        style: TextStyle(
                          fontFamily: AppFonts.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: grad[0].withValues(alpha: 1),
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('👋 打招呼',
                          style: TextStyle(
                              fontFamily: AppFonts.primary,
                              fontSize: 11,
                              color: Colors.grey.shade600)),
                    ),
                  const SizedBox(height: 6),
                  // 时间
                  Row(children: [
                    Icon(Icons.access_time_rounded,
                        size: 11, color: Colors.grey.shade400),
                    const SizedBox(width: 3),
                    Text(
                      _fmtFull(item.createdAt),
                      style: TextStyle(
                        fontFamily: AppFonts.primary,
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ]),
                  if (hasAudio) ...[
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(Icons.graphic_eq_rounded,
                          size: 11, color: grad[0].withValues(alpha: 0.8)),
                      const SizedBox(width: 3),
                      Text('含招呼音频',
                          style: TextStyle(
                              fontFamily: AppFonts.primary,
                              fontSize: 10,
                              color: grad[0].withValues(alpha: 0.85),
                              fontWeight: FontWeight.w600)),
                    ]),
                  ],
                ],
              ),
            ),
          ),
          // ── 右箭头 ──
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Icon(Icons.chevron_right_rounded,
                size: 20, color: Colors.grey.shade300),
          ),
        ]),
      ),
    );
  }

  Widget _buildCoverPlaceholder(List<Color> grad) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            grad[0].withValues(alpha: 0.3),
            grad[1].withValues(alpha: 0.15)
          ],
        ),
      ),
      child: const Center(child: Text('🐾', style: TextStyle(fontSize: 28))),
    );
  }

  String _fmtFull(DateTime dt) {
    String p(int v) => v.toString().padLeft(2, '0');
    return '${dt.month}/${dt.day}  ${p(dt.hour)}:${p(dt.minute)}';
  }
}

class _GreetingDetailSheet extends ConsumerStatefulWidget {
  final GreetingItem item;
  final VoidCallback onDeleted;
  const _GreetingDetailSheet({required this.item, required this.onDeleted});

  @override
  ConsumerState<_GreetingDetailSheet> createState() =>
      _GreetingDetailSheetState();
}

class _GreetingDetailSheetState extends ConsumerState<_GreetingDetailSheet> {
  // ── media_kit 播放器
  Player? _mkPlayer;
  VideoController? _mkController;
  bool _videoError = false;

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _audioPlaying = false;
  Duration _audioPos = Duration.zero;
  Duration _audioDur = Duration.zero;

  bool _downloading = false;
  bool _deleting = false;
  bool _sharingCommunity = false;

  @override
  void initState() {
    super.initState();
    if (widget.item.responseUrl.isNotEmpty) {
      _mkPlayer = Player();
      _mkController = VideoController(
        _mkPlayer!,
        configuration: const VideoControllerConfiguration(
          enableHardwareAcceleration: false,
        ),
      );

      _mkPlayer!.stream.error.listen((err) {
        debugPrint('[Video] media_kit error: $err');
        if (mounted) setState(() => _videoError = true);
      });
      _mkPlayer!.open(Media(widget.item.responseUrl));
    }
    _audioPlayer.positionStream.listen((p) {
      if (mounted) setState(() => _audioPos = p);
    });
    _audioPlayer.durationStream.listen((d) {
      if (mounted) setState(() => _audioDur = d ?? Duration.zero);
    });
    _audioPlayer.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed && mounted) {
        setState(() {
          _audioPlaying = false;
          _audioPos = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _mkPlayer?.dispose();
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

  Future<void> _download() async {
    final url = widget.item.coverUrl.isNotEmpty
        ? widget.item.coverUrl
        : widget.item.responseUrl;
    if (url.isEmpty) return;
    setState(() => _downloading = true);
    try {
      final hasAccess = await Gal.hasAccess(toAlbum: true);
      if (!hasAccess) {
        final ok = await Gal.requestAccess(toAlbum: true);
        if (!ok) {
          if (mounted) PetToast.error(context, '无相册权限，请在设置中开启');
          return;
        }
      }
      final tmp = await getTemporaryDirectory();
      final isVideo = widget.item.responseUrl.isNotEmpty;
      final ext = isVideo ? 'mp4' : 'jpg';
      final path =
          '${tmp.path}/greeting_${DateTime.now().millisecondsSinceEpoch}.$ext';
      await Dio().download(url, path);
      if (isVideo) {
        await Gal.putVideo(path, album: 'PetPogo');
      } else {
        await Gal.putImage(path, album: 'PetPogo');
      }
      await File(path).delete();
      if (mounted) PetToast.success(context, '已保存到相册');
    } catch (_) {
      if (mounted) PetToast.error(context, '保存失败，请重试');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _delete(BuildContext ctx) async {
    final confirm = await showDialog<bool>(
      context: ctx,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除打招呼记录'),
        content: const Text('确定要删除这条打招呼记录吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      // TODO: 接入打招呼删除接口
      widget.onDeleted();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) PetToast.error(context, '删除失败，请重试');
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _shareToWechat() {
    return _shareGreeting(WechatShareScene.session);
  }

  Future<void> _shareToTimeline() {
    return _shareGreeting(WechatShareScene.timeline);
  }

  Future<void> _shareGreeting(WechatShareScene scene) async {
    final url = widget.item.coverUrl.isNotEmpty
        ? widget.item.coverUrl
        : widget.item.responseUrl;
    if (url.isEmpty) return;
    final emotion = widget.item.aiResult?.top;
    final emotionText =
        emotion != null ? ' Ta现在${emotion.emoji}${emotion.name}' : '';
    final description = '我家宠物打招呼瞬间$emotionText，快来看看。';

    final result = await ref.read(shareRepositoryProvider).createShare(
      type: 'greeting',
      targetId: widget.item.id.toString(),
      title: '分享一段宠物打招呼',
      description: description,
      imageUrl: widget.item.coverUrl,
      payload: {
        'deviceId': widget.item.deviceId,
        'resourceUrl': widget.item.resourceUrl,
        'responseUrl': widget.item.responseUrl,
        'coverUrl': widget.item.coverUrl,
        'createdAt': widget.item.createdAt.toIso8601String(),
      },
    );

    await result.when<Future<void>>(
      success: (share) async {
        if (share.shareUrl.isEmpty) {
          if (mounted) PetToast.error(context, '分享链接生成失败');
          return;
        }
        await shareWechatWebPage(
          url: share.shareUrl,
          title: share.title.isNotEmpty ? share.title : '宠物打招呼',
          description:
              share.description.isNotEmpty ? share.description : description,
          scene: scene,
        );
        if (mounted) PetToast.success(context, '分享已打开');
      },
      failure: (error) async {
        if (mounted) PetToast.error(context, error.userMessage);
      },
    );
  }

  void _showShareSheet(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (_) => _GreetShareSheet(
        onWechat: () {
          Navigator.pop(ctx);
          _shareToWechat();
        },
        onTimeline: () {
          Navigator.pop(ctx);
          _shareToTimeline();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasResponse = widget.item.responseUrl.isNotEmpty;
    final hasCover = widget.item.coverUrl.isNotEmpty;
    final hasGreetAudio = widget.item.resourceUrl.isNotEmpty;
    final hasEmotion = widget.item.aiResult?.emotions.isNotEmpty == true;
    final bottomPad = MediaQuery.of(context).viewPadding.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPad),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // 拖拽指示条
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 4),
          // 可滚动内容（最多占屏高 80%）
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.80,
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.zero,
              child: Column(children: [
                // 封面 / 视频区
                _buildMediaArea(hasResponse, hasCover),
                // 信息区
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (hasGreetAudio) _buildAudioRow(),
                      if (hasGreetAudio) const SizedBox(height: 12),
                      _GreetInfoRow(
                          icon: '📅',
                          label: '打招呼时间',
                          value: _fmtFull(widget.item.createdAt)),
                      if (hasEmotion) ...[
                        const SizedBox(height: 16),
                        AiEmotionCard(
                            result: widget.item.aiResult!,
                            time: widget.item.createdAt),
                      ],
                      const SizedBox(height: 20),
                      // ── 操作按钮行 ──
                      Row(children: [
                        // 下载（有封面/视频才显示）
                        if (hasCover || hasResponse) ...[
                          Expanded(
                            child: SizedBox(
                              height: 46,
                              child: ElevatedButton.icon(
                                onPressed: _downloading ? null : _download,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size.fromHeight(46),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                  textStyle: TextStyle(
                                    fontFamily: AppFonts.primary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    height: 1.1,
                                  ),
                                ),
                                icon: _downloading
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white))
                                    : const Icon(Icons.download_rounded,
                                        size: 18),
                                label: Text(_downloading ? '保存中...' : '保存到相册',
                                    maxLines: 1),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        // 删除
                        SizedBox(
                          width: 46,
                          height: 46,
                          child: Builder(
                            builder: (ctx) => ElevatedButton(
                              onPressed: _deleting ? null : () => _delete(ctx),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade50,
                                foregroundColor: Colors.red.shade700,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                                padding: EdgeInsets.zero,
                              ),
                              child: _deleting
                                  ? SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.red.shade700))
                                  : const Icon(Icons.delete_outline_rounded,
                                      size: 20),
                            ),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildMediaArea(bool hasResponse, bool hasCover) {
    if (hasResponse) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          color: Colors.black,
          child: _videoError
              ? _buildVideoErrorWidget()
              : _mkController != null
                  ? Video(
                      controller: _mkController!,
                      controls: AdaptiveVideoControls,
                    )
                  : const Center(
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white)),
        ),
      );
    }
    if (hasCover) {
      return AspectRatio(
        aspectRatio: 4 / 3,
        child: CachedNetworkImage(
          imageUrl: widget.item.coverUrl,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => Container(
              color: Colors.grey.shade200,
              child: const Icon(Icons.broken_image_outlined,
                  size: 48, color: Colors.grey)),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  // 视频解码失败降级 UI
  Widget _buildVideoErrorWidget() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.videocam_off_rounded,
              color: Colors.white54, size: 40),
          const SizedBox(height: 8),
          const Text('视频格式暂不支持播放',
              style: TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 4),
          Text('可保存到相册查看',
              style: TextStyle(color: Colors.white38, fontSize: 11)),
        ]),
      );

  Widget _buildAudioRow() {
    final progress = _audioDur.inMilliseconds > 0
        ? (_audioPos.inMilliseconds / _audioDur.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(children: [
        Row(children: [
          GestureDetector(
            onTap: _toggleAudio,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: AppColors.primary, shape: BoxShape.circle),
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
                Text('👋 招呼音频',
                    style: TextStyle(
                        fontFamily: AppFonts.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                Text(
                    _audioPlaying
                        ? '${_fmtDur(_audioPos)} / ${_fmtDur(_audioDur)}'
                        : '点击播放招呼声',
                    style: TextStyle(
                        fontFamily: AppFonts.primary,
                        fontSize: 12,
                        color: Colors.grey.shade500)),
              ],
            ),
          ),
        ]),
        if (_audioPlaying || progress > 0) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.toDouble(),
              minHeight: 3,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
        ],
      ]),
    );
  }

  String _fmtDur(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _fmtFull(DateTime dt) {
    String p(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${p(dt.month)}-${p(dt.day)} ${p(dt.hour)}:${p(dt.minute)}';
  }
}

// ── 微信图标按钮（46×46）───────────────────────────
class _WechatIconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;
  const _WechatIconBtn(
      {required this.icon,
      required this.tooltip,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }
}

class _GreetInfoRow extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  const _GreetInfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(icon, style: const TextStyle(fontSize: 16)),
      const SizedBox(width: 8),
      Text(label,
          style: TextStyle(
              fontFamily: AppFonts.primary,
              fontSize: 14,
              color: Colors.grey.shade600)),
      const Spacer(),
      Text(value,
          style: TextStyle(
              fontFamily: AppFonts.primary,
              fontSize: 14,
              fontWeight: FontWeight.w600)),
    ]);
  }
}

// ── 打招呼详情页（全新沉浸式设计）──────────────────────────
class _GreetingDetailPage extends StatefulWidget {
  final GreetingItem item;
  const _GreetingDetailPage({required this.item});

  @override
  State<_GreetingDetailPage> createState() => _GreetingDetailPageState();
}

class _GreetingDetailPageState extends State<_GreetingDetailPage>
    with TickerProviderStateMixin {
  // ── media_kit 播放器
  Player? _mkPlayer;
  VideoController? _mkController;
  bool _videoError = false;

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _audioPlaying = false;
  Duration _audioPos = Duration.zero;
  Duration _audioDur = Duration.zero;

  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    if (widget.item.responseUrl.isNotEmpty) {
      _mkPlayer = Player();
      _mkController = VideoController(
        _mkPlayer!,
        configuration: const VideoControllerConfiguration(
          enableHardwareAcceleration: false,
        ),
      );

      _mkPlayer!.stream.error.listen((err) {
        debugPrint('[Video] media_kit error: $err');
        if (mounted) setState(() => _videoError = true);
      });
      _mkPlayer!.open(Media(widget.item.responseUrl));
    }
    _audioPlayer.positionStream.listen((p) {
      if (mounted) setState(() => _audioPos = p);
    });
    _audioPlayer.durationStream.listen((d) {
      if (mounted) setState(() => _audioDur = d ?? Duration.zero);
    });
    _audioPlayer.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed && mounted) {
        setState(() {
          _audioPlaying = false;
          _audioPos = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _mkPlayer?.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _toggleVideo() async {
    if (_mkPlayer == null) return;
    _mkPlayer!.state.playing ? _mkPlayer!.pause() : _mkPlayer!.play();
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
    final hasResponse = widget.item.responseUrl.isNotEmpty;
    final hasGreet = widget.item.resourceUrl.isNotEmpty;
    final hasEmotion = widget.item.aiResult?.emotions.isNotEmpty == true;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '🐾 打招呼详情',
          style: TextStyle(
            fontFamily: AppFonts.primary,
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 视频 / 封面区（顶部全宽，沉到 AppBar 后面）
            _buildVideoSection(hasResponse),

            const SizedBox(height: 20),

            // 招呼音频播放器
            if (hasGreet)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildAudioPlayer(),
              ),

            // 时间 chip
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Wrap(children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(99),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.access_time_rounded,
                        size: 13, color: Colors.white.withValues(alpha: 0.55)),
                    const SizedBox(width: 5),
                    Text(
                      _fmtFull(widget.item.createdAt),
                      style: TextStyle(
                        fontFamily: AppFonts.primary,
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ]),
                ),
              ]),
            ),

            // AI 情绪卡片
            if (hasEmotion)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: AiEmotionCard(
                    result: widget.item.aiResult!, time: widget.item.createdAt),
              ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ─ 视频区
  Widget _buildVideoSection(bool hasResponse) {
    final hasCover = widget.item.coverUrl.isNotEmpty;
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 背景：封面 or 深色渐变（video出错或未就绪时）
          if (!hasResponse || _videoError || _mkController == null)
            _videoError
                ? _videoErrorBg()
                : hasCover
                    ? CachedNetworkImage(
                        imageUrl: widget.item.coverUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _videoBg(),
                      )
                    : _videoBg(),
          // media_kit 视频播放器（自带进度条 + 播放按钮）
          if (hasResponse && _mkController != null && !_videoError)
            Video(
              controller: _mkController!,
              controls: AdaptiveVideoControls,
            ),
          // 底部渐变遮罩
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 100,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xFF0D0D1A)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _videoBg() => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primary.withValues(alpha: 0.15),
              const Color(0xFF0D0D1A),
            ],
          ),
        ),
        child: const Center(child: Text('🐾', style: TextStyle(fontSize: 52))),
      );

  // 视频解码失败降级背景
  Widget _videoErrorBg() => Container(
        color: const Color(0xFF0D0D1A),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.videocam_off_rounded,
              color: Colors.white38, size: 52),
          const SizedBox(height: 12),
          const Text('视频格式暂不支持播放',
              style: TextStyle(color: Colors.white54, fontSize: 14)),
          const SizedBox(height: 4),
          const Text('可保存到相册后查看',
              style: TextStyle(color: Colors.white30, fontSize: 12)),
        ]),
      );

  // ─ 音频播放器
  Widget _buildAudioPlayer() {
    final progress = _audioDur.inMilliseconds > 0
        ? (_audioPos.inMilliseconds / _audioDur.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.22),
            AppColors.primary.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.28), width: 1),
      ),
      child: Column(children: [
        Row(children: [
          // 播放按钮（呼吸光晕）
          GestureDetector(
            onTap: _toggleAudio,
            child: AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, child) => Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                  boxShadow: _audioPlaying
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(
                                alpha: 0.35 + 0.30 * _pulseCtrl.value),
                            blurRadius: 12 + 10 * _pulseCtrl.value,
                            spreadRadius: 2 * _pulseCtrl.value,
                          )
                        ]
                      : [],
                ),
                child: child,
              ),
              child: Icon(
                _audioPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
          const SizedBox(width: 14),
          // 标题 + 进度文字
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '👋 招呼音频',
                  style: TextStyle(
                    fontFamily: AppFonts.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _audioPlaying
                      ? '${_fmtDur(_audioPos)} / ${_fmtDur(_audioDur)}'
                      : '点击播放招呼声音',
                  style: TextStyle(
                    fontFamily: AppFonts.primary,
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ]),
        // 进度条
        if (_audioPlaying || progress > 0) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.toDouble(),
              minHeight: 3,
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
        ],
      ]),
    );
  }

  String _fmtDur(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _fmtFull(DateTime dt) {
    String p(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${p(dt.month)}-${p(dt.day)}  ${p(dt.hour)}:${p(dt.minute)}';
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

// ── 打招呼专用分享弹窗（微信好友 + 朋友圈）──────────────────
class _GreetShareSheet extends StatelessWidget {
  final VoidCallback onWechat;
  final VoidCallback onTimeline;
  const _GreetShareSheet({required this.onWechat, required this.onTimeline});

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewPadding.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomPad),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 18),
          Text('分享到',
              style: TextStyle(
                  fontFamily: AppFonts.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _GreetShareOption(
                icon: Icons.chat_bubble_rounded,
                label: '微信好友',
                color: const Color(0xFF07C160),
                onTap: onWechat,
              ),
              _GreetShareOption(
                icon: Icons.wb_sunny_rounded,
                label: '朋友圈',
                color: const Color(0xFF07C160),
                onTap: onTimeline,
              ),
            ],
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

class _GreetShareOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _GreetShareOption(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border:
                Border.all(color: color.withValues(alpha: 0.20), width: 1.5),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(height: 8),
        Text(label,
            style: TextStyle(
                fontFamily: AppFonts.primary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurface)),
      ]),
    );
  }
}
