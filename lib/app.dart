import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/habits/habits_screen.dart';
import 'features/monthly/monthly_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/stats/stats_screen.dart';
import 'features/tasks/tasks_screen.dart';
import 'features/today/today_screen.dart';
import 'shared/tema_modu.dart';
import 'shared/theme.dart';
import 'ui_metin.dart';

class HabitApp extends ConsumerWidget {
  const HabitApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: Metin.uygulamaAdi,
      // Mobile default is "follow the system" (PLAN: Tema Sistem / Koyu / Açık).
      themeMode: ref.watch(temaModuProvider),
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      locale: const Locale('tr'),
      supportedLocales: const [Locale('tr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const Kabuk(),
    );
  }
}

/// Bottom-navigation shell: Bugün / Görevler / Aylık / İstatistik. Habits and
/// Settings open on top of it (pushed from the Bugün menu).
class Kabuk extends StatefulWidget {
  const Kabuk({super.key});

  @override
  State<Kabuk> createState() => _KabukState();
}

class _KabukState extends State<Kabuk> {
  int _index = 0; // the app opens on Bugün

  void _push(Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack keeps each tab's scroll position when switching.
      body: IndexedStack(
        index: _index,
        children: [
          TodayScreen(
            onAliskanliklar: () => _push(const HabitsScreen()),
            onAyarlar: () => _push(const SettingsScreen()),
            onGorevler: () => setState(() => _index = 1),
          ),
          const TasksScreen(),
          const MonthlyScreen(),
          const StatsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: Metin.sekmeBugun,
          ),
          NavigationDestination(
            icon: Icon(Icons.checklist_outlined),
            selectedIcon: Icon(Icons.checklist),
            label: Metin.sekmeGorevler,
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: Metin.sekmeAylik,
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: Metin.sekmeIstatistik,
          ),
        ],
      ),
    );
  }
}
