import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/expressive_tokens.dart';
import 'package:habit_tracker/data/services/reminder_scheduler.dart';

class RemindersSettingsPage extends StatefulWidget {
  const RemindersSettingsPage({super.key});

  @override
  State<RemindersSettingsPage> createState() => _RemindersSettingsPageState();
}

class _RemindersSettingsPageState extends State<RemindersSettingsPage> {
  late Box _settingsBox;

  bool _enabled = true;
  int _timeMinutes = 540; // 09:00 AM
  int _daysBefore = 1;

  String _styleBill = 'both';
  String _styleSub = 'notification';
  String _styleSip = 'notification';
  String _styleEmi = 'both';
  String _styleCard = 'notification';

  bool _isNotifGranted = false;
  bool _isExactAlarmGranted = false;
  bool _isBatteryIgnored = false;

  @override
  void initState() {
    super.initState();
    _settingsBox = Hive.box('finance_settings');
    _loadSettings();
    _checkPermissions();
  }

  void _loadSettings() {
    _enabled = _settingsBox.get('rem_enabled', defaultValue: true) as bool;
    _timeMinutes =
        _settingsBox.get('rem_time_minutes', defaultValue: 540) as int;
    _daysBefore = _settingsBox.get('rem_days_before', defaultValue: 1) as int;
    _styleBill =
        _settingsBox.get('rem_style_bill', defaultValue: 'both') as String;
    _styleSub = _settingsBox.get('rem_style_sub', defaultValue: 'notification')
        as String;
    _styleSip = _settingsBox.get('rem_style_sip', defaultValue: 'notification')
        as String;
    _styleEmi =
        _settingsBox.get('rem_style_emi', defaultValue: 'both') as String;
    _styleCard = _settingsBox.get('rem_style_card',
        defaultValue: 'notification') as String;
  }

  Future<void> _checkPermissions() async {
    final notif = await Permission.notification.isGranted;
    final exact = await Permission.scheduleExactAlarm.isGranted;
    final battery = await Permission.ignoreBatteryOptimizations.isGranted;
    if (mounted) {
      setState(() {
        _isNotifGranted = notif;
        _isExactAlarmGranted = exact;
        _isBatteryIgnored = battery;
      });
    }
  }

  Future<void> _saveAndSync() async {
    await _settingsBox.put('rem_enabled', _enabled);
    await _settingsBox.put('rem_time_minutes', _timeMinutes);
    await _settingsBox.put('rem_days_before', _daysBefore);
    await _settingsBox.put('rem_style_bill', _styleBill);
    await _settingsBox.put('rem_style_sub', _styleSub);
    await _settingsBox.put('rem_style_sip', _styleSip);
    await _settingsBox.put('rem_style_emi', _styleEmi);
    await _settingsBox.put('rem_style_card', _styleCard);

    await ReminderScheduler.sync(force: true);
  }

  String _formatTime(int minutes) {
    final hour = minutes ~/ 60;
    final min = minutes % 60;
    final period = hour >= 12 ? 'PM' : 'AM';
    final h12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final minStr = min.toString().padLeft(2, '0');
    return '$h12:$minStr $period';
  }

