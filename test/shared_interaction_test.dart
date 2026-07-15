import 'dart:ui' show SemanticsAction, SemanticsFlag;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petpogo_app/shared/widgets/glass_bottom_nav.dart';
import 'package:petpogo_app/shared/widgets/pressable.dart';

void main() {
  testWidgets('PressableButton exposes one semantic label and handles tap',
      (tester) async {
    var taps = 0;
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PressableButton(
            semanticLabel: '保存',
            onTap: () => taps++,
            child: const Text('保存'),
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('保存'), findsOneWidget);
    await tester.tap(find.text('保存'));
    await tester.pump();
    expect(taps, 1);
    semantics.dispose();
  });

  testWidgets('disabled PressableButton has no tap action', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PressableButton(
            semanticLabel: '保存',
            child: const Text('保存'),
          ),
        ),
      ),
    );

    final node = tester.getSemantics(find.bySemanticsLabel('保存'));
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
    semantics.dispose();
  });

  testWidgets('NavButton exposes selected semantic state', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NavButton(
            item: NavItem(
              icon: Icons.home_outlined,
              activeIcon: Icons.home,
              label: '首页',
            ),
            selected: true,
            onTap: () {},
          ),
        ),
      ),
    );

    final data =
        tester.getSemantics(find.bySemanticsLabel('首页')).getSemanticsData();
    expect(data.hasFlag(SemanticsFlag.isSelected), isTrue);
    expect(data.hasFlag(SemanticsFlag.isButton), isTrue);
    semantics.dispose();
  });
}
