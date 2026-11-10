import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'kabuk.dart';

class HabitApp extends StatelessWidget {
  const HabitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Habit Tracker',
      // Mobile default is "follow the system" (PLAN: Tema Sistem / Koyu / Açık).
      themeMode: ThemeMode.system,
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      locale: const Locale('tr'),
      supportedLocales: const [Locale('tr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const Kabuk(),
    );
  }
}
