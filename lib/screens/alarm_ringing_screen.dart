import 'dart:async';
import 'package:flutter/material.dart';
import '../models/alarm_model.dart';
import '../services/alarm_service.dart';
import '../utils/app_theme.dart';
import '../widgets/common_widgets.dart';

class AlarmRingingScreen extends StatefulWidget {
  final AlarmModel alarm;

  const AlarmRingingScreen({super.key, required this.alarm});

  @override
  State<AlarmRingingScreen> createState() => _AlarmRingingScreenState();
}

class _AlarmRingingScreenState extends State<AlarmRingingScreen>
    with TickerProviderStateMixin {
  final AlarmService _alarmService = AlarmService();
  late AnimationController _pulseController;
  late AnimationController _shakeController;
  late Animation<double> _pulseAnim;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );

    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _shakeAnim = Tween<double>(begin: -8.0, end: 8.0).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );

    // Auto-shake every 2 seconds
    Timer.periodic(const Duration(seconds: 2), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      _shakeController.forward().then((_) => _shakeController.reverse());
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _stopAlarm() async {
    await _alarmService.stopAlarm();
    await _alarmService.handleAlarmStopped(widget.alarm.id);
    if (mounted) {
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  Future<void> _snooze() async {
    await _alarmService.snoozeAlarm(widget.alarm);
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A0515), Color(0xFF2D0A0A), Color(0xFF0A0B14)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                children: [
                  const Spacer(),
                  // Alarm icon with pulsing effect
                  AnimatedBuilder(
                    animation: _pulseAnim,
                    builder: (_, child) => Transform.scale(
                      scale: _pulseAnim.value,
                      child: child,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Glow rings
                        ...List.generate(3, (i) {
                          return AnimatedBuilder(
                            animation: _pulseController,
                            builder: (_, child2) => Container(
                              width: 120.0 + (i + 1) * 40,
                              height: 120.0 + (i + 1) * 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.accentRed.withValues(
                                    alpha: (0.4 - i * 0.1) *
                                        (i.isEven
                                            ? _pulseController.value
                                            : 1 - _pulseController.value),
                                  ),
                                  width: 1.5,
                                ),
                              ),
                            ),
                          );
                        }),
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                AppColors.accentRed.withAlpha(80),
                                AppColors.bgCard,
                              ],
                            ),
                            border: Border.all(
                              color: AppColors.accentRed,
                              width: 2,
                            ),
                          ),
                          child: AnimatedBuilder(
                            animation: _shakeAnim,
                            builder: (_, child) => Transform.translate(
                              offset: Offset(_shakeAnim.value, 0),
                              child: child,
                            ),
                            child: const Icon(
                              Icons.alarm_on,
                              color: AppColors.accentRed,
                              size: 52,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Message
                  Text(
                    '${widget.alarm.label.toUpperCase()} TIME',
                    style: const TextStyle(
                      fontSize: 14,
                      letterSpacing: 4,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ShaderMask(
                    shaderCallback: (bounds) =>
                        AppColors.urgentGradient.createShader(bounds),
                    child: const Text(
                      'Time is up!\nReturn now.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.alarm.alertMode.hasSound)
                        const _RingingBadge(
                            icon: Icons.volume_up, label: 'Sound'),
                      if (widget.alarm.alertMode.hasVibrate)
                        const _RingingBadge(
                            icon: Icons.vibration, label: 'Vibrate'),
                      if (widget.alarm.alertMode.hasFlashlight)
                        const _RingingBadge(
                            icon: Icons.flashlight_on, label: 'Flash'),
                    ],
                  ),

                  const Spacer(),

                  // STOP button
                  SizedBox(
                    width: double.infinity,
                    child: GradientButton(
                      label: 'STOP ALARM',
                      icon: Icons.stop_circle,
                      gradient: AppColors.urgentGradient,
                      fontSize: 20,
                      padding: const EdgeInsets.symmetric(vertical: 22),
                      onTap: _stopAlarm,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Snooze button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _snooze,
                      icon: const Icon(Icons.snooze,
                          color: AppColors.textSecondary),
                      label: const Text(
                        'SNOOZE 5 MIN',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        side: const BorderSide(
                            color: AppColors.textMuted, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingingBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _RingingBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.accentRed.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: AppColors.accentRed.withAlpha(80), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.accentRed, size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.accentRed,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
