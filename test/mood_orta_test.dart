import 'package:aktenak_habit_tracker/core/enums.dart';
import 'package:aktenak_habit_tracker/features/today/widgets/mood_card.dart';
import 'package:aktenak_habit_tracker/shared/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('altı düğmeli seçici 360dp\'de taşmaz, sıra Üzgün-Orta-Memnun, 48dp', (t) async {
    t.view.physicalSize = const Size(360, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: MoodPicker(selected: Mood.orta, onTap: (_) {}),
        ),
      ),
    ));
    expect(t.takeException(), isNull);
    final icons = t.widgetList<Icon>(find.byType(Icon)).map((i) => i.icon).toList();
    expect(icons.length, 6);
    expect(icons.indexOf(Icons.sentiment_neutral_outlined),
        icons.indexOf(Icons.sentiment_dissatisfied_outlined) + 1);
    expect(icons.indexOf(Icons.sentiment_satisfied_outlined),
        icons.indexOf(Icons.sentiment_neutral_outlined) + 1);
    for (final e in find.byType(InkWell).evaluate()) {
      final s = t.getSize(find.byWidget(e.widget));
      expect(s.width, greaterThanOrEqualTo(48));
      expect(s.height, greaterThanOrEqualTo(48));
    }
  });
}
