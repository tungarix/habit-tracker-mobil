// Bridge to Android: MainActivity's method channel (no extra plugin).
//  - agTuru: active network kind ('wifi' | 'mobil' | 'yok'),
//  - kurulumIzniVar / kurulumIzniAc: "install unknown apps" permission,
//  - apkKur: installs a verified APK through PackageInstaller,
//  - kurulumSonucu (Kotlin -> Dart): install session result,
//  - bekleyenDosya / dosyaGeldi: a .habitsync opened from outside the app ("Open with" / Share).
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A file handed to the app from outside: the bytes, or a readable error.
class GelenDosya {
  const GelenDosya.bayt(Uint8List this.bayt) : hata = null;
  const GelenDosya.hata(String this.hata) : bayt = null;
  final Uint8List? bayt;
  final String? hata;
}

/// Null in tests and on non-Android hosts; main() overrides it with [AndroidKopru].
final kopruProvider = Provider<Kopru?>((ref) => null);

abstract class Kopru {
  /// Active network kind: 'wifi' (unmetered) | 'mobil' (metered) | 'yok'.
  Future<String> agTuru();

  /// Whether this app may install packages (Android 8+ "install unknown apps").
  Future<bool> kurulumIzniVar();

  /// Opens the system screen for that permission; the user grants it and comes back.
  Future<void> kurulumIzniAc();

  /// Installs a verified APK. Kotlin accepts only an APK inside the app cache dir, with the
  /// same package name and a higher versionCode; otherwise throws a `PlatformException`.
  /// Success = the system install dialog opened.
  Future<void> apkKur(String yol);

  /// PackageInstaller result (status code + message); 0 = success.
  void kurulumSonucuDinle(void Function(int durum, String? mesaj) f);

  /// The file the app was opened with (cold start), once; null if none.
  Future<GelenDosya?> bekleyenDosya();

  /// A file that arrives while the app is already running.
  void dosyaDinle(void Function(GelenDosya) f);
}

class AndroidKopru implements Kopru {
  AndroidKopru()
    : _kanal = const MethodChannel('com.aktenak.habit_tracker/kopru');
  final MethodChannel _kanal;

  void Function(int, String?)? _kurulumF;
  void Function(GelenDosya)? _dosyaF;

  // One handler serves every Kotlin -> Dart call (setMethodCallHandler keeps only the last).
  void _isleyiciKur() => _kanal.setMethodCallHandler((c) async {
    if (c.method == 'dosyaGeldi') {
      final g = _coz(c.arguments);
      if (g != null) _dosyaF?.call(g);
    } else if (c.method == 'kurulumSonucu' && c.arguments is Map) {
      final m = c.arguments as Map;
      final d = m['durum'];
      if (d is int) {
        _kurulumF?.call(d, m['mesaj'] is String ? m['mesaj'] as String : null);
      }
    }
  });

  @override
  Future<String> agTuru() async =>
      (await _kanal.invokeMethod<String>('agTuru')) ?? 'yok';

  @override
  Future<bool> kurulumIzniVar() async =>
      (await _kanal.invokeMethod<bool>('kurulumIzniVar')) ?? false;

  @override
  Future<void> kurulumIzniAc() => _kanal.invokeMethod<void>('kurulumIzniAc');

  @override
  Future<void> apkKur(String yol) => _kanal.invokeMethod<void>('apkKur', yol);

  @override
  void kurulumSonucuDinle(void Function(int durum, String? mesaj) f) {
    _kurulumF = f;
    _isleyiciKur();
  }

  @override
  Future<GelenDosya?> bekleyenDosya() async =>
      _coz(await _kanal.invokeMethod<Object?>('bekleyenDosya'));

  @override
  void dosyaDinle(void Function(GelenDosya) f) {
    _dosyaF = f;
    _isleyiciKur();
  }

  static GelenDosya? _coz(Object? o) {
    if (o is! Map) return null;
    final bayt = o['bayt'], hata = o['hata'];
    if (bayt is Uint8List) return GelenDosya.bayt(bayt);
    if (hata is String) return GelenDosya.hata(hata);
    return null;
  }
}
