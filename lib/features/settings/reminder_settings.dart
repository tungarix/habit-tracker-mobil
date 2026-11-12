import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Evening-reminder time as the settings screen sees it.
///
/// The screen only needs "which hour, or off". The real notification logic
/// (scheduling, permissions) lives elsewhere and supplies its own
/// implementation by overriding [reminderSettingsProvider].
abstract class ReminderSettings {
  /// Hour of day (0-23) the reminder fires at; null means switched off.
  Future<int?> readHour();

  Future<void> writeHour(int? hour);

  /// False when the system blocks notifications, so the reminder can never show.
  Future<bool> izinVar();
}

/// Default implementation: keeps the value for the life of the process only.
class InMemoryReminderSettings implements ReminderSettings {
  InMemoryReminderSettings([this._hour]);

  int? _hour;

  @override
  Future<int?> readHour() async => _hour;

  @override
  Future<void> writeHour(int? hour) async => _hour = hour;

  @override
  Future<bool> izinVar() async => true;
}

final reminderSettingsProvider = Provider<ReminderSettings>(
  (ref) => InMemoryReminderSettings(),
);