  Future<void> _pickTime() async {
    final initialTime = TimeOfDay(
      hour: _timeMinutes ~/ 60,
      minute: _timeMinutes % 60,
    );
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: BentoTheme.accent,
              surface: BentoTheme.surface,
              onSurface: BentoTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _timeMinutes = picked.hour * 60 + picked.minute;
      });
      await _saveAndSync();
    }
  }

  void _showStylePicker(
    String title,
    String currentStyle,
    ValueChanged<String> onSelected,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: BentoTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reminder Style for $title',
                  style: TextStyle(
                    color: BentoTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _styleOptionTile(
                  title: 'Off',
                  description: 'Do not send reminders for this type',
                  icon: LucideIcons.bellOff,
                  isSelected: currentStyle == 'off',
                  onTap: () {
                    Navigator.pop(context);
                    onSelected('off');
                  },
                ),
                _styleOptionTile(
                  title: 'Notification',
                  description: 'Standard notification with sound and vibration',
                  icon: LucideIcons.bell,
                  isSelected: currentStyle == 'notification',
                  onTap: () {
                    Navigator.pop(context);
                    onSelected('notification');
                  },
                ),
                _styleOptionTile(
                  title: 'Alarm',
                  description:
                      'Insistent alarm with full-screen intent on lock screen',
                  icon: LucideIcons.alarmClock,
                  isSelected: currentStyle == 'alarm',
                  onTap: () {
                    Navigator.pop(context);
                    onSelected('alarm');
                  },
                ),
                _styleOptionTile(
                  title: 'Both',
                  description:
                      'Notification in advance + full alarm on payment due date',
                  icon: LucideIcons.bellRing,
                  isSelected: currentStyle == 'both',
                  onTap: () {
                    Navigator.pop(context);
                    onSelected('both');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _styleOptionTile({
    required String title,
    required String description,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? BentoTheme.accent.withValues(alpha: 0.12)
            : BentoTheme.background,
        borderRadius: ExpressiveTokens.borderM,
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? BentoTheme.accent : BentoTheme.textSecondary,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? BentoTheme.accent : BentoTheme.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          description,
          style: TextStyle(
            color: BentoTheme.textSecondary,
            fontSize: 12,
          ),
        ),
        trailing: isSelected
            ? Icon(LucideIcons.check, size: 18, color: BentoTheme.accent)
            : null,
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BentoTheme.background,
      appBar: AppBar(
        backgroundColor: BentoTheme.background,
        elevation: 0,
        title: Text(
          'Reminders & Alarms',
          style: TextStyle(
            color: BentoTheme.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: BentoTheme.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Master Switch
              _buildMasterCard(),
              const SizedBox(height: 16),

              if (_enabled) ...[
                // Schedule timing
                _buildScheduleCard(),
                const SizedBox(height: 20),

                // Types & Styles
                _sectionHeader('REMINDER STYLES'),
                _buildStylesCard(),
                const SizedBox(height: 20),

                // Sound & Tone Card
                _buildSoundCard(),
                const SizedBox(height: 20),

                // Test Section
                _sectionHeader('TESTING'),
                _buildTestCard(),
                const SizedBox(height: 20),
              ],

              // Permissions Section
              _sectionHeader('PERMISSIONS & SYSTEM HEALTH'),
              _buildPermissionsCard(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          color: BentoTheme.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildMasterCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BentoTheme.surface,
        borderRadius: ExpressiveTokens.borderM,
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _enabled
                  ? BentoTheme.accent.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _enabled ? LucideIcons.bellRing : LucideIcons.bellOff,
              color: _enabled ? BentoTheme.accent : BentoTheme.textSecondary,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Finance Reminders',
                  style: TextStyle(
                    color: BentoTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _enabled
                      ? 'Scheduled for bills, SIPs, and card dues'
                      : 'All finance reminders are paused',
                  style: TextStyle(
                    color: BentoTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _enabled,
            activeColor: BentoTheme.accent,
            onChanged: (val) {
              setState(() => _enabled = val);
              _saveAndSync();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BentoTheme.surface,
        borderRadius: ExpressiveTokens.borderM,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time Row
          InkWell(
            onTap: _pickTime,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(LucideIcons.clock,
                      size: 18, color: BentoTheme.textSecondary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reminder Time',
                          style: TextStyle(
                            color: BentoTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Local device time when reminders fire',
                          style: TextStyle(
                            color: BentoTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: BentoTheme.background,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _formatTime(_timeMinutes),
                      style: TextStyle(
                        color: BentoTheme.accent,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Divider(height: 24, color: BentoTheme.divider),

          // Days in advance
          Text(
            'Remind In Advance',
            style: TextStyle(
              color: BentoTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Send an advance heads-up before the due date',
            style: TextStyle(
              color: BentoTheme.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [0, 1, 2, 3, 5, 7].map((days) {
                final isSelected = _daysBefore == days;
                final label = days == 0 ? 'On Due Date' : '$days Days Before';
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(label),
                    selected: isSelected,
                    selectedColor: BentoTheme.accent.withValues(alpha: 0.2),
                    backgroundColor: BentoTheme.background,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? BentoTheme.accent
                          : BentoTheme.textSecondary,
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    side: BorderSide.none,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _daysBefore = days);
                        _saveAndSync();
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStylesCard() {
    return Container(
      decoration: BoxDecoration(
        color: BentoTheme.surface,
        borderRadius: ExpressiveTokens.borderM,
      ),
      child: Column(
        children: [
          _typeStyleTile(
            title: 'Bills',
            icon: LucideIcons.receipt,
            currentStyle: _styleBill,
            onTap: () => _showStylePicker('Bills', _styleBill, (v) {
              setState(() => _styleBill = v);
              _saveAndSync();
            }),
          ),
          _divider(),
          _typeStyleTile(
            title: 'Subscriptions',
            icon: LucideIcons.refreshCw,
            currentStyle: _styleSub,
            onTap: () => _showStylePicker('Subscriptions', _styleSub, (v) {
              setState(() => _styleSub = v);
              _saveAndSync();
            }),
          ),
          _divider(),
          _typeStyleTile(
            title: 'SIP Investments',
            icon: LucideIcons.trendingUp,
            currentStyle: _styleSip,
            onTap: () => _showStylePicker('SIPs', _styleSip, (v) {
              setState(() => _styleSip = v);
              _saveAndSync();
            }),
          ),
          _divider(),
          _typeStyleTile(
            title: 'EMI & Loans',
            icon: LucideIcons.landmark,
            currentStyle: _styleEmi,
            onTap: () => _showStylePicker('EMIs', _styleEmi, (v) {
              setState(() => _styleEmi = v);
              _saveAndSync();
            }),
          ),
          _divider(),
          _typeStyleTile(
            title: 'Credit Card Dues',
            icon: LucideIcons.creditCard,
            currentStyle: _styleCard,
            onTap: () => _showStylePicker('Card Dues', _styleCard, (v) {
              setState(() => _styleCard = v);
              _saveAndSync();
            }),
          ),
        ],
      ),
    );
  }

  Widget _typeStyleTile({
    required String title,
    required IconData icon,
    required String currentStyle,
    required VoidCallback onTap,
  }) {
    String badgeText;
    Color badgeColor;
    switch (currentStyle) {
      case 'alarm':
        badgeText = 'Alarm';
        badgeColor = const Color(0xFFE07A7A);
        break;
      case 'both':
        badgeText = 'Both';
        badgeColor = BentoTheme.accent;
        break;
      case 'off':
        badgeText = 'Off';
        badgeColor = Colors.white38;
        break;
      case 'notification':
      default:
        badgeText = 'Notification';
        badgeColor = const Color(0xFF6BB58A);
        break;
    }

    return ListTile(
      leading: Icon(icon, size: 18, color: BentoTheme.textSecondary),
      title: Text(
        title,
        style: TextStyle(
          color: BentoTheme.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              badgeText,
              style: TextStyle(
                color: badgeColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(LucideIcons.chevronRight,
              size: 16, color: BentoTheme.textSecondary),
        ],
      ),
      onTap: onTap,
    );
  }

  Widget _divider() {
    return const Divider(height: 1, indent: 48, color: Colors.white10);
  }

  Widget _buildSoundCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BentoTheme.surface,
        borderRadius: ExpressiveTokens.borderM,
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: BentoTheme.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(LucideIcons.volume2,
                size: 18, color: BentoTheme.textSecondary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Alarm Ringtone',
                  style: TextStyle(
                    color: BentoTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'System default alarm tone with vibration',
                  style: TextStyle(
                    color: BentoTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BentoTheme.surface,
        borderRadius: ExpressiveTokens.borderM,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Verify Delivery in 1 Minute',
            style: TextStyle(
              color: BentoTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Send an immediate reminder scheduled 60 seconds from now to test device lockscreen wake-up.',
            style: TextStyle(
              color: BentoTheme.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(LucideIcons.bell, size: 14),
                  label: const Text('Test Notification'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: BentoTheme.textPrimary,
                    side: BorderSide(color: BentoTheme.divider),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () async {
                    await ReminderScheduler.sendTestReminder(asAlarm: false);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Test notification scheduled in 1 minute. Lock phone to verify.'),
                        ),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(LucideIcons.alarmClock, size: 14),
                  label: const Text('Test Alarm'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BentoTheme.accent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () async {
                    await ReminderScheduler.sendTestReminder(asAlarm: true);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Test alarm scheduled in 1 minute with sound and snooze action.'),
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BentoTheme.surface,
        borderRadius: ExpressiveTokens.borderM,
      ),
      child: Column(
        children: [
          _permissionRow(
            title: 'Notifications',
            subtitle: 'Required to show heads-up alerts and badges',
            isGranted: _isNotifGranted,
            onFix: () async {
              await Permission.notification.request();
              _checkPermissions();
            },
          ),
          Divider(height: 20, color: BentoTheme.divider),
          _permissionRow(
            title: 'Exact Alarms',
            subtitle: 'Required for to-the-minute alarms and lockscreen alerts',
            isGranted: _isExactAlarmGranted,
            onFix: () async {
              await Permission.scheduleExactAlarm.request();
              _checkPermissions();
            },
          ),
          Divider(height: 20, color: BentoTheme.divider),
          _permissionRow(
            title: 'Full-Screen Intent',
            subtitle: 'Displays alarm over lockscreen when phone is sleeping',
            isGranted: true, // Configured in Android manifest
            isInfoOnly: true,
          ),
          Divider(height: 20, color: BentoTheme.divider),
          _permissionRow(
            title: 'Battery Optimization',
            subtitle: 'Avoid OS killing scheduled alarms during deep doze mode',
            isGranted: _isBatteryIgnored,
            onFix: () async {
              await Permission.ignoreBatteryOptimizations.request();
              _checkPermissions();
            },
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(LucideIcons.externalLink, size: 14),
              label: const Text('Open System App Settings'),
              style: OutlinedButton.styleFrom(
                foregroundColor: BentoTheme.textSecondary,
                side: BorderSide(color: BentoTheme.divider),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => openAppSettings(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _permissionRow({
    required String title,
    required String subtitle,
    required bool isGranted,
    bool isInfoOnly = false,
    VoidCallback? onFix,
  }) {
    final statusColor = isGranted ? BentoTheme.positive : BentoTheme.negative;
    final statusText = isGranted ? 'Granted' : 'Denied';

    return Row(
      children: [
        Icon(
          isGranted ? LucideIcons.checkCircle2 : LucideIcons.alertCircle,
          size: 18,
          color: statusColor,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: BentoTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isInfoOnly ? 'Active' : statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: BentoTheme.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        if (!isGranted && !isInfoOnly && onFix != null) ...[
          const SizedBox(width: 8),
          TextButton(
            onPressed: onFix,
            style: TextButton.styleFrom(
              foregroundColor: BentoTheme.accent,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
            child: const Text('Grant', style: TextStyle(fontSize: 12)),
          ),
        ],
      ],
    );
  }
}
