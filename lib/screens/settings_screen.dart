import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../utils/app_theme.dart';
import '../widgets/app_logo.dart';
import '../widgets/common_widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settings = SettingsService();
  bool _gradualVolume = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final gv = await _settings.getGradualVolume();
    if (mounted) setState(() => _gradualVolume = gv);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
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
                        'Settings',
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
                    children: [
                      const SizedBox(height: 20),

                      // App info
                      Center(
                        child: Column(
                          children: [
                            const AppLogo(size: 70, showText: true),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.bgSurface,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'Version 1.0.0',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Sound settings
                      GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionHeader(
                                'Sound', Icons.volume_up, AppColors.primary),
                            const SizedBox(height: 16),
                            _switchTile(
                              title: 'Gradual Volume',
                              subtitle: 'Volume increases gradually when alarm rings',
                              value: _gradualVolume,
                              onChanged: (v) async {
                                await _settings.setGradualVolume(v);
                                setState(() => _gradualVolume = v);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // About
                      GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionHeader(
                                'About', Icons.info_outline, AppColors.accent),
                            const SizedBox(height: 16),
                            _infoTile('App Name', "Vin's Alarm"),
                            _infoTile('Purpose', 'Quick alarms for BRB & lunch'),
                            _infoTile('Developer', 'Vin'),
                            _infoTile(
                                'Platform', 'Android (Flutter)'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Permissions
                      GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionHeader('Permissions',
                                Icons.security, AppColors.accentOrange),
                            const SizedBox(height: 16),
                            _permissionTile(
                                'Notifications', Icons.notifications),
                            _permissionTile(
                                'Exact Alarms', Icons.alarm),
                            _permissionTile(
                                'Vibration', Icons.vibration),
                            _permissionTile(
                                'Camera (Flashlight)', Icons.flashlight_on),
                            _permissionTile(
                                'Wake Lock', Icons.lock_clock),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
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

  Widget _sectionHeader(String title, IconData icon, Color color) {
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

  Widget _switchTile({
    required String title,
    required String subtitle,
    required bool value,
    required void Function(bool) onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppColors.accent,
          activeTrackColor: AppColors.accent.withAlpha(80),
        ),
      ],
    );
  }

  Widget _infoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _permissionTile(String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textMuted, size: 16),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.accent.withAlpha(20),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'Required',
              style: TextStyle(
                color: AppColors.accent,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
