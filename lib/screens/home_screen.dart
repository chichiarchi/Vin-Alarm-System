import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/alarm_model.dart';
import '../services/alarm_service.dart';
import '../services/settings_service.dart';
import '../utils/app_theme.dart';
import '../widgets/app_logo.dart';
import '../widgets/common_widgets.dart';
import 'add_alarm_screen.dart';
import 'alert_mode_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final AlarmService _alarmService = AlarmService();
  final SettingsService _settingsService = SettingsService();

  List<AlarmModel> _alarms = [];
  AlertMode _alertMode = AlertMode.soundVibrate;
  bool _loading = true;

  late Timer _clockTimer;
  DateTime _now = DateTime.now();

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });

    _init();
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await _requestPermissions();
    await _loadAlarms();
    await _loadSettings();
    _fadeCtrl.forward();
  }

  Future<void> _requestPermissions() async {
    await [Permission.notification, Permission.scheduleExactAlarm].request();
  }

  Future<void> _loadAlarms() async {
    await _alarmService.cleanPastAlarms();
    final alarms = await _alarmService.getAllAlarms();
    if (mounted) setState(() { _alarms = alarms; _loading = false; });
  }

  Future<void> _loadSettings() async {
    final mode = await _settingsService.getAlertMode();
    if (mounted) setState(() => _alertMode = mode);
  }

  // ─── Quick alarm ──────────────────────────────────────────────────────────

  Future<void> _quickAlarm(int minutes, String label) async {
    final alarm = await _alarmService.createQuickAlarm(
      minutesFromNow: minutes,
      label: label,
      alertMode: _alertMode,
    );
    await _loadAlarms();
    if (mounted) _showAlarmCreatedSnack(alarm);
  }

  void _showAlarmCreatedSnack(AlarmModel alarm) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.bgCard,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Row(
          children: [
            const Icon(Icons.alarm_on, color: AppColors.accent, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 14),
                  children: [
                    TextSpan(
                      text: '${alarm.label} ',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(
                      text: 'alarm set for ${alarm.formattedTime}',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ─── Navigation ───────────────────────────────────────────────────────────

  Future<void> _openAddAlarm() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddAlarmScreen(defaultAlertMode: _alertMode),
      ),
    );
    await _loadAlarms();
  }

  Future<void> _editAlarm(AlarmModel alarm) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddAlarmScreen(
          defaultAlertMode: _alertMode,
          existingAlarm: alarm,
        ),
      ),
    );
    await _loadAlarms();
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: RefreshIndicator(
                    onRefresh: _loadAlarms,
                    color: AppColors.accent,
                    backgroundColor: AppColors.bgCard,
                    child: CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(child: _buildClock()),
                        SliverToBoxAdapter(child: _buildQuickAlarms()),
                        SliverToBoxAdapter(child: _buildAlarmsHeader()),
                        if (_loading)
                          const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.all(40),
                              child: Center(
                                  child: CircularProgressIndicator(
                                      color: AppColors.accent)),
                            ),
                          )
                        else if (_alarms.isEmpty)
                          SliverToBoxAdapter(child: _buildEmptyState())
                        else
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (_, i) => _buildAlarmCard(_alarms[i]),
                              childCount: _alarms.length,
                            ),
                          ),
                        const SliverToBoxAdapter(child: SizedBox(height: 100)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildFab(),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          const AppLogoIcon(size: 36),
          const SizedBox(width: 10),
          const Text(
            "Vin's Alarm",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.tune, color: AppColors.textSecondary),
            tooltip: 'Alert Mode',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AlertModeScreen()),
            ).then((_) => _loadSettings()),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined,
                color: AppColors.textSecondary),
            tooltip: 'Settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClock() {
    final h = _now.hour;
    final m = _now.minute.toString().padLeft(2, '0');
    final s = _now.second.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final hour = (h % 12 == 0 ? 12 : h % 12).toString();

    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final dateStr =
        '${weekdays[_now.weekday - 1]}, ${months[_now.month - 1]} ${_now.day}';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF13152A), Color(0xFF1C1F3A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.primary.withAlpha(50), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: AppColors.primary.withAlpha(30),
              blurRadius: 24,
              spreadRadius: 0),
        ],
      ),
      child: Column(
        children: [
          // Time
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ShaderMask(
                shaderCallback: (b) =>
                    AppColors.primaryGradient.createShader(b),
                child: Text(
                  '$hour:$m',
                  style: const TextStyle(
                    fontSize: 72,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    fontFeatures: [FontFeature.tabularFigures()],
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      period,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent,
                      ),
                    ),
                    Text(
                      ':$s',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textMuted,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            dateStr,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
          // Active alarm count
          if (_alarms.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.accent.withAlpha(20),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: AppColors.accent.withAlpha(60), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const PulsingDot(size: 8),
                  const SizedBox(width: 8),
                  Text(
                    '${_alarms.length} alarm${_alarms.length > 1 ? 's' : ''} scheduled',
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickAlarms() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.flash_on, color: AppColors.accent, size: 18),
                const SizedBox(width: 8),
                const Text(
                  'Quick Alarm',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _alertMode.label,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Big lunch button
            SizedBox(
              width: double.infinity,
              child: GradientButton(
                label: 'Lunch / BRB — 1 Hour',
                gradient: AppColors.accentGradient,
                icon: Icons.lunch_dining,
                fontSize: 14,
                padding: const EdgeInsets.symmetric(
                    vertical: 16, horizontal: 20),
                onTap: () => _quickAlarm(60, 'Lunch / BRB'),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _QuickChip(
                    label: 'BRB 15',
                    sublabel: _timeLabel(15),
                    color: AppColors.primary,
                    onTap: () => _quickAlarm(15, 'BRB'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _QuickChip(
                    label: 'BRB 30',
                    sublabel: _timeLabel(30),
                    color: AppColors.primaryDark,
                    onTap: () => _quickAlarm(30, 'BRB'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _QuickChip(
                    label: 'BRB 45',
                    sublabel: _timeLabel(45),
                    color: AppColors.accentOrange,
                    onTap: () => _quickAlarm(45, 'BRB'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _timeLabel(int minutes) {
    final t = DateTime.now().add(Duration(minutes: minutes));
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    final period = t.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $period';
  }

  Widget _buildAlarmsHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 20, 10),
      child: Row(
        children: [
          const Text(
            'Scheduled Alarms',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const Spacer(),
          if (_alarms.isNotEmpty)
            GestureDetector(
              onTap: _openAddAlarm,
              child: const Row(
                children: [
                  Icon(Icons.add, color: AppColors.primary, size: 18),
                  SizedBox(width: 4),
                  Text(
                    'Add',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 40),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              shape: BoxShape.circle,
              border: Border.all(
                  color: AppColors.primary.withAlpha(40), width: 1.5),
            ),
            child: const Icon(Icons.alarm_add,
                size: 48, color: AppColors.textMuted),
          ),
          const SizedBox(height: 20),
          const Text(
            'No alarms yet',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Use Quick Alarm or tap + to create\na custom alarm at any time.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          GradientButton(
            label: 'Add Alarm',
            icon: Icons.add,
            gradient: AppColors.primaryGradient,
            onTap: _openAddAlarm,
          ),
        ],
      ),
    );
  }

  Widget _buildAlarmCard(AlarmModel alarm) {
    final isEnabled = alarm.isEnabled;
    final isPast = alarm.triggerTime.isBefore(DateTime.now());

    return Dismissible(
      key: Key(alarm.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.accentRed.withAlpha(40),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: AppColors.accentRed.withAlpha(80), width: 1),
        ),
        child: const Icon(Icons.delete_outline,
            color: AppColors.accentRed, size: 26),
      ),
      onDismissed: (_) async {
        await _alarmService.deleteAlarm(alarm.id);
        await _loadAlarms();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${alarm.label} alarm deleted',
                style: const TextStyle(color: AppColors.textPrimary),
              ),
              backgroundColor: AppColors.bgCard,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 12),
            ),
          );
        }
      },
      child: GestureDetector(
        onTap: () => _editAlarm(alarm),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isPast
                ? AppColors.bgCard.withAlpha(150)
                : isEnabled
                    ? AppColors.bgCard
                    : AppColors.bgCard.withAlpha(180),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isPast
                  ? AppColors.textMuted.withAlpha(30)
                  : isEnabled
                      ? AppColors.primary.withAlpha(60)
                      : AppColors.textMuted.withAlpha(30),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              // Time + label
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          alarm.formattedTime.split(' ')[0], // "1:22"
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            color: isPast
                                ? AppColors.textMuted
                                : isEnabled
                                    ? AppColors.textPrimary
                                    : AppColors.textMuted,
                            fontFeatures: const [
                              FontFeature.tabularFigures()
                            ],
                            height: 1,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          alarm.formattedTime.split(' ')[1], // "PM"
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isEnabled && !isPast
                                ? AppColors.accent
                                : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          alarm.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isEnabled && !isPast
                                ? AppColors.textSecondary
                                : AppColors.textMuted,
                          ),
                        ),
                        if (!isPast && isEnabled) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withAlpha(20),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              alarm.remainingLabel,
                              style: const TextStyle(
                                color: AppColors.accent,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                        if (isPast) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.textMuted.withAlpha(20),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Passed',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Mode chips
                    Row(
                      children: [
                        if (alarm.alertMode.hasSound)
                          _MiniChip(
                              icon: Icons.volume_up,
                              color: isEnabled && !isPast
                                  ? AppColors.primary
                                  : AppColors.textMuted),
                        if (alarm.alertMode.hasVibrate)
                          _MiniChip(
                              icon: Icons.vibration,
                              color: isEnabled && !isPast
                                  ? AppColors.accent
                                  : AppColors.textMuted),
                        if (alarm.alertMode.hasFlashlight)
                          _MiniChip(
                              icon: Icons.flashlight_on,
                              color: isEnabled && !isPast
                                  ? AppColors.accentOrange
                                  : AppColors.textMuted),
                      ],
                    ),
                  ],
                ),
              ),
              // Toggle
              Switch(
                value: isEnabled && !isPast,
                onChanged: (v) async {
                  await _alarmService.toggleAlarm(alarm.id, v);
                  await _loadAlarms();
                },
                activeThumbColor: AppColors.accent,
                activeTrackColor: AppColors.accent.withAlpha(80),
                inactiveThumbColor: AppColors.textMuted,
                inactiveTrackColor: AppColors.bgSurface,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFab() {
    return FloatingActionButton.extended(
      onPressed: _openAddAlarm,
      backgroundColor: AppColors.primary,
      elevation: 8,
      label: const Text(
        'New Alarm',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
      icon: const Icon(Icons.add, color: Colors.white),
    );
  }
}

// ─── Helper widgets ──────────────────────────────────────────────────────────

class _QuickChip extends StatelessWidget {
  final String label;
  final String sublabel;
  final Color color;
  final VoidCallback onTap;

  const _QuickChip({
    required this.label,
    required this.sublabel,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withAlpha(25),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withAlpha(80), width: 1),
        ),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                sublabel,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _MiniChip({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, color: color, size: 12),
    );
  }
}
