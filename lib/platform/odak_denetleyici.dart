// Real [FocusController]: wall-clock based, survives the app being closed.
//
// Running state is persisted under `focus_running` (see odak_durumu.dart); the end of the run is
// an exact alarm notification, so a 25-minute timer rings with the screen off. A session row is
// written only when the run ends (rang, stopped, or found finished after a restart).
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/enums.dart';
import '../data/database/database.dart';
import '../features/today/focus_controller.dart';
import 'bildirimler.dart';
import 'bugun_ozeti.dart';
import 'odak_durumu.dart';

class AndroidFocusController implements FocusController {
  AndroidFocusController({required this.db, required this.bildirim, DateTime Function()? saat})
    : _saat = saat ?? DateTime.now,
      _depo = OdakDeposu(db);

  final AppDatabase db;
  final BildirimKapisi bildirim;
  final DateTime Function() _saat;
  final OdakDeposu _depo;

  final _state = ValueNotifier<FocusState>(FocusState.idle);
  final _results = StreamController<FocusResult>.broadcast();

  Timer? _ticker;
  OdakCalisiyor? _calisan;
  bool _bitiyor = false;

  // Writes to the Settings table are queued so start/stop never interleave.
  Future<void> _kuyruk = Future.value();
  Future<T> _sirala<T>(Future<T> Function() is_) {
    final r = _kuyruk.then((_) => is_());
    _kuyruk = r.then((_) {}, onError: (_) {});
    return r;
  }

  @override
  ValueListenable<FocusState> get state => _state;

  @override
  Stream<FocusResult> get results => _results.stream;

  /// Picks up a run that was started before the process died: resumes it, or records it when its
  /// time ran out meanwhile. Call once after construction.
  Future<void> yukle() async {
    final s = await _depo.oku();
    if (s == null) return;
    if (!_saat().isBefore(s.bitis)) {
      _calisan = s;
      await _bitir(tamamlandi: true);
    } else {
      _baslatTicker(s);
    }
  }

  @override
  void start({required SessionKind kind, required int plannedMinutes, int? taskId}) {
    if (_calisan != null || plannedMinutes <= 0) return;
    final s = OdakCalisiyor(baslangic: _saat(), tur: kind, planSn: plannedMinutes * 60, taskId: taskId);
    _baslatTicker(s);
    unawaited(
      _sirala(() async {
        await _depo.baslat(s);
        try {
          await bildirim.odakBitisiKur(
            bitis: s.bitis,
            baslik: '${kind.label} bitti',
            govde: '$plannedMinutes dakika tamamlandı.',
          );
        } catch (_) {
          // No alarm permission etc.: the in-app timer still works.
        }
      }),
    );
  }

  void _baslatTicker(OdakCalisiyor s) {
    _calisan = s;
    _ticker?.cancel();
    _guncelle();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _guncelle());
  }

  void _guncelle() {
    final s = _calisan;
    if (s == null) return;
    final kalan = s.kalanSn(_saat());
    if (kalan <= 0) {
      unawaited(_bitir(tamamlandi: true));
      return;
    }
    _state.value = FocusState(
      running: true,
      kind: s.tur,
      plannedMinutes: s.planSn ~/ 60,
      remainingSeconds: kalan,
    );
  }

  @override
  Future<void> stop() => _bitir(tamamlandi: false);

  Future<void> _bitir({required bool tamamlandi}) async {
    final s = _calisan;
    if (s == null || _bitiyor) return;
    _bitiyor = true;
    _ticker?.cancel();
    _ticker = null;
    _calisan = null;
    final simdi = _saat();
    _state.value = FocusState(
      running: false,
      kind: s.tur,
      plannedMinutes: s.planSn ~/ 60,
      remainingSeconds: s.planSn,
    );
    try {
      final gecen = (tamamlandi ? s.bitis : simdi).difference(s.baslangic).inSeconds.clamp(0, s.planSn);
      final kaydedilen = await _sirala(() async {
        // Stopping early cancels the alarm; a run that rang keeps its notification.
        if (!tamamlandi) {
          try {
            await bildirim.odakBitisiIptal();
          } catch (_) {}
        }
        return _depo.bitir(simdi, dayStartHour: await gunBaslangicSaati(db), tamamlandi: tamamlandi);
      });
      if (!_results.isClosed) {
        _results.add(
          FocusResult(kind: s.tur, durationS: gecen, completed: tamamlandi, saved: kaydedilen != null),
        );
      }
    } finally {
      _bitiyor = false;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _results.close();
    _state.dispose();
  }
}
