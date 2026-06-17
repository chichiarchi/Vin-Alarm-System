import 'package:shared_preferences/shared_preferences.dart';
import '../models/alarm_model.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  static const _keyAlertMode = 'alert_mode';
  static const _keyFlashMode = 'flash_mode';
  static const _keyVibrationPattern = 'vibration_pattern';
  static const _keyGradualVolume = 'gradual_volume';

  Future<AlertMode> getAlertMode() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_keyAlertMode) ?? AlertMode.soundVibrate.index;
    return AlertMode.values[index];
  }

  Future<void> setAlertMode(AlertMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyAlertMode, mode.index);
  }

  Future<FlashMode> getFlashMode() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_keyFlashMode) ?? FlashMode.blinking.index;
    return FlashMode.values[index];
  }

  Future<void> setFlashMode(FlashMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyFlashMode, mode.index);
  }

  Future<VibrationPattern> getVibrationPattern() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_keyVibrationPattern) ??
        VibrationPattern.normal.index;
    return VibrationPattern.values[index];
  }

  Future<void> setVibrationPattern(VibrationPattern pattern) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyVibrationPattern, pattern.index);
  }

  Future<bool> getGradualVolume() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyGradualVolume) ?? false;
  }

  Future<void> setGradualVolume(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyGradualVolume, value);
  }
}
