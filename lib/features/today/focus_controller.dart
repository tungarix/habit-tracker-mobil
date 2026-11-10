import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/enums.dart';
import '../../data/providers.dart';

/// Immutable snapshot of the focus timer.
@immutable
class FocusState {
  final bool running;
  final SessionKind kind;
  final int plannedMinutes;
  final int remainingSeconds;

  const FocusState({
    required this.running,
    required this.kind,
    required this.plannedMinutes,
    required this.remainingSeconds,
  });

  static const idle = FocusState(
    running: false,
    kind: SessionKind.focus,
    plannedMinutes: 25,
    remainingSeconds: 25 * 60,
  );
}

/// A finished run, as the database wants it.
class FocusRecord {
  final SessionKind kind;
  final DateTime startedAt;
  final DateTime endedAt;
  final int durationS;
  final int? taskId;

  const FocusRecord({
    required this.kind,
    required this.startedAt,
    required this.endedAt,
    required this.durationS,
    this.taskId,
  });
}

/// What happened when a run ended; the UI turns it into a snackbar.
class FocusResult {
  final SessionKind kind;
  final int durationS;

  /// The timer rang (true) or the user stopped it early (false).
  final bool completed;

  /// A row was written (runs under a minute are noise and are dropped).
  final bool saved;

  const FocusResult({
    required this.kind,
    required this.durationS,
    required this.completed,
    required this.saved,
  });
}

/// The focus timer as the UI sees it. The screen only talks to this interface;
/// the real implementation (persisted `focus_running`, exact-alarm
/// notification) replaces [MemoryFocusController] by overriding
/// [focusControllerProvider].
abstract class FocusController {
  ValueListenable<FocusState> get state;

  /// Emits once per run that ends, whether it rang or was stopped.
  Stream<FocusResult> get results;

  void start({
    required SessionKind kind,
    required int plannedMinutes,
    int? taskId,
  });

  /// Ends the current run early. No-op when idle.
  Future<void> stop();

  void dispose();
}

/// In-memory timer: lives only while the app process does.
///
/// shortcut: counts one-second ticks instead of wall-clock time, so a
/// backgrounded app under-counts; the real controller must use timestamps.
class MemoryFocusController implements FocusController {
  static const minimumRecordedSeconds = 60;

  final Future<void> Function(FocusRecord record) onRecord;
  final _state = ValueNotifier<FocusState>(FocusState.idle);
  final _results = StreamController<FocusResult>.broadcast();

  Timer? _ticker;
  DateTime? _startedAt;
  int _elapsed = 0;
  int? _taskId;

  MemoryFocusController({required this.onRecord});

  @override
  ValueListenable<FocusState> get state => _state;

  @override
  Stream<FocusResult> get results => _results.stream;

  @override
  void start({
    required SessionKind kind,
    required int plannedMinutes,
    int? taskId,
  }) {
    if (_state.value.running) return;
    _startedAt = DateTime.now();
    _elapsed = 0;
    _taskId = taskId;
    _state.value = FocusState(
      running: true,
      kind: kind,
      plannedMinutes: plannedMinutes,
      remainingSeconds: plannedMinutes * 60,
    );
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    _elapsed++;
    final left = _state.value.remainingSeconds - 1;
    if (left <= 0) {
      _finish(completed: true);
      return;
    }
    final s = _state.value;
    _state.value = FocusState(
      running: true,
      kind: s.kind,
      plannedMinutes: s.plannedMinutes,
      remainingSeconds: left,
    );
  }

  @override
  Future<void> stop() => _finish(completed: false);

  Future<void> _finish({required bool completed}) async {
    final started = _startedAt;
    if (!_state.value.running || started == null) return;
    final s = _state.value;
    _ticker?.cancel();
    _ticker = null;
    _startedAt = null;
    final elapsed = _elapsed;
    _state.value = FocusState(
      running: false,
      kind: s.kind,
      plannedMinutes: s.plannedMinutes,
      remainingSeconds: s.plannedMinutes * 60,
    );

    final saved = elapsed >= minimumRecordedSeconds;
    if (saved) {
      await onRecord(
        FocusRecord(
          kind: s.kind,
          startedAt: started,
          endedAt: DateTime.now(),
          durationS: elapsed,
          taskId: _taskId,
        ),
      );
    }
    if (!_results.isClosed) {
      _results.add(
        FocusResult(
          kind: s.kind,
          durationS: elapsed,
          completed: completed,
          saved: saved,
        ),
      );
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _results.close();
    _state.dispose();
  }
}

/// Override this in the app root to plug in the real controller.
final focusControllerProvider = Provider<FocusController>((ref) {
  final controller = MemoryFocusController(
    onRecord: (r) => ref
        .read(sessionRepositoryProvider)
        .record(
          kind: r.kind,
          startedAt: r.startedAt,
          endedAt: r.endedAt,
          durationS: r.durationS,
          day: ref.read(todayProvider),
          taskId: r.taskId,
        ),
  );
  ref.onDispose(controller.dispose);
  return controller;
});
