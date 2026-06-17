import 'package:flutter/material.dart';
import '../models/alarm_model.dart';
import '../services/settings_service.dart';
import '../utils/app_theme.dart';

class AlertModeScreen extends StatefulWidget {
  const AlertModeScreen({super.key});

  @override
  State<AlertModeScreen> createState() => _AlertModeScreenState();
}

class _AlertModeScreenState extends State<AlertModeScreen> {
  final SettingsService _settings = SettingsService();
  AlertMode _selected = AlertMode.soundVibrate;
  FlashMode _flashMode = FlashMode.blinking;
  VibrationPattern _vibPattern = VibrationPattern.normal;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final mode = await _settings.getAlertMode();
    final flash = await _settings.getFlashMode();
    final vib = await _settings.getVibrationPattern();
    if (mounted) {
      setState(() {
        _selected = mode;
        _flashMode = flash;
        _vibPattern = vib;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              // App bar
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios,
                          color: AppColors.textSecondary),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        'Alert Mode',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Choose how your alarm alerts you',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Alert modes list
                      ...AlertMode.values.map((mode) =>
                          _buildAlertModeCard(mode)),

                      const SizedBox(height: 24),

                      // Flash mode
                      if (_selected.hasFlashlight) ...[
                        _buildSectionHeader('Flashlight Mode',
                            Icons.flashlight_on, AppColors.accentOrange),
                        const SizedBox(height: 12),
                        ...FlashMode.values
                            .map((f) => _buildSubOption(
                                  label: _flashLabel(f),
                                  selected: _flashMode == f,
                                  color: AppColors.accentOrange,
                                  onTap: () async {
                                    await _settings.setFlashMode(f);
                                    setState(() => _flashMode = f);
                                  },
                                )),
                        const SizedBox(height: 24),
                      ],

                      // Vibration pattern
                      if (_selected.hasVibrate) ...[
                        _buildSectionHeader('Vibration Pattern',
                            Icons.vibration, AppColors.primary),
                        const SizedBox(height: 12),
                        ...VibrationPattern.values
                            .map((v) => _buildSubOption(
                                  label: _vibLabel(v),
                                  selected: _vibPattern == v,
                                  color: AppColors.primary,
                                  onTap: () async {
                                    await _settings.setVibrationPattern(v);
                                    setState(() => _vibPattern = v);
                                  },
                                )),
                        const SizedBox(height: 24),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlertModeCard(AlertMode mode) {
    final isSelected = _selected == mode;
    final color = _modeColor(mode);

    return GestureDetector(
      onTap: () async {
        await _settings.setAlertMode(mode);
        setState(() => _selected = mode);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withAlpha(20) : AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : AppColors.textMuted.withAlpha(40),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withAlpha(isSelected ? 40 : 20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_modeIcon(mode), color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mode.label,
                    style: TextStyle(
                      color: isSelected ? color : AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  if (mode.preset.isNotEmpty)
                    Text(
                      mode.preset,
                      style: TextStyle(
                        color: isSelected
                            ? color.withAlpha(180)
                            : AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
            Row(
              children: [
                if (mode.hasSound)
                  _chip(Icons.volume_up, AppColors.primary),
                if (mode.hasVibrate)
                  _chip(Icons.vibration, AppColors.accent),
                if (mode.hasFlashlight)
                  _chip(Icons.flashlight_on, AppColors.accentOrange),
                const SizedBox(width: 8),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? color : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? color : AppColors.textMuted,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check,
                          color: Colors.white, size: 14)
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  Widget _buildSubOption({
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? color.withAlpha(20) : AppColors.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : AppColors.textMuted.withAlpha(40),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? color : AppColors.textSecondary,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
            if (selected) Icon(Icons.check_circle, color: color, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, color: color, size: 13),
    );
  }

  Color _modeColor(AlertMode mode) {
    if (mode.hasFlashlight && mode.hasSound && mode.hasVibrate) {
      return AppColors.accentRed;
    }
    if (mode.hasSound && mode.hasVibrate) return AppColors.accent;
    if (mode.hasVibrate) return AppColors.primary;
    if (mode.hasFlashlight) return AppColors.accentOrange;
    return AppColors.textSecondary;
  }

  IconData _modeIcon(AlertMode mode) {
    if (mode.hasFlashlight && mode.hasSound && mode.hasVibrate) {
      return Icons.warning_amber_rounded;
    }
    if (mode.hasSound && mode.hasVibrate) return Icons.lunch_dining;
    if (mode.hasVibrate && mode.hasFlashlight) return Icons.meeting_room;
    if (mode.hasVibrate) return Icons.work;
    if (mode.hasFlashlight) return Icons.flashlight_on;
    return Icons.volume_up;
  }

  String _flashLabel(FlashMode m) {
    switch (m) {
      case FlashMode.steady:
        return 'Steady — constant light';
      case FlashMode.blinking:
        return 'Blinking — regular pulses';
      case FlashMode.fast:
        return 'Fast — rapid urgent flashes';
    }
  }

  String _vibLabel(VibrationPattern v) {
    switch (v) {
      case VibrationPattern.soft:
        return 'Soft — gentle vibration';
      case VibrationPattern.normal:
        return 'Normal — standard vibration';
      case VibrationPattern.strong:
        return 'Strong — intense repeated';
    }
  }
}
