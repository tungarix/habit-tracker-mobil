// "Bilgisayarla eşitle": QR (ya da yapıştırılan bağlantı) -> Onay 1 -> parmak izine sabitli bağlantı ->
// bilgisayarın verisi kuru çalıştırılır -> Onay 3 (özet) -> yedek, birleştir, telefonun tam durumunu gönder
// -> sonuç. Tasarım: docs/faz4/TASARIM.md A1, A6-A8. Onay 1'e kadar ağ isteği yok.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../data/providers.dart';
import '../../data/sync/sync_export.dart';
import '../../data/sync/sync_format.dart';
import '../../data/sync/sync_import.dart';
import '../../data/sync/sync_parse.dart';
import '../../platform/kopru.dart';
import '../../platform/wifi/istemci.dart';
import '../../platform/wifi/onizle.dart';
import '../../platform/wifi/qr_tarayici.dart';
import '../../platform/wifi/sozlesme.dart';
import '../../surum.dart';
import '../../ui_metin.dart';

typedef WifiIstemciKurucu = WifiIstemci Function(EslestirmeBaglantisi baglanti);

/// Testler sahte istemci verir.
final wifiIstemciProvider = Provider<WifiIstemciKurucu>(
  (ref) =>
      (b) => WifiIstemci(
        b,
        cihazAdi: 'Android telefon',
        uygulamaSurumu: uygulamaSurumu.split('+').first,
      ),
);

/// Birleştirmeden önceki yerel yedeğin yazılacağı klasör. Testler geçici klasör verir.
final wifiYedekKlasoruProvider = FutureProvider<Directory>((ref) async {
  final veri = await ref.watch(dataDirectoryProvider.future);
  return Directory(p.join(veri.path, 'yedekler'));
});

enum _Adim {
  giris,
  tarama,
  izinYok,
  baglaniyor,
  ozet,
  uygulaniyor,
  bitti,
  hata,
}

class WifiEslestirEkrani extends ConsumerStatefulWidget {
  const WifiEslestirEkrani({super.key});

  @override
  ConsumerState<WifiEslestirEkrani> createState() => _WifiEslestirEkraniState();
}

