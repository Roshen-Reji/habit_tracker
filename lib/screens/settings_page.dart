import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:habit_tracker/data/models/goal.dart';
import 'package:habit_tracker/data/services/ai_service.dart';
import 'package:habit_tracker/data/services/gemini_client.dart';
import 'package:habit_tracker/core/theme/app_colors.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/app_tokens.dart';
import 'package:habit_tracker/screens/home_layout_settings_page.dart';
import 'package:habit_tracker/features/wearables/ui/wearables_settings_page.dart';
import 'package:habit_tracker/features/finance/ui/settings/reminders_settings_page.dart';
import 'package:habit_tracker/features/finance/ui/settings/finance_privacy_data_page.dart';
import 'package:habit_tracker/features/finance/ui/ai/ai_privacy_page.dart';
import 'package:habit_tracker/models/speech_model.dart';
import 'package:habit_tracker/core/progression/progression_service.dart';
import 'package:habit_tracker/core/widgets/progress_bar_x.dart';
import 'package:habit_tracker/data/models/user_rank.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initBoxes();
  }

  Future<void> _initBoxes() async {
    try {
      if (!Hive.isBoxOpen('settings')) {
        await Hive.openBox('settings');
      }
      if (!Hive.isBoxOpen('finance_settings')) {
        await Hive.openBox('finance_settings');
      }
      if (!Hive.isBoxOpen('mission_box_v4')) {
        await Hive.openBox<Goal>('mission_box_v4');
      }
      if (!Hive.isBoxOpen('speech_vault')) {
        await Hive.openBox<SpeechModel>('speech_vault');
      }
    } catch (e) {
      debugPrint('Settings initialization warning: $e');
    }
    if (mounted) {
      setState(() => _isInitialized = true);
    }
  }

  Box? get _settingsBox =>
      Hive.isBoxOpen('settings') ? Hive.box('settings') : null;

  T _getSetting<T>(String key, T defaultValue) {
    final box = _settingsBox;
    if (box == null) return defaultValue;
    final val = box.get(key, defaultValue: defaultValue);
    if (val is T) return val;
    return defaultValue;
  }

  void _putSetting<T>(String key, T value) {
    _settingsBox?.put(key, value);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final tokens = AppTokens.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Column(
                children: [
                  _buildProfileSection(),
                  const SizedBox(height: 28),
                  _buildAppearanceGroup(tokens),
                  const SizedBox(height: 24),
                  _buildDashboardLayoutGroup(),
                  const SizedBox(height: 24),
                  _buildModulesAndSyncGroup(),
                  const SizedBox(height: 24),
                  _buildAiAndHealthGroup(),
                  const SizedBox(height: 24),
                  _buildDataManagementGroup(),
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 90,
      backgroundColor: Colors.transparent,
      elevation: 0,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: false,
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
        title: Text(
          "S E T T I N G S",
          style: TextStyle(
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: BentoTheme.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildProfileSection() {
    return ValueListenableBuilder<UserRank>(
      valueListenable: ProgressionService.rankListenable,
      builder: (context, rank, _) {
        final box = _settingsBox;
        if (box == null) {
          return _buildProfileCard('USER', rank);
        }
        return ValueListenableBuilder(
          valueListenable: box.listenable(keys: ['username']),
          builder: (context, Box settings, _) {
            final String name = settings.get('username', defaultValue: 'USER');
            return _buildProfileCard(name, rank);
          },
        );
      },
    );
  }

  Widget _buildProfileCard(String name, UserRank rank) {
    return BentoContainer(
      borderRadius: AppTokens.radiusLg,
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: BentoTheme.accent,
                child: Icon(
                  LucideIcons.user,
                  size: 28,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: BentoTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      rank.position,
                      style: TextStyle(
                        color: BentoTheme.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      "RANK: ${rank.title} (LVL ${rank.level})",
                      style: TextStyle(
                        color: BentoTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  LucideIcons.edit,
                  color: BentoTheme.textSecondary,
                  size: 18,
                ),
                onPressed: () => _editUsername(),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const XpProgressBar(height: 6),
        ],
      ),
    );
  }

  Widget _buildSettingGroup(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              color: BentoTheme.accent,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ),
        BentoContainer(
          borderRadius: AppTokens.radiusLg,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Material(
            type: MaterialType.transparency,
            child: Column(children: children),
          ),
        ),
      ],
    );
  }

  Widget _buildAppearanceGroup(AppTokens tokens) {
    final modeStr = _getSetting<String>('theme_mode', 'dark');

    return ValueListenableBuilder<AppColorSchemePreset>(
      valueListenable: AppTheme.presetNotifier,
      builder: (context, activePreset, _) {
        return _buildSettingGroup("APPEARANCE & THEME", [
          // Theme Mode Selector
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(LucideIcons.sunMedium,
                        size: 18, color: BentoTheme.textPrimary),
                    const SizedBox(width: 8),
                    Text(
                      "Theme Mode",
                      style: TextStyle(
                        color: BentoTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildModePill("System", modeStr == 'system', () {
                      _putSetting('theme_mode', 'system');
                      setState(() {});
                    }),
                    const SizedBox(width: 8),
                    _buildModePill("Dark", modeStr == 'dark', () {
                      _putSetting('theme_mode', 'dark');
                      setState(() {});
                    }),
                    const SizedBox(width: 8),
                    _buildModePill("Light", modeStr == 'light', () {
                      _putSetting('theme_mode', 'light');
                      setState(() {});
                    }),
                  ],
                ),
              ],
            ),
          ),
          Divider(color: BentoTheme.divider, height: 1),

          // Color Scheme Selector
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(LucideIcons.palette,
                        size: 18, color: BentoTheme.textPrimary),
                    const SizedBox(width: 8),
                    Text(
                      "Color Scheme Preset",
                      style: TextStyle(
                        color: BentoTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  "High-contrast native backgrounds with tuned accent highlights",
                  style: TextStyle(
                    color: BentoTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 12),
                _buildPresetSelector(activePreset),
              ],
            ),
          ),
          Divider(color: BentoTheme.divider, height: 1),

          // Mission Alerts Toggle
          _buildToggleTile(
            LucideIcons.bellRing,
            "Mission Alerts",
            _notificationsEnabled,
            (v) => setState(() => _notificationsEnabled = v),
          ),
        ]);
      },
    );
  }

  Widget _buildModePill(String label, bool isSelected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? BentoTheme.accent.withValues(alpha: 0.15)
                : BentoTheme.surfaceSunken,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? BentoTheme.accent : BentoTheme.divider,
              width: 1.0,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? BentoTheme.accent : BentoTheme.textSecondary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPresetSelector(AppColorSchemePreset activePreset) {
    final presets = AppColorSchemePreset.values;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: presets.map((preset) {
        final isSelected = preset == activePreset;
        final swatch = preset.swatchColor;

        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            AppTheme.setPreset(preset);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? swatch.withValues(alpha: 0.12)
                  : BentoTheme.surfaceSunken,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? swatch : BentoTheme.divider,
                width: isSelected ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: swatch,
                    border: Border.all(
                      color: preset == AppColorSchemePreset.monochrome
                          ? Colors.grey
                          : Colors.transparent,
                      width: 0.8,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  preset.displayName,
                  style: TextStyle(
                    color: isSelected ? BentoTheme.textPrimary : BentoTheme.textSecondary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 6),
                  Icon(LucideIcons.check, size: 12, color: swatch),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDashboardLayoutGroup() {
    return _buildSettingGroup("DASHBOARD & CARDS", [
      _buildActionTile(
        LucideIcons.layoutGrid,
        "Home Layout",
        "Reorder, resize & toggle home cards",
        () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const HomeLayoutSettingsPage(),
            ),
          );
        },
      ),
    ]);
  }

  Widget _buildModulesAndSyncGroup() {
    String currency = _getSetting<String>('currency_symbol', '₹');

    return _buildSettingGroup("MODULES & SYNC", [
      _buildActionTile(
        LucideIcons.watch,
        "Galaxy Watch & Wearables",
        "Samsung Health sync, AGEs index & sleep",
        () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const WearablesSettingsPage(),
            ),
          );
        },
      ),
      _buildActionTile(
        LucideIcons.bellRing,
        "Finance Reminders & Alarms",
        "Schedules, styles, permissions & test",
        () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const RemindersSettingsPage(),
            ),
          );
        },
      ),
      _buildActionTile(
        LucideIcons.coins,
        "Finance Currency",
        currency,
        () => _editCurrency(),
      ),
    ]);
  }

  Widget _buildAiAndHealthGroup() {
    int calorieTarget = _getSetting<int>('daily_calorie_target', 2000);
    String modelOverride =
        _getSetting<String>('gemini_model', '');

    return _buildSettingGroup("AI PRIVACY & HEALTH", [
      _buildActionTile(
        LucideIcons.shieldAlert,
        "AI Privacy Controls",
        "Local-first privacy, context toggles & model permissions",
        () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AiPrivacyPage(),
            ),
          );
        },
      ),
      _buildActionTile(
        LucideIcons.key,
        "Gemini API Key",
        AiService.instance.configurationSummary,
        () => _editAiKey(),
      ),
      _buildActionTile(
        LucideIcons.cpu,
        "Gemini Model Override",
        modelOverride.isEmpty ? "Auto (Flash fallback chain)" : modelOverride,
        () => _editAiModel(),
      ),
      _buildActionTile(
        LucideIcons.activity,
        "Test Connection",
        "Verify API key and model connectivity",
        () => _testGeminiConnection(),
      ),
      _buildActionTile(
        LucideIcons.flame,
        "Daily Calorie Target",
        "$calorieTarget kcal",
        () => _editCalorieTarget(),
      ),
    ]);
  }

  Widget _buildDataManagementGroup() {
    return _buildSettingGroup("DATA MANAGEMENT", [
      _buildActionTile(
        LucideIcons.shieldCheck,
        "Privacy, Backup & Encryption",
        "AES-256 data lock, JSON export & CSV/SMS import",
        () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const FinancePrivacyDataPage(),
            ),
          );
        },
      ),
      _buildActionTile(
        LucideIcons.refreshCw,
        "Reset Daily Streaks",
        "Keep rank, reset daily targets",
        _resetAllDailyGoals,
      ),
      _buildActionTile(
        LucideIcons.trash2,
        "Purge Mission Data",
        "Wipe progress and reset position",
        _confirmDataPurge,
        isDestructive: true,
      ),
    ]);
  }

  Widget _buildToggleTile(
    IconData icon,
    String title,
    bool value,
    Function(bool) onChanged,
  ) {
    return ListTile(
      leading: Icon(icon, color: BentoTheme.textPrimary, size: 20),
      title: Text(
        title,
        style: TextStyle(color: BentoTheme.textPrimary, fontSize: 15),
      ),
      trailing: BentoToggle(
        value: value,
        onChanged: (v) {
          HapticFeedback.lightImpact();
          onChanged(v);
        },
      ),
    );
  }

  Widget _buildActionTile(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return ListTile(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      leading: Icon(
        icon,
        color: isDestructive ? Colors.redAccent : BentoTheme.textPrimary,
        size: 20,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? Colors.redAccent : BentoTheme.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: BentoTheme.textSecondary, fontSize: 11),
      ),
      trailing: Icon(
        LucideIcons.chevronRight,
        color: BentoTheme.textSecondary,
        size: 18,
      ),
    );
  }

  void _editUsername() {
    final controller =
        TextEditingController(text: _getSetting<String>('username', 'USER'));
    _showInputDialog("Update Username", controller, (val) {
      _putSetting('username', val.toUpperCase());
      setState(() {});
    });
  }

  void _editAiKey() {
    final controller =
        TextEditingController(text: _getSetting<String>('gemini_api_key', ''));
    _showInputDialog("Update Gemini API Key", controller, (val) {
      _putSetting('gemini_api_key', val.trim());
      setState(() {});
    });
  }

  void _editAiModel() {
    final current = _getSetting<String>('gemini_model', '');
    final controller = TextEditingController(text: current);
    _showInputDialog("Gemini Model Override", controller, (val) {
      _putSetting('gemini_model', val.trim());
      setState(() {});
    });
  }

  void _testGeminiConnection() async {
    final apiKey = _getSetting<String>('gemini_api_key', '').trim();
    if (apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No Gemini API key configured. Enter one in Settings first."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Testing Gemini connection..."),
        duration: Duration(seconds: 1),
      ),
    );

    final client = GeminiClient();
    final box = _settingsBox ?? await Hive.openBox('settings');
    final result = await client.testConnection(apiKey: apiKey, settingsBox: box);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BentoTheme.background,
        title: Text(
          result.isSuccess ? "Connection Successful" : "Connection Failed",
          style: TextStyle(
            color: result.isSuccess ? Colors.greenAccent : Colors.redAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          result.isSuccess
              ? "Successfully connected to Gemini API!\n\nModel used: ${result.modelUsed}\nStatus code: ${result.statusCode}"
              : "Connection test failed.\n\nStatus code: ${result.statusCode}\nDetails: ${result.errorMessage}",
          style: TextStyle(color: BentoTheme.textPrimary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("OK", style: TextStyle(color: BentoTheme.accent)),
          ),
        ],
      ),
    );
  }

  void _editCalorieTarget() {
    final controller = TextEditingController(
        text: _getSetting<int>('daily_calorie_target', 2000).toString());
    _showInputDialog("Update Calorie Target", controller, (val) {
      final target = int.tryParse(val);
      if (target != null) {
        _putSetting('daily_calorie_target', target);
        setState(() {});
      }
    }, isNumber: true);
  }

  void _editCurrency() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BentoTheme.background,
        title: Text(
          "Select Currency",
          style: TextStyle(color: BentoTheme.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['\$', '€', '£', '₹', '¥']
              .map(
                (sym) => ListTile(
                  title: Text(
                    sym,
                    style: TextStyle(
                      color: BentoTheme.textPrimary,
                      fontSize: 20,
                    ),
                  ),
                  onTap: () {
                    _putSetting('currency_symbol', sym);
                    Navigator.pop(context);
                    setState(() {});
                  },
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  void _showInputDialog(
    String title,
    TextEditingController controller,
    Function(String) onSave, {
    bool isNumber = false,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BentoTheme.background,
        title: Text(title, style: TextStyle(color: BentoTheme.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          style: TextStyle(color: BentoTheme.textPrimary),
          decoration: InputDecoration(
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: BentoTheme.accent),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Cancel",
              style: TextStyle(color: BentoTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              onSave(controller.text);
              Navigator.pop(context);
            },
            child: Text("Apply", style: TextStyle(color: BentoTheme.accent)),
          ),
        ],
      ),
    );
  }

  void _confirmDataPurge() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BentoTheme.background,
        title: const Text(
          "PURGE ALL DATA?",
          style: TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          "This will permanently delete missions and reset your service record.",
          style: TextStyle(color: BentoTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Abort",
              style: TextStyle(color: BentoTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              if (Hive.isBoxOpen('mission_box_v4')) {
                await Hive.box<Goal>('mission_box_v4').clear();
              }
              if (mounted) Navigator.pop(context);
            },
            child: const Text(
              "Confirm Purge",
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  void _resetAllDailyGoals() {
    if (Hive.isBoxOpen('mission_box_v4')) {
      final box = Hive.box<Goal>('mission_box_v4');
      for (var goal in box.values) {
        if (goal.type == GoalType.daily) goal.reset();
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Daily missions reset.")),
    );
  }
}
