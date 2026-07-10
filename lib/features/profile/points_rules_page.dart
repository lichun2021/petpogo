import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_fonts.dart';
import 'data/points_repository.dart';

class PointsRulesPage extends ConsumerStatefulWidget {
  const PointsRulesPage({super.key});

  @override
  ConsumerState<PointsRulesPage> createState() => _PointsRulesPageState();
}

class _PointsRulesPageState extends ConsumerState<PointsRulesPage> {
  List<Map<String, dynamic>>? _rules;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rules = await ref.read(pointsRepositoryProvider).fetchRules();
      if (!mounted) return;
      setState(() {
        _rules = rules;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = '积分消费规则加载失败，请重试');
    }
  }

  int _asInt(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;

  @override
  Widget build(BuildContext context) {
    final rules = _rules;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('积分消费规则',
            style: TextStyle(
                fontFamily: AppFonts.primary,
                fontSize: 17,
                fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 18, color: AppColors.primary),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text('使用 AI 分析、问诊等功能时会按下列规则扣除积分。',
                        style: TextStyle(
                            fontFamily: AppFonts.primary,
                            fontSize: 12,
                            height: 1.5,
                            color: AppColors.onSurfaceVariant)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (rules == null && _error == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 90),
                child:
                    Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
              )
            else if (_error != null && rules == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 70),
                child: Column(children: [
                  Text(_error!,
                      style: TextStyle(
                          fontFamily: AppFonts.primary,
                          fontSize: 13,
                          color: AppColors.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  TextButton(onPressed: _load, child: const Text('重新加载')),
                ]),
              )
            else if (rules!.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 70),
                child: Text('暂无积分消费规则',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontFamily: AppFonts.primary,
                        fontSize: 13,
                        color: AppColors.onSurfaceVariant)),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: rules.asMap().entries.map((entry) {
                    final rule = entry.value;
                    final basis = rule['unit_basis']?.toString();
                    return Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        border: entry.key < rules.length - 1
                            ? Border(
                                bottom: BorderSide(
                                    color: AppColors.outlineVariant
                                        .withValues(alpha: 0.5)))
                            : null,
                      ),
                      child: Row(children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Icon(Icons.bolt_rounded,
                              size: 20, color: AppColors.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(rule['name']?.toString() ?? '积分消费',
                                  style: TextStyle(
                                      fontFamily: AppFonts.primary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.onSurface)),
                              const SizedBox(height: 3),
                              Text(basis == 'per_unit' ? '按上报数量计费' : '每次调用',
                                  style: TextStyle(
                                      fontFamily: AppFonts.primary,
                                      fontSize: 11,
                                      color: AppColors.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        Text('-${_asInt(rule['unit_points'])}',
                            style: TextStyle(
                                fontFamily: AppFonts.primary,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: AppColors.onSurface)),
                        const SizedBox(width: 3),
                        Text('积分',
                            style: TextStyle(
                                fontFamily: AppFonts.primary,
                                fontSize: 10,
                                color: AppColors.onSurfaceVariant)),
                      ]),
                    );
                  }).toList(),
                ),
              ),
            if (_error != null && rules != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: AppFonts.primary,
                      fontSize: 11,
                      color: AppColors.error)),
            ],
          ],
        ),
      ),
    );
  }
}