class _WifiEslestirEkraniState extends ConsumerState<WifiEslestirEkrani>
    with WidgetsBindingObserver {
  _Adim _adim = _Adim.giris;
  String _durum = '';
  String? _hataKodu;
  String? _bilgi;
  WifiIstemci? _istemci;
  Uint8List? _gelen;
  SyncReport? _onizleme;
  SyncReport? _telefonRapor;
  MasaustuRaporu? _masaustuRapor;
  String? _masaustuHata;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_istemci?.bitir('cancel'));
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Özet ekranında beklerken uygulama arka plana giderse oturum kapanır (jeton/anahtar bellekte kalmasın).
    if (state == AppLifecycleState.paused && _adim == _Adim.ozet) {
      unawaited(_istemci?.bitir('cancel'));
      _git(_Adim.giris, bilgi: Metin.wifiIptalEkran);
    }
  }

  void _git(_Adim a, {String? durum, String? hata, String? bilgi}) {
    if (!mounted) return;
    setState(() {
      _adim = a;
      if (durum != null) _durum = durum;
      _hataKodu = hata;
      _bilgi = bilgi;
    });
  }

  void _hatayaGit(String kod) => _git(_Adim.hata, hata: kod);

  // ---- Giriş: tarama ya da yapıştırma ----

  Future<bool> _wifiMi() async {
    final k = ref.read(kopruProvider);
    if (k == null) return true; // köprü yok (test / Android dışı)
    try {
      return await k.wifiBagli();
    } catch (_) {
      return true; // ağ türü okunamadı: asıl bağlantı denemesi hatayı verir
    }
  }

  Future<void> _tara() async {
    if (!await _wifiMi()) return _hatayaGit('wifi_degil');
    _git(_Adim.tarama);
  }

  Future<void> _yapistir() async {
    if (!await _wifiMi()) return _hatayaGit('wifi_degil');
    if (!mounted) return;
    final metin = await showDialog<String>(
      context: context,
      builder: (_) => const _YapistirPenceresi(),
    );
    if (metin != null) await _qrIsle(metin);
  }

  Future<void> _qrIsle(String metin) async {
    final EslestirmeBaglantisi b;
    try {
      b = qrCoz(metin);
    } on WifiHatasi catch (e) {
      return _hatayaGit(e.kod);
    }
    if (!mounted) return;
    // Onay 1: bu noktaya kadar ağ isteği yok.
    final evet = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text(Metin.wifiOnay1Baslik),
        content: Text(
          Metin.wifiOnay1(
            b.ad,
            b.adresler,
            b.suresiDolmusOlabilir(DateTime.now()),
          ),
        ),
        actions: [
          TextButton(
            style: _buyukDugme,
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(Metin.wifiVazgec),
          ),
          FilledButton(
            style: _buyukDugme,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(Metin.wifiBaglan),
          ),
        ],
      ),
    );
    if (evet != true) return _git(_Adim.giris, bilgi: Metin.wifiVazgecildi);
    await _baglan(b);
  }

  // ---- Bağlantı ve önizleme ----

  Future<void> _baglan(EslestirmeBaglantisi b) async {
    _git(_Adim.baglaniyor, durum: Metin.wifiBaglaniyor);
    final i = ref.read(wifiIstemciProvider)(b);
    _istemci = i;
    try {
      await i.oturumAc();
      _git(_Adim.baglaniyor, durum: Metin.wifiVeriAliniyor);
      final bayt = await i.durumAl();
      try {
        parseSync(bayt);
      } on SyncVersionException {
        throw const WifiHatasi('senkron_surumu');
      } on SyncException {
        throw const WifiHatasi('senkron_bozuk_yerel');
      }
      final rapor = await senkronOnizle(ref.read(databaseProvider), bayt);
      _gelen = bayt;
      _onizleme = rapor;
      _git(_Adim.ozet);
    } on WifiHatasi catch (e) {
      await i.bitir('cancel');
      _hatayaGit(e.kod);
    } catch (_) {
      await i.bitir('cancel');
      _hatayaGit('uygulama_hatasi');
    }
  }

  Future<void> _vazgec() async {
    await _istemci?.bitir('cancel');
    _gelen = null;
    _git(_Adim.giris, bilgi: Metin.wifiVazgecildi);
  }

  // ---- Birleştir ve gönder ----

  Future<void> _yedekAl() async {
    try {
      final klasor = await ref.read(wifiYedekKlasoruProvider.future);
      await klasor.create(recursive: true);
      final damga = DateTime.now()
          .toIso8601String()
          .replaceAll(RegExp(r'[^0-9]'), '')
          .substring(0, 14);
      final hedef = File(p.join(klasor.path, 'aktenak-sync-$damga.json'));
      final gecici = File('${hedef.path}.tmp');
      await gecici.writeAsString(
        await ref.read(backupRepositoryProvider).exportJson(),
        flush: true,
      );
      await gecici.rename(hedef.path);
    } catch (_) {
      throw const WifiHatasi('yedek_alinamadi');
    }
  }

  Future<void> _birlestirVeGonder() async {
    final i = _istemci!;
    final db = ref.read(databaseProvider);
    _git(_Adim.uygulaniyor, durum: Metin.wifiUygulaniyor);
    var birlesti = false;
    try {
      await _yedekAl();
      _telefonRapor = await importSyncBytes(db, _gelen!);
      birlesti = true;
      ref.invalidate(dayStartHourProvider);
      final tam = utf8.encode(await exportSync(db, deviceName: 'Telefon'));
      _masaustuRapor = await i.durumGonder(tam);
      _masaustuHata = null;
    } on WifiHatasi catch (e) {
      if (!birlesti) {
        await i.bitir('cancel');
        return _hatayaGit(e.kod);
      }
      _masaustuHata = e.kod;
    } on SyncException {
      await i.bitir('cancel');
      return _hatayaGit('senkron_bozuk_yerel');
    } catch (_) {
      if (!birlesti) {
        await i.bitir('cancel');
        return _hatayaGit('uygulama_hatasi');
      }
      _masaustuHata = 'uygulama_hatasi';
    }
    i.kapat();
    _gelen = null;
    _git(_Adim.bitti);
  }

  // ---- Arayüz ----

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _adim != _Adim.uygulaniyor,
      child: Scaffold(
        appBar: AppBar(title: const Text(Metin.wifiBaslik)),
        body: _adim == _Adim.tarama
            ? _taramaGorunumu()
            : SafeArea(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: switch (_adim) {
                    _Adim.giris => _giris(),
                    _Adim.izinYok => _izinYok(),
                    _Adim.baglaniyor || _Adim.uygulaniyor => _bekle(),
                    _Adim.ozet => _ozet(),
                    _Adim.bitti => _bitti(),
                    _Adim.hata => _hata(),
                    _Adim.tarama => const [],
                  },
                ),
              ),
      ),
    );
  }

  List<Widget> _giris() => [
    if (_bilgi != null)
      Semantics(
        liveRegion: true,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(_bilgi!),
        ),
      ),
    const Text(Metin.wifiAnlatim),
    const SizedBox(height: 24),
    FilledButton.icon(
      style: _buyukDugme,
      onPressed: _tara,
      icon: const Icon(Icons.qr_code_scanner),
      label: const Text(Metin.wifiQrTara),
    ),
    const SizedBox(height: 12),
    OutlinedButton.icon(
      style: _buyukDugme,
      onPressed: _yapistir,
      icon: const Icon(Icons.paste),
      label: const Text(Metin.wifiBaglantiYapistir),
    ),
  ];

  Widget _taramaGorunumu() => Column(
    children: [
      Expanded(
        child: ref.watch(qrTarayiciProvider)(
          context,
          bulundu: (m) {
            _git(_Adim.giris);
            unawaited(_qrIsle(m));
          },
          izinYok: () => _git(_Adim.izinYok),
          hata: () => _hatayaGit('kamera_izni'),
        ),
      ),
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(Metin.wifiTaramaYonerge),
              const SizedBox(height: 12),
              OutlinedButton(
                style: _buyukDugme,
                onPressed: () => _git(_Adim.giris),
                child: const Text(Metin.wifiVazgec),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  List<Widget> _izinYok() => [
    Semantics(
      liveRegion: true,
      header: true,
      child: Text(
        Metin.wifiIzinBaslik,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    ),
    const SizedBox(height: 8),
    const Text(Metin.wifiIzinAciklama),
    const SizedBox(height: 24),
    FilledButton(
      style: _buyukDugme,
      onPressed: _tara,
      child: const Text(Metin.wifiYenidenDene),
    ),
    const SizedBox(height: 12),
    if (ref.read(kopruProvider) != null) ...[
      OutlinedButton(
        style: _buyukDugme,
        onPressed: () => ref.read(kopruProvider)!.uygulamaAyarlariniAc(),
        child: const Text(Metin.wifiAyarlariAc),
      ),
      const SizedBox(height: 12),
    ],
    OutlinedButton(
      style: _buyukDugme,
      onPressed: _yapistir,
      child: const Text(Metin.wifiBaglantiYapistir),
    ),
  ];

  List<Widget> _bekle() => [
    const SizedBox(height: 32),
    const Center(child: CircularProgressIndicator()),
    const SizedBox(height: 24),
    Semantics(
      liveRegion: true,
      child: Text(_durum, textAlign: TextAlign.center),
    ),
  ];

  List<Widget> _ozet() {
    final r = _onizleme!;
    final text = Theme.of(context).textTheme;
    final turler = <String, SyncCounts>{
      'habit': r.habit,
      'entry': r.entry,
      'mood': r.mood,
      'task': r.task,
      'session': r.session,
    };
    final kirilim = <String>[
      for (final e in turler.entries)
        if (e.value.added + e.value.updated + e.value.deleted > 0)
          '${_tur(e.key)}: ${e.value.added} / ${e.value.updated} / ${e.value.deleted}',
    ];
    Widget sayi(String ad, int n) => Expanded(
      child: Semantics(
        label: '$ad: $n',
        excludeSemantics: true,
        child: Column(
          children: [
            Text('$n', style: text.headlineMedium),
            Text(ad, style: text.bodySmall, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
    return [
      Semantics(
        header: true,
        child: Text(Metin.wifiOzetBaslik, style: text.titleMedium),
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          sayi(Metin.wifiEklenecek, r.added),
          sayi(Metin.wifiGuncellenecek, r.updated),
          sayi(Metin.wifiSilinecek, r.deleted),
        ],
      ),
      const SizedBox(height: 16),
      if (!r.changed) const Text(Metin.wifiDegisiklikYok),
      for (final k in kirilim)
        Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(k)),
      if (r.deleted > 0) ...[
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.warning_amber,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 8),
            const Expanded(child: Text(Metin.wifiSilmeUyari)),
          ],
        ),
      ],
      if (r.deleted >= 50) ...[
        const SizedBox(height: 8),
        const Text(Metin.wifiCokSilme),
      ],
      const SizedBox(height: 16),
      const Text(Metin.wifiGonderSonra),
      const SizedBox(height: 24),
      OutlinedButton(
        style: _buyukDugme,
        autofocus: r.deleted > 0,
        onPressed: _vazgec,
        child: const Text(Metin.wifiVazgec),
      ),
      const SizedBox(height: 12),
      FilledButton(
        style: _buyukDugme,
        onPressed: _birlestirVeGonder,
        child: Text(r.changed ? Metin.wifiBirlestirGonder : Metin.wifiGonder),
      ),
    ];
  }

  String _tur(String t) => Metin.wifiTur(t, 0).replaceFirst('0 ', '');

  List<Widget> _bitti() {
    final t = _telefonRapor!;
    final m = _masaustuRapor;
    final yarim = m == null;
    // İstek bilgisayara ulaşmış olabilir: "değişmedi" demek yanlış olur.
    final belirsiz = yarim && Metin.wifiSonucBelirsizMi(_masaustuHata);
    return [
      Semantics(
        liveRegion: true,
        header: true,
        child: Text(
          !yarim
              ? Metin.wifiBitti
              : belirsiz
              ? Metin.wifiBelirsizBaslik
              : Metin.wifiYarimBaslik,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      const SizedBox(height: 12),
      Text(Metin.wifiTelefonSonuc(t.added, t.updated, t.deleted)),
      const SizedBox(height: 8),
      if (m != null)
        Text(Metin.wifiBilgisayarSonuc(m.eklenen, m.guncellenen, m.silinen)),
      if (yarim) ...[
        Text(belirsiz ? Metin.wifiBelirsizTelefon : Metin.wifiYarimTelefon),
        const SizedBox(height: 8),
        Text(Metin.wifiHata(_masaustuHata ?? 'uygulama_hatasi')),
      ],
      const SizedBox(height: 24),
      FilledButton(
        style: _buyukDugme,
        onPressed: () => Navigator.of(context).maybePop(),
        child: const Text(Metin.wifiTamam),
      ),
    ];
  }

  List<Widget> _hata() => [
    Semantics(
      liveRegion: true,
      header: true,
      child: Text(
        Metin.wifiHataBaslik,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    ),
    const SizedBox(height: 12),
    Text(Metin.wifiHata(_hataKodu ?? '')),
    const SizedBox(height: 24),
    FilledButton(
      style: _buyukDugme,
      onPressed: () => _git(_Adim.giris),
      child: const Text(Metin.wifiYenidenDene),
    ),
  ];
}

final _buyukDugme = ButtonStyle(
  minimumSize: WidgetStatePropertyAll(const Size(64, 48)),
);

/// Bağlantıyı yapıştırma penceresi (kamerasız cihaz, izin reddi, TalkBack).
class _YapistirPenceresi extends StatefulWidget {
  const _YapistirPenceresi();

  @override
  State<_YapistirPenceresi> createState() => _YapistirPenceresiState();
}

class _YapistirPenceresiState extends State<_YapistirPenceresi> {
  final _alan = TextEditingController();

  @override
  void dispose() {
    _alan.dispose();
    super.dispose();
  }

  Future<void> _panodan() async {
    final v = await Clipboard.getData(Clipboard.kTextPlain);
    if (v?.text != null) _alan.text = v!.text!;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(Metin.wifiBaglantiYapistir),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _alan,
            autofocus: true,
            maxLines: 3,
            minLines: 1,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: Metin.wifiBaglantiAlani,
              hintText: Metin.wifiBaglantiIpucu,
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            style: _buyukDugme,
            onPressed: _panodan,
            icon: const Icon(Icons.content_paste),
            label: const Text(Metin.wifiBaglantiYapistir),
          ),
        ],
      ),
      actions: [
        TextButton(
          style: _buyukDugme,
          onPressed: () => Navigator.pop(context),
          child: const Text(Metin.wifiVazgec),
        ),
        FilledButton(
          style: _buyukDugme,
          onPressed: () => Navigator.pop(context, _alan.text),
          child: const Text(Metin.wifiBaglantiTamam),
        ),
      ],
    );
  }
}
