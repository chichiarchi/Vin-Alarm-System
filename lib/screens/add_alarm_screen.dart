import 'package:flutter/material.dart';
import '../models/alarm_model.dart';
import '../services/alarm_service.dart';
import '../services/settings_service.dart';
import '../utils/app_theme.dart';
import '../widgets/common_widgets.dart';

class AddAlarmScreen extends StatefulWidget {
  final AlertMode defaultAlertMode;
  final AlarmModel? existingAlarm; // null = new alarm, non-null = edit

  const AddAlarmScreen({
    super.key,
    required this.defaultAlertMode,
    this.existingAlarm,
  });

  @override
  State<AddAlarmScreen> createState() => _AddAlarmScreenState();
}

class _AddAlarmScreenState extends State<AddAlarmScreen> {
  final AlarmService _alarmService = AlarmService();
  final SettingsService _settingsService = SettingsService();

  // Time state
  int _hour = 8;
  int _minute = 0;
  bool _isPM = false;

  // Config
  final TextEditingController _labelController =
      TextEditingController(text: 'Alarm');
  late AlertMode _alertMode;
  String? _soundUri;
  String? _soundTitle;
  int _ringDuration = 90; // Default 1.5 min (90s)

  bool get _isEditing => widget.existingAlarm != null;

  @override
  void initState() {
    super.initState();
    _alertMode = widget.defaultAlertMode;

    if (_isEditing) {
      final alarm = widget.existingAlarm!;
      final h = alarm.triggerTime.hour;
      _hour = h % 12 == 0 ? 12 : h % 12;
      _minute = alarm.triggerTime.minute;
      _isPM = h >= 12;
      _labelController.text = alarm.label;
      _alertMode = alarm.alertMode;
      _soundUri = alarm.soundUri;
      _soundTitle = alarm.soundTitle;
      _ringDuration = alarm.ringDuration;
    } else {
      // Default to 1 hour from now
      final now = DateTime.now().add(const Duration(hours: 1));
      final h = now.hour;
      _hour = h % 12 == 0 ? 12 : h % 12;
      _minute = now.minute;
      _isPM = h >= 12;
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  DateTime _buildTriggerTime() {
    final now = DateTime.now();
    int h24 = _hour % 12 + (_isPM ? 12 : 0);
    var trigger = DateTime(now.year, now.month, now.day, h24, _minute);
    // If the time is in the past, schedule for tomorrow
    if (trigger.isBefore(now)) {
      trigger = trigger.add(const Duration(days: 1));
    }
    return trigger;
  }

  String get _untilLabel {
    final trigger = _buildTriggerTime();
    final diff = trigger.difference(DateTime.now());
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    if (h > 0 && m > 0) return 'in ${h}h ${m}m';
    if (h > 0) return 'in ${h}h';
    return 'in ${m}m';
  }

  Future<void> _pickRingtone() async {
    final res = await _alarmService.pickRingtone();
    if (res != null && mounted) {
      setState(() {
        _soundUri = res['uri'];
        _soundTitle = res['title'];
      });
    }
  }

  Future<void> _save() async {
    final label = _labelController.text.trim().isEmpty
        ? 'Alarm'
        : _labelController.text.trim();
    final trigger = _buildTriggerTime();

    final alarm = AlarmModel(
      id: _isEditing
          ? widget.existingAlarm!.id
          : 'alarm_${DateTime.now().millisecondsSinceEpoch}',
      label: label,
      triggerTime: trigger,
      alertMode: _alertMode,
      isEnabled: true,
      soundUri: _soundUri,
      soundTitle: _soundTitle,
      isQuickAlarm: false, // Customized alarms are NOT quick alarms
      ringDuration: _ringDuration,
    );

    await _alarmService.saveAlarm(alarm);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    if (!_isEditing) return;
    await _alarmService.deleteAlarm(widget.existingAlarm!.id);
    if (mounted) Navigator.pop(context);
  }

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
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 8),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      _buildTimePicker(),
                      const SizedBox(height: 20),
                      _buildLabelSection(),
                      const SizedBox(height: 16),
                      _buildRingtoneSection(),
                      const SizedBox(height: 16),
                      _buildRingDurationSection(),
                      const SizedBox(height: 16),
                      _buildAlertModeSection(),
                      const SizedBox(height: 32),
                      _buildSaveButton(),
                      if (_isEditing) ...[
                        const SizedBox(height: 12),
                        _buildDeleteButton(),
                      ],
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

  Widget _buildRingDurationSection() {
    final options = [
      {'label': '1 Min', 'value': 60},
      {'label': '1.5 Min', 'value': 90},
      {'label': '2 Min', 'value': 120},
      {'label': '5 Min', 'value': 300},
      {'label': '10 Min', 'value': 600},
    ];

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.timer_outlined, color: AppColors.accent, size: 16),
              SizedBox(width: 8),
              Text(
                'Ring Duration',
                style: TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: options.map((opt) {
              final isSelected = _ringDuration == opt['value'];
              return ChoiceChip(
                label: Text(
                  opt['label'] as String,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                selected: isSelected,
                selectedColor: AppColors.primary,
                backgroundColor: AppColors.bgSurface,
                showCheckmark: false,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: isSelected ? AppColors.primary : Colors.transparent,
                  ),
                ),
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _ringDuration = opt['value'] as int;
                    });
                  }
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRingtoneSection() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.music_note, color: AppColors.accent, size: 16),
              SizedBox(width: 8),
              Text(
                'Alarm Ringtone',
                style: TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _pickRingtone,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _soundTitle ?? 'Default Ringtone',
                      style: TextStyle(
                        color: _soundTitle != null
                            ? AppColors.textPrimary
                            : AppColors.textMuted,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.chevron_right,
                      color: AppColors.textMuted, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.textSecondary),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              _isEditing ? 'Edit Alarm' : 'New Alarm',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ),
          TextButton(
            onPressed: _save,
            child: const Text(
              'Save',
              style: TextStyle(
                color: AppColors.accent,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimePicker() {
    return GlassCard(
      child: Column(
        children: [
          // "in X time" preview
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _untilLabel,
              style: const TextStyle(
                color: AppColors.accent,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Wheel pickers: HH : MM AM/PM
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Hour
              _WheelColumn(
                values: List.generate(12, (i) => i + 1),
                selectedIndex: _hour - 1,
                onChanged: (i) => setState(() { _hour = i + 1; }),
                label: 'HR',
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 20),
                child: Text(
                  ' : ',
                  style: TextStyle(
                    fontSize: 36,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
              // Minute
              _WheelColumn(
                values: List.generate(60, (i) => i),
                selectedIndex: _minute,
                onChanged: (i) => setState(() { _minute = i; }),
                label: 'MIN',
                padZero: true,
              ),
              const SizedBox(width: 16),
              // AM / PM toggle
              _buildAmPmToggle(),
            ],
          ),
          const SizedBox(height: 16),

          // Quick time presets
          Wrap(
            spacing: 8,
            children: [
              _TimePreset(label: '+15 min', onTap: () => _addMinutes(15)),
              _TimePreset(label: '+30 min', onTap: () => _addMinutes(30)),
              _TimePreset(label: '+1 hr', onTap: () => _addMinutes(60)),
              _TimePreset(label: '+2 hr', onTap: () => _addMinutes(120)),
            ],
          ),
        ],
      ),
    );
  }

  void _addMinutes(int m) {
    final now = DateTime.now().add(Duration(minutes: m));
    final h = now.hour;
    setState(() {
      _hour = h % 12 == 0 ? 12 : h % 12;
      _minute = now.minute;
      _isPM = h >= 12;
    });
  }

  Widget _buildAmPmToggle() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          _AmPmButton(label: 'AM', selected: !_isPM,
              onTap: () => setState(() => _isPM = false)),
          _AmPmButton(label: 'PM', selected: _isPM,
              onTap: () => setState(() => _isPM = true)),
        ],
      ),
    );
  }

