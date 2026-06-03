/// 品种选择全屏页 — 仿电话本字母索引 + 搜索
///
/// 使用方式：
///   final breed = await Navigator.push<String>(context,
///     MaterialPageRoute(builder: (_) => BreedPickerPage(species: 'cat')));

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../shared/theme/app_colors.dart';
import 'package:petpogo_app/shared/theme/app_fonts.dart';

class BreedPickerPage extends StatefulWidget {
  /// 'cat' 或 'dog'
  final String species;
  const BreedPickerPage({super.key, required this.species});

  @override
  State<BreedPickerPage> createState() => _BreedPickerPageState();
}

class _BreedPickerPageState extends State<BreedPickerPage> {
  // 按字母分组 { 'A': ['阿比西尼亚猫', ...], ... }
  Map<String, List<String>> _groups = const {};
  bool _loading = true;

  String _query = '';
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  // 每类 item 的固定高度（用于准确计算跳转偏移量）
  static const _headerH = 36.0;
  static const _tileH   = 52.0;

  @override
  void initState() {
    super.initState();
    _loadBreeds();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBreeds() async {
    final jsonStr = await rootBundle
        .loadString('assets/fonts/pet_breeds.json');
    final data  = json.decode(jsonStr) as Map<String, dynamic>;
    final key   = widget.species == 'cat' ? 'cats' : 'dogs';
    final raw   = data[key] as Map<String, dynamic>;
    final groups = raw.map(
        (k, v) => MapEntry(k, List<String>.from(v as List)));
    if (mounted) {
      setState(() {
        _groups  = groups;
        _loading = false;
      });
    }
  }

  // ── 过滤 ────────────────────────────────────────────────
  Map<String, List<String>> get _filtered {
    if (_query.isEmpty) return _groups;
    final q = _query.toLowerCase();
    final result = <String, List<String>>{};
    for (final e in _groups.entries) {
      final matches = e.value.where((b) => b.contains(q)).toList();
      if (matches.isNotEmpty) result[e.key] = matches;
    }
    return result;
  }

  // ── 展平成 [header|breed] 列表 ──────────────────────────
  List<({bool isHeader, String value})> get _flatItems {
    final filtered = _filtered;
    final letters  = filtered.keys.toList()..sort();
    final items    = <({bool isHeader, String value})>[];
    for (final letter in letters) {
      items.add((isHeader: true, value: letter));
      for (final breed in filtered[letter]!) {
        items.add((isHeader: false, value: breed));
      }
    }
    return items;
  }

  // ── 精确跳转到字母对应的滚动位置 ────────────────────────
  void _scrollToLetter(String letter) {
    if (!_scrollCtrl.hasClients) return;
    double offset = 0;
    for (final item in _flatItems) {
      if (item.isHeader && item.value == letter) break;
      offset += item.isHeader ? _headerH : _tileH;
    }
    _scrollCtrl.animateTo(
      offset.clamp(0.0, _scrollCtrl.position.maxScrollExtent),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final items          = _flatItems;
    final filteredLetters = _filtered.keys.toList()..sort();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: AppColors.onSurface,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.species == 'cat' ? '选择猫品种' : '选择狗品种',
          style: const TextStyle(
            fontFamily: AppFonts.primary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        centerTitle: true,
        // 搜索栏嵌入 AppBar 底部
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.outlineVariant.withOpacity(0.4),
                  width: 1,
                ),
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
                style: const TextStyle(
                  fontFamily: AppFonts.primary,
                  fontSize: 14,
                  color: AppColors.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: '搜索品种名称…',
                  hintStyle: TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontFamily: AppFonts.primary,
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: AppColors.onSurfaceVariant,
                    size: 18,
                  ),
                  suffixIcon: _query.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                          child: Icon(
                            Icons.clear_rounded,
                            size: 16,
                            color: AppColors.onSurfaceVariant,
                          ),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.secondary),
            )
          : items.isEmpty
              ? _EmptySearch(query: _query)
              : Row(
                  children: [
                    // ── 主列表 ──────────────────────────────
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollCtrl,
                        itemCount: items.length,
                        itemBuilder: (ctx, i) {
                          final item = items[i];
                          if (item.isHeader) {
                            return _SectionHeader(
                              letter: item.value,
                              height: _headerH,
                            );
                          }
                          return _BreedTile(
                            breed: item.value,
                            height: _tileH,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              Navigator.of(context).pop(item.value);
                            },
                          );
                        },
                      ),
                    ),

                    // ── 右侧字母索引（无搜索时显示）──────────
                    if (_query.isEmpty)
                      _SideIndex(
                        letters: filteredLetters,
                        onLetterTap: _scrollToLetter,
                      ),
                  ],
                ),
    );
  }
}

// ── 字母段头 ────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String letter;
  final double height;
  const _SectionHeader({required this.letter, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      color: AppColors.surfaceContainerLowest,
      alignment: Alignment.centerLeft,
      child: Text(
        letter,
        style: const TextStyle(
          fontFamily: AppFonts.primary,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: AppColors.secondary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ── 品种条目 ────────────────────────────────────────────────
class _BreedTile extends StatelessWidget {
  final String breed;
  final double height;
  final VoidCallback onTap;
  const _BreedTile({
    required this.breed,
    required this.height,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppColors.outlineVariant.withOpacity(0.25),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Text(
              breed,
              style: const TextStyle(
                fontFamily: AppFonts.primary,
                fontSize: 15,
                color: AppColors.onSurface,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.outlineVariant,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

// ── 右侧字母快速索引 ─────────────────────────────────────────
class _SideIndex extends StatelessWidget {
  final List<String> letters;
  final void Function(String) onLetterTap;
  const _SideIndex({required this.letters, required this.onLetterTap});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragUpdate: (details) {
            // 拖动时根据 Y 坐标定位字母
            final renderBox = ctx.findRenderObject() as RenderBox;
            final localY = renderBox.globalToLocal(details.globalPosition).dy;
            final h = renderBox.size.height;
            final idx = ((localY / h) * letters.length)
                .clamp(0, letters.length - 1)
                .toInt();
            onLetterTap(letters[idx]);
          },
          child: SizedBox(
            width: 24,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: letters.map((l) {
                return Expanded(
                  child: GestureDetector(
                    onTap: () => onLetterTap(l),
                    child: Center(
                      child: Text(
                        l,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.secondary,
                          fontFamily: AppFonts.primary,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}

// ── 搜索无结果 ───────────────────────────────────────────────
class _EmptySearch extends StatelessWidget {
  final String query;
  const _EmptySearch({required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔍', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text(
            '没有找到「$query」',
            style: const TextStyle(
              fontFamily: AppFonts.primary,
              fontSize: 15,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
