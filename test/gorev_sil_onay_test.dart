import 'package:aktenak_habit_tracker/data/database/database.dart';
import 'package:aktenak_habit_tracker/data/providers.dart';
import 'package:aktenak_habit_tracker/features/tasks/task_edit_dialog.dart';
import 'package:aktenak_habit_tracker/ui_metin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';
import 'ui_yardimci.dart';

void main() {
  testWidgets('Görev penceresinde Sil onay ister; İptal korur, onay siler', (
    tester,
  ) async {
    telefonBoyutu(tester, yukseklik: 1200);
    final db = await bellekDb();
    final id = (await tester.runAsync(
      () => db.insertTask(TasksCompanion.insert(title: 'Sil beni')),
    ))!;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => TaskEditDialog.show(
                context,
                existing: testTask(id: id, title: 'Sil beni'),
              ),
              child: const Text('aç'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, Metin.sil));
    await tester.pumpAndSettle();
    expect(find.text(Metin.gorevSilBaslik), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, Metin.iptal).last);
    await tester.pumpAndSettle();
    expect((await tester.runAsync(db.getAllTasks))!.length, 1);

    await tester.tap(find.widgetWithText(TextButton, Metin.sil));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, Metin.sil));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect((await tester.runAsync(db.getAllTasks))!, isEmpty);
  });
}
