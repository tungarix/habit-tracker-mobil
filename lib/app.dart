import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/providers.dart';
import 'features/habits/habits_screen.dart';
import 'features/monthly/monthly_screen.dart';
import 'features/settings/guncelleme_bolumu.dart';
import 'features/settings/senkron_akisi.dart';
import 'features/settings/settings_screen.dart';
import 'platform/kopru.dart';
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
class Kabuk extends ConsumerStatefulWidget {
  const Kabuk({super.key});

  @override
  ConsumerState<Kabuk> createState() => _KabukState();
}

class _KabukState extends ConsumerState<Kabuk> with WidgetsBindingObserver {
  int _index = 0; // the app opens on Bugün

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final kopru = ref.read(kopruProvider);
    if (kopru == null) return;
    kopru.dosyaDinle(_gelen);
    // Opened with a file (cold start): ask once the first frame is up.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final g = await kopru.bekleyenDosya();
      if (g != null) await _gelen(g);
      if (!mounted) return;
      try {
        await guncellemeIlkAcilis(context, ref);
      } catch (_) {
        // The update check is optional; never block the app.
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // todayProvider's rollover Timer runs on the monotonic clock, which stands still while the
  // phone sleeps: after a night in the background the day would still be yesterday's.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) ref.invalidate(todayProvider);
  }

  /// A .habitsync opened from a file manager / share sheet: validate, confirm, merge.
  Future<void> _gelen(GelenDosya g) async {
    if (!mounted) return;
    final bayt = g.bayt;
    if (bayt == null) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(content: Text(Metin.senkronGecersiz(g.hata ?? ''))),
        );
      return;
    }
    await senkronDosyasiniIceAktar(context, ref, bayt);
  }

  void _push(Widget screen) =>
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => screen));

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
          // These two have no AppBar, so keep their titles out of the status bar.
          const SafeArea(bottom: false, child: MonthlyScreen()),
          const SafeArea(bottom: false, child: StatsScreen()),
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
