import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../data/providers.dart';
import '../../data/sync/sync_export.dart';
import '../../data/sync/sync_format.dart';
import '../../platform/yedek_denetimi.dart';
import '../../shared/tema_modu.dart';
import 'backup_file_service.dart';
import 'guncelleme_bolumu.dart';
import 'reminder_settings.dart';
import 'senkron_akisi.dart';
import 'senkron_dosya_servisi.dart';
import 'wifi_eslestir_ekrani.dart';
import '../../ui_metin.dart';

enum _ImportMode { merge, replace }

/// "Yedek & Ayarlar": export / import, auto-backup status, theme, day start
/// and the evening-reminder time.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with WidgetsBindingObserver {
  bool _busy = false;
  bool _reminderLoaded = false;
  int? _reminderHour;
  bool _reminderIzinVar = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _izniOku();
    ref.read(reminderSettingsProvider).readHour().then((h) {
      if (mounted) {
        setState(() {
          _reminderHour = h;
          _reminderLoaded = true;
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // The user may grant the permission in system settings and come back.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _izniOku();
  }

  Future<void> _izniOku() async {
    final izin = await ref.read(reminderSettingsProvider).izinVar();
    if (mounted && izin != _reminderIzinVar) setState(() => _reminderIzinVar = izin);
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final repo = ref.read(backupRepositoryProvider);
      final json = await repo.exportJson();
      await ref
          .read(backupFileServiceProvider)
          .shareBackup(json, repo.suggestedFileName());
    } catch (e) {
      _toast(Metin.disaAktarmaHata('$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    setState(() => _busy = true);
    try {
      final content = await ref.read(backupFileServiceProvider).pickBackup();
      if (content == null) return; // cancelled
      yedekAlanlariniDenetle(content); // before anything is asked or changed
      final mode = await _askMergeOrReplace();
      if (mode == null) return;
      final r = await ref
          .read(backupRepositoryProvider)
          .importJson(content, replace: mode == _ImportMode.replace);
      _toast(
        Metin.iceAktarildi(r.habits, r.entries, r.moods, r.tasks, r.sessions),
      );
    } on FormatException catch (e) {
      _toast(Metin.iceAktarmaHata(e.message));
    } catch (e) {
      _toast(Metin.iceAktarmaHata('$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _syncExport() async {
    setState(() => _busy = true);
    try {
      final text = await exportSync(
        ref.read(databaseProvider),
        deviceName: 'Telefon',
      );
      await ref.read(senkronDosyaServisiProvider).paylas(text, syncFileName());
    } catch (e) {
      _toast(Metin.disaAktarmaHata('$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _syncImport() async {
    setState(() => _busy = true);
    try {
      final bytes = await ref.read(senkronDosyaServisiProvider).sec();
      if (bytes == null || !mounted) return; // cancelled
      await senkronDosyasiniIceAktar(context, ref, bytes);
    } on SyncException catch (e) {
      _toast(Metin.senkronGecersiz(e.message));
    } catch (e) {
      _toast(Metin.iceAktarmaHata('$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<_ImportMode?> _askMergeOrReplace() {
    return showDialog<_ImportMode>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(Metin.iceAktarModuBaslik),
        content: const SingleChildScrollView(
          child: Text(Metin.iceAktarModuAciklama),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(Metin.iptal),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _ImportMode.merge),
            child: const Text(Metin.birlestir),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, _ImportMode.replace),
            child: const Text(Metin.tamamenDegistir),
          ),
        ],
      ),
    );
  }

  Future<void> _setReminder(int? hour) async {
    setState(() => _reminderHour = hour);
    await ref.read(reminderSettingsProvider).writeHour(hour);
    await _izniOku();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final dim = Theme.of(context).colorScheme.onSurfaceVariant;
    return Scaffold(
      appBar: AppBar(title: const Text(Metin.ayarlarBaslik)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Text(Metin.veriYalnizBuTelefonda, style: TextStyle(color: dim)),
            const SizedBox(height: 16),
            _ActionCard(
              icon: Icons.upload_file,
              title: Metin.disaAktar,
              subtitle: Metin.disaAktarAciklama,
              onTap: _busy ? null : _export,
            ),
            const SizedBox(height: 8),
            _ActionCard(
              icon: Icons.download,
              title: Metin.iceAktar,
              subtitle: Metin.iceAktarAciklama,
              onTap: _busy ? null : _import,
            ),
            if (_busy) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ],
            const SizedBox(height: 24),
            Semantics(
              header: true,
              child: Text(Metin.senkronBaslik, style: text.titleSmall),
            ),
            const SizedBox(height: 8),
            _ActionCard(
              icon: Icons.qr_code_scanner,
              title: Metin.wifiGiris,
              subtitle: Metin.wifiGirisAciklama,
              onTap: _busy
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const WifiEslestirEkrani(),
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            _ActionCard(
              icon: Icons.computer,
              title: Metin.senkronDisaAktar,
              subtitle: Metin.senkronDisaAktarAciklama,
              onTap: _busy ? null : _syncExport,
            ),
            const SizedBox(height: 8),
            _ActionCard(
              icon: Icons.sync,
              title: Metin.senkronIceAktar,
              subtitle: Metin.senkronIceAktarAciklama,
              onTap: _busy ? null : _syncImport,
            ),
            const SizedBox(height: 24),
            Semantics(
              header: true,
              child: Text(Metin.otomatikYedekBaslik, style: text.titleSmall),
            ),
            const SizedBox(height: 8),
            const _AutoBackupCard(),
            const GuncellemeBolumu(),
            const SizedBox(height: 24),
            Semantics(
              header: true,
              child: Text(Metin.gorunumBaslik, style: text.titleSmall),
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  const _ThemeRow(),
                  const Divider(height: 1),
                  const _DayStartRow(),
                  const Divider(height: 1),
                  _ReminderRow(
                    loaded: _reminderLoaded,
                    hour: _reminderHour,
                    izinVar: _reminderIzinVar,
                    onChanged: _setReminder,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeRow extends ConsumerWidget {
  const _ThemeRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(temaModuProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(Metin.tema),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              style: const ButtonStyle(
                minimumSize: WidgetStatePropertyAll(Size(0, 48)),
              ),
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text(Metin.temaSistem),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text(Metin.temaAcik),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text(Metin.temaKoyu),
                ),
              ],
              selected: {mode},
              onSelectionChanged: (s) =>
                  ref.read(temaModuProvider.notifier).set(s.first),
            ),
          ),
        ],
      ),
    );
  }
}

String _hh(int h) => '${h.toString().padLeft(2, '0')}:00';

class _DayStartRow extends ConsumerWidget {
  const _DayStartRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hour = ref.watch(dayStartHourProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text(Metin.gunBaslangici)),
              Text(
                _hh(hour),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          Slider(
            key: const ValueKey('gun-baslangic-slider'),
            value: hour.toDouble(),
            min: 0,
            max: 12,
            divisions: 12,
            label: _hh(hour),
            semanticFormatterCallback: (v) =>
                Metin.gunBaslangiciSesli(v.round()),
            onChanged: (v) =>
                ref.read(dayStartHourProvider.notifier).set(v.round()),
          ),
          Text(
            Metin.gunBaslangiciAciklama(_hh(hour)),
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ReminderRow extends StatelessWidget {
  final bool loaded;
  final int? hour;
  final bool izinVar;
  final ValueChanged<int?> onChanged;
  const _ReminderRow({
    required this.loaded,
    required this.hour,
    required this.izinVar,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final h = hour;
    return Column(
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.notifications_outlined),
          title: const Text(Metin.aksamHatirlaticisi),
          subtitle: Text(
            h == null
                ? Metin.hatirlaticiKapali
                : !izinVar
                ? Metin.hatirlaticiIzinYok
                : Metin.hatirlaticiAcik(_hh(h)),
          ),
          value: h != null,
          onChanged: loaded
              ? (on) => onChanged(on ? AppConstants.defaultReminderHour : null)
              : null,
        ),
        if (h != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Slider(
                    key: const ValueKey('hatirlatici-slider'),
                    value: h.clamp(17, 23).toDouble(),
                    min: 17,
                    max: 23,
                    divisions: 6,
                    label: _hh(h),
                    semanticFormatterCallback: (v) =>
                        Metin.hatirlaticiSesli(v.round()),
                    onChanged: (v) => onChanged(v.round()),
                  ),
                ),
                SizedBox(
                  width: 56,
                  child: Text(_hh(h), textAlign: TextAlign.end),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Auto-backup status plus the "these never leave the phone" warning.
class _AutoBackupCard extends ConsumerWidget {
  const _AutoBackupCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latest = ref.watch(latestAutoBackupProvider).value;
    final scheme = Theme.of(context).colorScheme;
    final status = latest == null
        ? Metin.otomatikYedekYok
        : Metin.sonYedek(DateFormat('d MMMM y, HH:mm', 'tr').format(latest));
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text(Metin.otomatikYedek),
            subtitle: Text('${Metin.otomatikYedekAciklama} $status'),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: scheme.onErrorContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    Metin.yedekUyari,
                    style: TextStyle(color: scheme.onErrorContainer),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        minVerticalPadding: 12,
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          child: Icon(icon, color: scheme.onPrimaryContainer),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
