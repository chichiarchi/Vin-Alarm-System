import 'dart:convert';

enum AlertMode {
  vibrateOnly,
  soundOnly,
  soundVibrate,
  flashlightOnly,
  flashlightVibrate,
  soundFlashlight,
  soundVibrateFlashlight,
}

enum FlashMode { steady, blinking, fast }

enum VibrationPattern { soft, normal, strong }

extension AlertModeExtension on AlertMode {
  String get label {
    switch (this) {
      case AlertMode.vibrateOnly:
        return 'Vibrate Only';
      case AlertMode.soundOnly:
        return 'Sound Only';
      case AlertMode.soundVibrate:
        return 'Sound + Vibrate';
      case AlertMode.flashlightOnly:
        return 'Flashlight Only';
      case AlertMode.flashlightVibrate:
        return 'Flashlight + Vibrate';
      case AlertMode.soundFlashlight:
        return 'Sound + Flashlight';
      case AlertMode.soundVibrateFlashlight:
        return 'Sound + Vibrate + Flashlight';
    }
  }

  String get preset {
    switch (this) {
      case AlertMode.vibrateOnly:
        return 'Work Mode';
      case AlertMode.soundVibrate:
        return 'Lunch Mode';
      case AlertMode.soundVibrateFlashlight:
        return 'Urgent Mode';
      case AlertMode.flashlightVibrate:
        return 'Silent Office';
      default:
        return '';
    }
  }

  bool get hasSound =>
      this == AlertMode.soundOnly ||
      this == AlertMode.soundVibrate ||
      this == AlertMode.soundFlashlight ||
      this == AlertMode.soundVibrateFlashlight;

  bool get hasVibrate =>
      this == AlertMode.vibrateOnly ||
      this == AlertMode.soundVibrate ||
      this == AlertMode.flashlightVibrate ||
      this == AlertMode.soundVibrateFlashlight;

  bool get hasFlashlight =>
      this == AlertMode.flashlightOnly ||
      this == AlertMode.flashlightVibrate ||
      this == AlertMode.soundFlashlight ||
      this == AlertMode.soundVibrateFlashlight;
}

class AlarmModel {
  final String id;
  final String label;
  final DateTime triggerTime; // The exact DateTime the alarm fires
  final AlertMode alertMode;
  final FlashMode flashMode;
  final VibrationPattern vibrationPattern;
  final bool gradualVolume;
  bool isEnabled;
  final String? soundUri;      // Custom alarm ringtone system URI
  final String? soundTitle;    // Custom alarm ringtone readable title
  final bool isQuickAlarm;     // If true, auto-delete when past. If false, disable it.
  final int ringDuration;      // Ring duration in seconds

  AlarmModel({
    required this.id,
    required this.label,
    required this.triggerTime,
    this.alertMode = AlertMode.soundVibrate,
    this.flashMode = FlashMode.blinking,
    this.vibrationPattern = VibrationPattern.normal,
    this.gradualVolume = false,
    this.isEnabled = true,
    this.soundUri,
    this.soundTitle,
    this.isQuickAlarm = false,
    this.ringDuration = 90,
  });

  AlarmModel copyWith({
    String? id,
    String? label,
    DateTime? triggerTime,
    AlertMode? alertMode,
    FlashMode? flashMode,
    VibrationPattern? vibrationPattern,
    bool? gradualVolume,
    bool? isEnabled,
    String? soundUri,
    String? soundTitle,
    bool? isQuickAlarm,
    int? ringDuration,
  }) {
    return AlarmModel(
      id: id ?? this.id,
      label: label ?? this.label,
      triggerTime: triggerTime ?? this.triggerTime,
      alertMode: alertMode ?? this.alertMode,
      flashMode: flashMode ?? this.flashMode,
      vibrationPattern: vibrationPattern ?? this.vibrationPattern,
      gradualVolume: gradualVolume ?? this.gradualVolume,
      isEnabled: isEnabled ?? this.isEnabled,
      soundUri: soundUri ?? this.soundUri,
      soundTitle: soundTitle ?? this.soundTitle,
      isQuickAlarm: isQuickAlarm ?? this.isQuickAlarm,
      ringDuration: ringDuration ?? this.ringDuration,
    );
  }

  /// Time remaining until alarm fires
  Duration get remaining {
    final diff = triggerTime.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  /// Human-readable "in X hours Y min" string
  String get remainingLabel {
    final diff = triggerTime.difference(DateTime.now());
    if (diff.isNegative) return 'Passed';
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    if (h > 0 && m > 0) return 'in ${h}h ${m}m';
    if (h > 0) return 'in ${h}h';
    if (m > 0) return 'in ${m}m';
    return 'in <1 min';
  }

  /// Formatted alarm time: e.g. "1:22 PM"
  String get formattedTime {
    final h = triggerTime.hour;
    final m = triggerTime.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final hour = h % 12 == 0 ? 12 : h % 12;
    return '$hour:$m $period';
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'label': label,
        'triggerTime': triggerTime.millisecondsSinceEpoch,
        'alertMode': alertMode.index,
        'flashMode': flashMode.index,
        'vibrationPattern': vibrationPattern.index,
        'gradualVolume': gradualVolume,
        'isEnabled': isEnabled,
        'soundUri': soundUri,
        'soundTitle': soundTitle,
        'isQuickAlarm': isQuickAlarm,
        'ringDuration': ringDuration,
      };

  factory AlarmModel.fromMap(Map<String, dynamic> map) => AlarmModel(
        id: map['id'],
        label: map['label'],
        triggerTime:
            DateTime.fromMillisecondsSinceEpoch(map['triggerTime']),
        alertMode: AlertMode.values[map['alertMode'] ?? 2],
        flashMode: FlashMode.values[map['flashMode'] ?? 1],
        vibrationPattern:
            VibrationPattern.values[map['vibrationPattern'] ?? 1],
        gradualVolume: map['gradualVolume'] ?? false,
        isEnabled: map['isEnabled'] ?? true,
        soundUri: map['soundUri'],
        soundTitle: map['soundTitle'],
        isQuickAlarm: map['isQuickAlarm'] ?? false,
        ringDuration: map['ringDuration'] ?? 90,
      );

  String toJson() => jsonEncode(toMap());
  factory AlarmModel.fromJson(String json) =>
      AlarmModel.fromMap(jsonDecode(json));
}
