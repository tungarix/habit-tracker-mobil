// Settings section + first-launch consent for the in-app updater.
// The section is hidden when there is no platform bridge (tests / non-Android hosts).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../platform/guncelleme/ag.dart';
import '../../platform/guncelleme/akis.dart';
import '../../platform/guncelleme/guncelleyici.dart';
import '../../platform/guncelleme/kur.dart';
import '../../platform/kopru.dart';
import '../../surum.dart';
import '../../ui_metin.dart';

/// null when there is no bridge to install through.
final guncelleyiciProvider = FutureProvider<Guncelleyici?>((ref) async {
  if (ref.watch(kopruProvider) == null) return null;
  return guncelleyiciKur(
    ref.watch(databaseProvider),
    uygulamaSurumu.split('+').first,
  );
});

/// First launch: ask once whether to check for updates (no network until
/// answered), then run the daily check.
Future<void> guncellemeIlkAcilis(BuildContext context, WidgetRef ref) async {
  final g = await ref.read(guncelleyiciProvider.future);
  if (g == null || !context.mounted) return;
  if (g.denetim == null) {
    final evet = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text(Metin.guncellemeIlkBaslik),
        content: const Text(Metin.guncellemeIlkGovde),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(Metin.guncellemeIlkHayir),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(Metin.guncellemeIlkEvet),
          ),
        ],
      ),
    );
    await g.denetimYaz(evet ?? false);
  }
  await g.otomatikAdim();
}

class GuncellemeBolumu extends ConsumerStatefulWidget {
  const GuncellemeBolumu({super.key});

  @override
  ConsumerState<GuncellemeBolumu> createState() => _GuncellemeBolumuState();
}

class _GuncellemeBolumuState extends ConsumerState<GuncellemeBolumu> {
  String? _durum; // transient status / error line
  bool _mesgul = false;

  Future<void> _calis(Future<void> Function() gorev) async {
    setState(() => _mesgul = true);
    try {
      await gorev();
    } on GuncellemeHatasi catch (e) {
      _durum = Metin.guncellemeHata(e.kod);
    } catch (_) {
      _durum = Metin.guncellemeHata('bilinmiyor');
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  Future<bool> _mobilSor() async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text(Metin.guncellemeMobilBaslik),
          content: const Text(Metin.guncellemeMobilGovde),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(Metin.iptal),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(Metin.guncellemeMobilEvet),
            ),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    final g = ref.watch(guncelleyiciProvider).value;
    final kopru = ref.watch(kopruProvider);
    if (g == null || kopru == null) return const SizedBox.shrink();
    final teklif = g.teklif;
    final satir =
        _durum ??
        (g.hataKodu != null
            ? Metin.guncellemeHata(g.hataKodu!)
            : teklif != null
            ? Metin.guncellemeHazir(teklif.surum)
            : g.sonDenetim != null
            ? Metin.guncellemeGuncel
            : Metin.guncellemeHic);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Semantics(
          header: true,
          child: Text(
            Metin.guncellemeBaslik,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text(Metin.guncellemeDenetle),
                subtitle: const Text(Metin.guncellemeDenetleAciklama),
                value: g.denetim == true,
                onChanged: _mesgul
                    ? null
                    : (v) => _calis(() => g.denetimYaz(v)),
              ),
              SwitchListTile(
                title: const Text(Metin.guncellemeYalnizWifi),
                value: g.ayarlar.yalnizWifi,
                onChanged: _mesgul
                    ? null
                    : (v) => _calis(() => g.ayarlar.yalnizWifiYaz(v)),
              ),
              ListTile(
                title: Text(_mesgul ? Metin.guncellemeDenetleniyor : satir),
                trailing: TextButton(
                  onPressed: _mesgul
                      ? null
                      : () => _calis(() async {
                          _durum = null;
                          await g.denetle();
                        }),
                  child: const Text(Metin.guncellemeSimdiDenetle),
                ),
              ),
              if (teklif != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _mesgul
                          ? null
                          : () => _calis(() async {
                              _durum = Metin.guncellemeIndiriliyor;
                              await guncellemeKur(
                                g,
                                kopru,
                                teklif,
                                mobilOnayi: _mobilSor,
                              );
                              _durum = Metin.guncellemeKurulumAcildi;
                            }),
                      child: const Text(Metin.guncellemeIndirKur),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
