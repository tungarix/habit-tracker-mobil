import 'package:flutter/material.dart';

import 'surum.dart';

/// Placeholder shell: the bottom-nav screens (Bugün / Görevler / Aylık / İstatistik) land in Faz 1.
class Kabuk extends StatelessWidget {
  const Kabuk({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Habit Tracker')),
      body: Center(child: Text('Sürüm $uygulamaSurumu')),
    );
  }
}
