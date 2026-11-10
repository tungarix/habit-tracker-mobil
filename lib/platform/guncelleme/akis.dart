// The user-triggered update flow: network rule -> install permission -> download + verify -> re-check -> installer.
// Throws GuncellemeHatasi (ag_yok | wifi_gerek | izin_yok | ozet_uyusmuyor | ...) ; success = system install dialog opened.
import 'ag.dart';
import 'guncelleyici.dart';
import 'kur.dart';
import 'saf.dart';
import '../kopru.dart';

Future<void> guncellemeKur(
  Guncelleyici g,
  Kopru kopru,
  Yayin y, {
  required Future<bool> Function() mobilOnayi,
  void Function(int alinan)? ilerleme,
}) async {
  final tur = await kopru.agTuru();
  final yalnizWifi = g.ayarlar.yalnizWifi;
  var izinli = indirmeIzinli(tur, yalnizWifi: yalnizWifi);
  if (!izinli && tur == 'mobil') {
    if (!await mobilOnayi()) throw const GuncellemeHatasi('wifi_gerek');
    izinli = indirmeIzinli(tur, yalnizWifi: yalnizWifi, mobilOnayi: true);
  }
  if (!izinli) throw const GuncellemeHatasi('ag_yok');
  if (!await kopru.kurulumIzniVar()) {
    await kopru.kurulumIzniAc();
    throw const GuncellemeHatasi('izin_yok');
  }
  final dosya = await g.hazirla(y, ilerleme: ilerleme);
  // The file may have changed since the download check; re-hash right before handing it over.
  final ozet = await Guncelleyici.dosyaOzeti(dosya);
  if (ozet != g.sonDogrulananOzet) {
    try {
      await dosya.delete();
    } catch (_) {
      // an undeletable file is still never installed
    }
    throw const GuncellemeHatasi('ozet_uyusmuyor', 'kurulum öncesi');
  }
  await kopru.apkKur(dosya.path, ozet);
}