  Widget _buildLabelSection() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.label_outline, color: AppColors.primary, size: 16),
              SizedBox(width: 8),
              Text(
                'Label',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _labelController,
            style: const TextStyle(
                color: AppColors.textPrimary, fontSize: 16),
            decoration: InputDecoration(
              hintText: 'e.g. Lunch, BRB, Meeting...',
              hintStyle: const TextStyle(color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.bgSurface,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: ['Lunch', 'BRB', 'Meeting', 'Break', 'Back Soon', 'Urgent']
                .map((s) => GestureDetector(
                      onTap: () => setState(() => _labelController.text = s),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.bgSurface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _labelController.text == s
                                ? AppColors.primary
                                : AppColors.primary.withAlpha(40),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          s,
                          style: TextStyle(
                            color: _labelController.text == s
                                ? AppColors.primary
                                : AppColors.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertModeSection() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.notifications_active,
                  color: AppColors.accentOrange, size: 16),
              SizedBox(width: 8),
              Text(
                'Alert Mode',
                style: TextStyle(
                  color: AppColors.accentOrange,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 2.6,
            ),
            itemCount: AlertMode.values.length,
            itemBuilder: (_, i) {
              final mode = AlertMode.values[i];
              final selected = _alertMode == mode;
              return GestureDetector(
                onTap: () {
                  setState(() => _alertMode = mode);
                  _settingsService.setAlertMode(mode);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary.withAlpha(30)
                        : AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? AppColors.primary
                          : AppColors.textMuted.withAlpha(40),
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          mode.label,
                          style: TextStyle(
                            color: selected
                                ? AppColors.primary
                                : AppColors.textMuted,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w400,
                            fontSize: 11,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (selected)
                        const Icon(Icons.check_circle,
                            color: AppColors.primary, size: 14),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: GradientButton(
        label: _isEditing ? 'Update Alarm' : 'Set Alarm',
        icon: Icons.alarm_add,
        gradient: AppColors.accentGradient,
        fontSize: 16,
        padding: const EdgeInsets.symmetric(vertical: 20),
        onTap: _save,
      ),
    );
  }

  Widget _buildDeleteButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _delete,
        icon: const Icon(Icons.delete_outline, color: AppColors.accentRed),
        label: const Text(
          'Delete Alarm',
          style: TextStyle(
            color: AppColors.accentRed,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: const BorderSide(color: AppColors.accentRed, width: 1.5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}

// ─── Sub-widgets ─────────────────────────────────────────────────────────────

class _WheelColumn extends StatefulWidget {
  final List<int> values;
  final int selectedIndex;
  final void Function(int index) onChanged;
  final String label;
  final bool padZero;

  const _WheelColumn({
    required this.values,
    required this.selectedIndex,
    required this.onChanged,
    required this.label,
    this.padZero = false,
  });

  @override
  State<_WheelColumn> createState() => _WheelColumnState();
}

class _WheelColumnState extends State<_WheelColumn> {
  late FixedExtentScrollController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = FixedExtentScrollController(initialItem: widget.selectedIndex);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 80,
          height: 150,
          child: ListWheelScrollView.useDelegate(
            controller: _ctrl,
            itemExtent: 50,
            physics: const FixedExtentScrollPhysics(),
            perspective: 0.003,
            diameterRatio: 1.4,
            onSelectedItemChanged: widget.onChanged,
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: widget.values.length,
              builder: (_, i) {
                final val = widget.values[i];
                final selected = i == widget.selectedIndex;
                final str = widget.padZero
                    ? val.toString().padLeft(2, '0')
                    : val.toString();
                return Center(
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 150),
                    style: TextStyle(
                      fontSize: selected ? 36 : 24,
                      fontWeight: selected
                          ? FontWeight.w800
                          : FontWeight.w300,
                      color: selected
                          ? AppColors.textPrimary
                          : AppColors.textMuted,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    child: Text(str),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _AmPmButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _AmPmButton(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 54,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textMuted,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _TimePreset extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _TimePreset({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: AppColors.primary.withAlpha(50), width: 1),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
