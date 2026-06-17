import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'models/alarm_model.dart';
import 'screens/alarm_ringing_screen.dart';
import 'screens/home_screen.dart';
import 'services/alarm_service.dart';
import 'utils/app_theme.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0A0B14),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const VinAlarmApp());
}

class VinAlarmApp extends StatefulWidget {
  const VinAlarmApp({super.key});

  @override
  State<VinAlarmApp> createState() => _VinAlarmAppState();
}

class _VinAlarmAppState extends State<VinAlarmApp> {
  final AlarmService _alarmService = AlarmService();

  @override
  void initState() {
    super.initState();
    _listenForAlarmFire();
    _checkPendingAlarm();
  }

  /// Listen on EventChannel — fires when AlarmForegroundService launches or stops
  void _listenForAlarmFire() {
    _alarmService.alarmFireStream.listen((data) {
      final event = data['event'] as String? ?? 'ring';
      if (event == 'ring') {
        _navigateToRinging(data);
      } else if (event == 'stop') {
        final alarmId = data['id'] as String? ?? '';
        _alarmService.handleAlarmStopped(alarmId);
        // Automatically pop the ringing screen back to home if stopped from notification
        navigatorKey.currentState?.popUntil((route) => route.isFirst);
      } else if (event == 'timeout') {
        final alarmId = data['id'] as String? ?? '';
        _alarmService.handleAlarmTimeout(alarmId);
        // Automatically pop the ringing screen back to home if ringing timed out
        navigatorKey.currentState?.popUntil((route) => route.isFirst);
      }
    });
  }

  /// Called when app is launched directly by an alarm (was not in foreground)
  Future<void> _checkPendingAlarm() async {
    final data = await _alarmService.getPendingAlarm();
    if (data != null) {
      final event = data['event'] as String? ?? 'ring';
      if (event == 'ring') {
        // Small delay to ensure Navigator is ready
        await Future.delayed(const Duration(milliseconds: 300));
        _navigateToRinging(data);
      }
    }
  }

  void _navigateToRinging(Map<String, dynamic> data) {
    // Build a minimal AlarmModel from the event data
    final alarm = AlarmModel(
      id: data['id'] as String? ?? '',
      label: data['label'] as String? ?? 'Alarm',
      triggerTime: DateTime.now(),
      alertMode: AlertMode.values[data['alertMode'] as int? ?? 2],
      isEnabled: true,
      soundUri: data['soundUri'] as String?,
      isQuickAlarm: data['isQuickAlarm'] as bool? ?? false,
    );
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => AlarmRingingScreen(alarm: alarm),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Vin's Alarm",
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: AppTheme.darkTheme,
      home: const HomeScreen(),
    );
  }
}
