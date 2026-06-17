import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/alarm_model.dart';

/// Communicates with native Android AlarmManager via MethodChannel.
/// All actual alarm triggering (sound, vibration, flashlight, wakelock)
/// is handled by AlarmForegroundService.kt on the Android side.
class AlarmService {
  static final AlarmService _instance = AlarmService._internal();
  factory AlarmService() => _instance;
  AlarmService._internal();

  static const _scheduleChannel = MethodChannel('vin.alarm/schedule');
  static const _controlChannel = MethodChannel('vin.alarm/control');
  static const _eventChannel = EventChannel('vin.alarm/events');
  static const _prefsKey = 'alarms_v2';

  // ── Stream that emits alarm data when an alarm fires ─────────────────────
  Stream<Map<String, dynamic>> get alarmFireStream =>
      _eventChannel.receiveBroadcastStream().map((e) {
        if (e is Map) return Map<String, dynamic>.from(e);
        return <String, dynamic>{};
      }).where((m) => m.isNotEmpty);

  // ── Check if there's a pending alarm (app launched by alarm) ─────────────
  Future<Map<String, dynamic>?> getPendingAlarm() async {
    try {
      final result = await _scheduleChannel.invokeMethod('getPendingAlarm');
      if (result == null) return null;
      return Map<String, dynamic>.from(result as Map);
    } catch (_) {
      return null;
    }
  }

  // ── Stop ringing alarm ────────────────────────────────────────────────────
  Future<void> stopAlarm() async {
    try {
      await _controlChannel.invokeMethod('stopAlarm');
    } catch (_) {}
  }

  Future<void> snoozeAlarm(AlarmModel alarm) async {
    try {
      await _controlChannel.invokeMethod('snoozeAlarm');
    } catch (_) {}
    await handleAlarmStopped(alarm.id); // Disable/delete original alarm

    // Schedule snooze alarm 5 min from now
    final snooze = alarm.copyWith(
      id: 'snooze_${DateTime.now().millisecondsSinceEpoch}',
      triggerTime: DateTime.now().add(const Duration(minutes: 5)),
      label: '${alarm.label} (Snooze)',
      isEnabled: true,
      isQuickAlarm: true,
      ringDuration: 90, // Quick snooze duration is 1 min 30 s
    );
    await saveAlarm(snooze);
  }

  Future<void> handleAlarmStopped(String alarmId) async {
    final alarms = await getAllAlarms();
    final idx = alarms.indexWhere((a) => a.id == alarmId);
    if (idx == -1) return;

    final alarm = alarms[idx];
    if (alarm.isQuickAlarm) {
      await deleteAlarm(alarmId);
    } else {
      await toggleAlarm(alarmId, false);
    }
  }

  Future<void> handleAlarmTimeout(String alarmId) async {
    final alarms = await getAllAlarms();
    final idx = alarms.indexWhere((a) => a.id == alarmId);
    if (idx == -1) return;

    final alarm = alarms[idx];
    await snoozeAlarm(alarm);
  }

  // ── CRUD ─────────────────────────────────────────────────────────────────

  Future<void> saveAlarm(AlarmModel alarm) async {
    final alarms = await getAllAlarms();
    alarms.removeWhere((a) => a.id == alarm.id);

    if (alarm.isEnabled && alarm.triggerTime.isAfter(DateTime.now())) {
      await _scheduleNative(alarm);
    } else {
      await _cancelNative(alarm.id);
    }

    alarms.add(alarm);
    alarms.sort((a, b) => a.triggerTime.compareTo(b.triggerTime));
    await _persist(alarms);
  }

  Future<void> deleteAlarm(String alarmId) async {
    await _cancelNative(alarmId);
    final alarms = await getAllAlarms();
    alarms.removeWhere((a) => a.id == alarmId);
    await _persist(alarms);
  }

  Future<void> toggleAlarm(String alarmId, bool enabled) async {
    final alarms = await getAllAlarms();
    final idx = alarms.indexWhere((a) => a.id == alarmId);
    if (idx == -1) return;

    var alarm = alarms[idx];
    alarm.isEnabled = enabled;

    if (enabled) {
      if (alarm.triggerTime.isBefore(DateTime.now())) {
        var newTime = DateTime(
          DateTime.now().year,
          DateTime.now().month,
          DateTime.now().day,
          alarm.triggerTime.hour,
          alarm.triggerTime.minute,
        );
        if (newTime.isBefore(DateTime.now())) {
          newTime = newTime.add(const Duration(days: 1));
        }
        alarm = alarm.copyWith(triggerTime: newTime, isEnabled: true);
        alarms[idx] = alarm;
      }
      await _scheduleNative(alarm);
    } else {
      await _cancelNative(alarmId);
    }
    await _persist(alarms);
  }

  Future<List<AlarmModel>> getAllAlarms() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_prefsKey) ?? [];
    return jsonList.map((j) {
      try { return AlarmModel.fromJson(j); } catch (_) { return null; }
    }).whereType<AlarmModel>().toList()
      ..sort((a, b) => a.triggerTime.compareTo(b.triggerTime));
  }

  Future<void> cleanPastAlarms() async {
    final alarms = await getAllAlarms();
    final now = DateTime.now();
    final updated = <AlarmModel>[];
    for (final a in alarms) {
      if (a.triggerTime.isBefore(now)) {
        if (a.isQuickAlarm) {
          continue;
        } else {
          a.isEnabled = false;
        }
      }
      updated.add(a);
    }
    await _persist(updated);
  }

  Future<AlarmModel> createQuickAlarm({
    required int minutesFromNow,
    required String label,
    required AlertMode alertMode,
  }) async {
    final alarm = AlarmModel(
      id: 'alarm_${DateTime.now().millisecondsSinceEpoch}',
      label: label,
      triggerTime: DateTime.now().add(Duration(minutes: minutesFromNow)),
      alertMode: alertMode,
      isEnabled: true,
      isQuickAlarm: true,
      ringDuration: 90, // Quick-add alarm auto sets duration to 1m 30s
    );
    await saveAlarm(alarm);
    return alarm;
  }

  /// Launch Android system ringtone picker.
  /// Returns {'uri': '...', 'title': '...'} or null.
  Future<Map<String, String>?> pickRingtone() async {
    try {
      final result = await _scheduleChannel.invokeMethod('pickRingtone');
      if (result == null) return null;
      return Map<String, String>.from(result as Map);
    } catch (_) {
      return null;
    }
  }

  // ── Native bridge ─────────────────────────────────────────────────────────

  Future<void> _scheduleNative(AlarmModel alarm) async {
    try {
      await _scheduleChannel.invokeMethod('scheduleAlarm', {
        'id': alarm.id,
        'triggerTime': alarm.triggerTime.millisecondsSinceEpoch,
        'label': alarm.label,
        'alertMode': alarm.alertMode.index,
        'soundUri': alarm.soundUri,
        'isQuickAlarm': alarm.isQuickAlarm,
        'ringDuration': alarm.ringDuration,
      });
    } catch (e) {
      // ignore: avoid_print
      print('scheduleAlarm error: $e');
    }
  }

  Future<void> _cancelNative(String alarmId) async {
    try {
      await _scheduleChannel.invokeMethod('cancelAlarm', alarmId);
    } catch (_) {}
  }

  Future<void> _persist(List<AlarmModel> alarms) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, alarms.map((a) => a.toJson()).toList());
  }
}
