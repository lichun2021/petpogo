import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petpogo_app/features/community/widgets/community_category_bar.dart';

void main() {
  for (final scale in [1.0, 1.5, 2.0]) {
    testWidgets('Category labels remain inside bar at scale $scale',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      int selected = -1;
      await tester.pumpWidget(MaterialApp(
          home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Scaffold(
            body: Column(children: [
          CommunityCategoryBar(
              labels: const ['全部', '狗', '猫', '其他宠物'],
              selected: 0,
              onSelected: (value) => selected = value)
        ])),
      )));
      final bar = tester.getRect(find.byType(CommunityCategoryBar));
      final text = tester.getRect(find.text('全部'));
      expect(bar.height, greaterThanOrEqualTo(text.height + 24));
      expect(text.top, greaterThanOrEqualTo(bar.top));
      expect(text.bottom, lessThanOrEqualTo(bar.bottom));
      await tester.tap(find.text('狗'));
      expect(selected, 1);
      expect(tester.takeException(), isNull);
    });
  }
}
