// Keeps the widget and the reminder plan in step with the database.
//
// Triggers: app open, app back in the foreground, and any change to habits, marks or settings
// (UI marks and widget writes both arrive here, because the database connection is shared).
// After a reboot or an app update the notification plugin re-registers the stored reminders itself;
// the next open recomputes the plan.
import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/widgets.dart';

import '../data/database/database.dart';
import 'bildirimler.dart';
import 'yenileme.dart';

class YanEtkiIzleyici with WidgetsBindingObserver {
  YanEtkiIzleyici(this._db, this._bildirim, {this.bekleme = const Duration(milliseconds: 500)});

  final AppDatabase _db;
  final BildirimKapisi _bildirim;
  final Duration bekleme;
  StreamSubscription<Set<TableUpdate>>? _abone;
  Timer? _zamanlayici;
  bool _calisiyor = false;
  bool _tekrar = false;

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _abone = _db
        .tableUpdates(TableUpdateQuery.onAllTables([_db.habits, _db.habitEntries, _db.settings]))
        .listen((_) => _zamanla());
    unawaited(yenile());
  }

  void stop() {
    WidgetsBinding.instance.removeObserver(this);
    _abone?.cancel();
    _zamanlayici?.cancel();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(yenile());
  }

  void _zamanla() {
    _zamanlayici?.cancel();
    _zamanlayici = Timer(bekleme, () => unawaited(yenile()));
  }

  /// One refresh at a time; a request that arrives meanwhile runs once more afterwards.
  Future<void> yenile() async {
    if (_calisiyor) {
      _tekrar = true;
      return;
    }
    _calisiyor = true;
    try {
      do {
        _tekrar = false;
        await yanEtkileriYenile(_db, _bildirim);
      } while (_tekrar);
    } catch (_) {
      // Best effort: the next change or resume retries.
    } finally {
      _calisiyor = false;
    }
  }
}
