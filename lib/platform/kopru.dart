// Bridge to Android: MainActivity's method channel (no extra plugin).
//  - agTuru: active network kind ('wifi' | 'mobil' | 'yok'),
//  - kurulumIzniVar / kurulumIzniAc: "install unknown apps" permission,
//  - apkKur: installs a verified APK through PackageInstaller,
//  - kurulumSonucu (Kotlin -> Dart): install session result.
import 'package:flutter/services.dart';

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
}

class AndroidKopru implements Kopru {
  AndroidKopru() : _kanal = const MethodChannel('com.aktenak.habit_tracker/kopru');
  final MethodChannel _kanal;

  void Function(int, String?)? _kurulumF;

  @override
  Future<String> agTuru() async => (await _kanal.invokeMethod<String>('agTuru')) ?? 'yok';

  @override
  Future<bool> kurulumIzniVar() async => (await _kanal.invokeMethod<bool>('kurulumIzniVar')) ?? false;

  @override
  Future<void> kurulumIzniAc() => _kanal.invokeMethod<void>('kurulumIzniAc');

  @override
  Future<void> apkKur(String yol) => _kanal.invokeMethod<void>('apkKur', yol);

  @override
  void kurulumSonucuDinle(void Function(int durum, String? mesaj) f) {
    _kurulumF = f;
    _kanal.setMethodCallHandler((c) async {
      if (c.method == 'kurulumSonucu' && c.arguments is Map) {
        final m = c.arguments as Map;
        final d = m['durum'];
        if (d is int) _kurulumF?.call(d, m['mesaj'] is String ? m['mesaj'] as String : null);
      }
    });
  }
}
