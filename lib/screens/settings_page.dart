import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:habit_tracker/data/models/goal.dart';
import 'package:habit_tracker/data/services/ai_service.dart';
import 'package:habit_tracker/data/services/gemini_client.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/expressive_tokens.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;

  // Rank Ladder
  final List<String> _ranks = [
    "RECRUIT",
    "OPERATIVE",
    "SPECIALIST",
    "VETERAN",
    "LEADER",
    "LEGEND"
  ];

  /// Calculates Rank, Level, and the user's specific "Position" based on category focus
  Map<String, dynamic> _calculateServiceRecord(List<Goal> goals) {
    double totalXp = 0;
    Map<GoalCategory, int> categoryPoints = {};

    for (var goal in goals) {
      // Priority weighting for XP
      double weight = goal.type == GoalType.monthly
          ? 50.0
          : (goal.type == GoalType.weekly ? 20.0 : 5.0);

      if (goal.isCompleted) {
        totalXp += weight;
        categoryPoints[goal.category] =
            (categoryPoints[goal.category] ?? 0) + weight.toInt();
      }
      totalXp += (goal.streakCount * (weight * 0.1));
    }

    // Determine "Position" (Specialization) based on max points in a category
    String position = "UNASSIGNED";
    if (categoryPoints.isNotEmpty) {
      final bestCategory = categoryPoints.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
      switch (bestCategory) {
        case GoalCategory.learning:
          position = "LEAD RESEARCHER";
          break;
        case GoalCategory.fitness:
          position = "TACTICAL ATHLETE";
          break;
        case GoalCategory.productivity:
          position = "OPERATIONS CHIEF";
          break;
        case GoalCategory.health:
          position = "BIO-SECURITY OFFICER";
          break;
        case GoalCategory.hobby:
          position = "CREATIVE DIRECTOR";
          break;
      }
    }

    int level = (totalXp / 100).floor();
    int rankIndex = level.clamp(0, _ranks.length - 1);
    double progressToNext = (totalXp % 100) / 100;

    return {
      "title": _ranks[rankIndex],
      "position": position,
      "level": level + 1,
      "progress": progressToNext,
      "xp": totalXp.toInt()
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BentoTheme.background,
      body: ValueListenableBuilder(
          valueListenable: Hive.box<Goal>('mission_box_v4').listenable(),
          builder: (context, Box<Goal> missionBox, _) {
            final goals = missionBox.values.toList();
            final record = _calculateServiceRecord(goals);

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildAppBar(),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 20),
                    child: Column(
                      children: [
                        _buildProfileSection(record),
                        const SizedBox(height: 32),
                        _buildSystemConfigGroup(),
                        const SizedBox(height: 24),
                        _buildAiConfigGroup(),
                        const SizedBox(height: 24),
                        _buildDataManagementGroup(),
                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 100,
      backgroundColor: BentoTheme.background,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: false,
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
        title: Text("S E T T I N G S",
            style: TextStyle(
                letterSpacing: 2,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: BentoTheme.textPrimary)),
      ),
    );
  }

  Widget _buildProfileSection(Map<String, dynamic> record) {
    return ValueListenableBuilder(
      valueListenable: Hive.box('settings').listenable(),
      builder: (context, Box settings, _) {
        final String name = settings.get('username', defaultValue: 'USER');

        return BentoContainer(
          borderRadius: ExpressiveTokens.radiusXL,
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                      radius: 30,
                      backgroundColor: BentoTheme.accent,
                      child: Icon(LucideIcons.user,
                          size: 35, color: Colors.black)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: TextStyle(
                                color: BentoTheme.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                        Text(record['position'],
                            style: TextStyle(
                                color: BentoTheme.accent,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5)),
                        Text(
                            "RANK: ${record['title']} (LVL ${record['level']})",
                            style: TextStyle(
                                color: BentoTheme.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  IconButton(
                      icon: Icon(LucideIcons.edit,
                          color: BentoTheme.textSecondary, size: 18),
                      onPressed: () => _editUsername(settings)),
                ],
              ),
              const SizedBox(height: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("EVOLUTION PROGRESS",
                          style: TextStyle(
                              color: BentoTheme.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                      Text("${record['xp']} XP",
                          style: TextStyle(
                              color: BentoTheme.textSecondary, fontSize: 10)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: record['progress']),
                        duration: const Duration(milliseconds: 1500),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, _) {
                          return LinearProgressIndicator(
                            value: value,
                            backgroundColor:
                                BentoTheme.textPrimary.withValues(alpha: 0.1),
                            color: BentoTheme.accent,
                            minHeight: 6,
                          );
                        }),
                  ),
                ],
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildSettingGroup(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text(title,
              style: TextStyle(
                  color: BentoTheme.accent,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2)),
        ),
        BentoContainer(
          borderRadius: ExpressiveTokens.radiusL,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Material(
            type: MaterialType.transparency,
            child: Column(children: children),
          ),
        ),
      ],
    );
  }

  Widget _buildSystemConfigGroup() {
    return ValueListenableBuilder(
        valueListenable: Hive.box('settings').listenable(),
        builder: (context, Box settings, _) {
          bool dynamicBackground =
              settings.get('dynamic_background', defaultValue: true);
          String currency = settings.get('currency_symbol', defaultValue: '\$');
          bool isDarkMode =
              settings.get('theme_mode', defaultValue: 'dark') == 'dark';

          List<dynamic> rawFolders =
              settings.get('music_folders', defaultValue: []);
          List<String> musicFolders = rawFolders.cast<String>();

          return _buildSettingGroup("SYSTEM CONFIGURATION", [
            _buildToggleTile(LucideIcons.moon, "Dark Mode", isDarkMode, (v) {
              settings.put('theme_mode', v ? 'dark' : 'light');
            }),
            _buildToggleTile(
                LucideIcons.bellRing,
                "Mission Alerts",
                _notificationsEnabled,
                (v) => setState(() => _notificationsEnabled = v)),
            _buildToggleTile(
                LucideIcons.palette, "Dynamic Background", dynamicBackground,
                (v) {
              settings.put('dynamic_background', v);
            }),
            _buildActionTile(LucideIcons.coins, "Finance Currency", currency,
                () => _editCurrency(settings)),
            _buildActionTile(
                LucideIcons.folder,
                "Music Folders",
                musicFolders.isEmpty
                    ? "All Audio Files"
                    : "${musicFolders.length} Folders Selected",
                () => _manageMusicFolders(settings)),
          ]);
        });
  }

  Widget _buildAiConfigGroup() {
    return ValueListenableBuilder(
        valueListenable: Hive.box('settings').listenable(),
        builder: (context, Box settings, _) {
          int calorieTarget =
              settings.get('daily_calorie_target', defaultValue: 2000);
          String modelOverride =
              settings.get('gemini_model', defaultValue: '')?.toString() ?? '';

          return _buildSettingGroup("AI & HEALTH CONFIGURATION", [
            _buildActionTile(
                LucideIcons.key,
                "Gemini API Key",
                AiService.instance.configurationSummary,
                () => _editAiKey(settings)),
            _buildActionTile(
                LucideIcons.cpu,
                "Gemini Model Override",
                modelOverride.isEmpty
                    ? "Auto (Flash fallback chain)"
                    : modelOverride,
                () => _editAiModel(settings)),
            _buildActionTile(
                LucideIcons.activity,
                "Test Connection",
                "Verify API key and model connectivity",
                () => _testGeminiConnection(settings)),
            _buildActionTile(LucideIcons.flame, "Daily Calorie Target",
                "$calorieTarget kcal", () => _editCalorieTarget(settings)),
          ]);
        });
  }

  Widget _buildDataManagementGroup() {
    return _buildSettingGroup("DATA MANAGEMENT", [
      _buildActionTile(LucideIcons.trash2, "Purge Mission Data",
          "Wipe progress and reset position", _confirmDataPurge,
          isDestructive: true),
      _buildActionTile(LucideIcons.refreshCw, "Reset Daily Streaks",
          "Keep rank, reset daily targets", _resetAllDailyGoals),
    ]);
  }

  Widget _buildToggleTile(
      IconData icon, String title, bool value, Function(bool) onChanged) {
    return ListTile(
      leading: Icon(icon, color: BentoTheme.textPrimary, size: 22),
      title: Text(title,
          style: TextStyle(color: BentoTheme.textPrimary, fontSize: 15)),
      trailing: BentoToggle(
          value: value,
          onChanged: (v) {
            HapticFeedback.lightImpact();
            onChanged(v);
          }),
    );
  }

  Widget _buildActionTile(
      IconData icon, String title, String subtitle, VoidCallback onTap,
      {bool isDestructive = false}) {
    return ListTile(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      leading: Icon(icon,
          color: isDestructive ? Colors.redAccent : BentoTheme.textPrimary,
          size: 22),
      title: Text(title,
          style: TextStyle(
              color: isDestructive ? Colors.redAccent : BentoTheme.textPrimary,
              fontSize: 15)),
      subtitle: Text(subtitle,
          style: TextStyle(color: BentoTheme.textSecondary, fontSize: 11)),
      trailing: Icon(LucideIcons.chevronRight,
          color: BentoTheme.textSecondary, size: 20),
    );
  }

  void _editUsername(Box box) {
    final controller =
        TextEditingController(text: box.get('username', defaultValue: 'USER'));
    _showInputDialog("Update Username", controller, (val) {
      box.put('username', val.toUpperCase());
    });
  }

  void _editAiKey(Box box) {
    final controller = TextEditingController(
        text: box.get('gemini_api_key', defaultValue: ''));
    _showInputDialog("Update Gemini API Key", controller, (val) {
      box.put('gemini_api_key', val.trim());
    });
  }

  void _editAiModel(Box box) {
    final current = box.get('gemini_model', defaultValue: '')?.toString() ?? '';
    final controller = TextEditingController(text: current);
    _showInputDialog("Gemini Model Override", controller, (val) {
      box.put('gemini_model', val.trim());
    });
  }

  void _testGeminiConnection(Box box) async {
    final apiKey =
        box.get('gemini_api_key', defaultValue: '')?.toString().trim() ?? '';
    if (apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              "No Gemini API key configured. Enter one in Settings first."),
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
    final result =
        await client.testConnection(apiKey: apiKey, settingsBox: box);

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

  void _editCalorieTarget(Box box) {
    final controller = TextEditingController(
        text: box.get('daily_calorie_target', defaultValue: 2000).toString());
    _showInputDialog("Update Calorie Target", controller, (val) {
      final target = int.tryParse(val);
      if (target != null) {
        box.put('daily_calorie_target', target);
      }
    }, isNumber: true);
  }

  void _editCurrency(Box box) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BentoTheme.background,
        title: Text("Select Currency",
            style: TextStyle(color: BentoTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['\$', '€', '£', '₹', '¥']
              .map((sym) => ListTile(
                    title: Text(sym,
                        style: TextStyle(
                            color: BentoTheme.textPrimary, fontSize: 20)),
                    onTap: () {
                      box.put('currency_symbol', sym);
                      Navigator.pop(context);
                    },
                  ))
              .toList(),
        ),
      ),
    );
  }

  void _showInputDialog(
      String title, TextEditingController controller, Function(String) onSave,
      {bool isNumber = false}) {
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
                    borderSide: BorderSide(color: BentoTheme.accent)))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel",
                  style: TextStyle(color: BentoTheme.textSecondary))),
          TextButton(
              onPressed: () {
                onSave(controller.text);
                Navigator.pop(context);
              },
              child: Text("Apply", style: TextStyle(color: BentoTheme.accent))),
        ],
      ),
    );
  }

  void _confirmDataPurge() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BentoTheme.background,
        title: const Text("PURGE ALL DATA?",
            style: TextStyle(
                color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: Text(
            "This will permanently delete missions and reset your service record.",
            style: TextStyle(color: BentoTheme.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Abort",
                  style: TextStyle(color: BentoTheme.textSecondary))),
          TextButton(
              onPressed: () async {
                await Hive.box<Goal>('mission_box_v4').clear();
                if (mounted) Navigator.pop(context);
              },
              child: const Text("Confirm Purge",
                  style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
  }

  void _resetAllDailyGoals() {
    final box = Hive.box<Goal>('mission_box_v4');
    for (var goal in box.values) {
      if (goal.type == GoalType.daily) goal.reset();
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Daily missions reset.")));
  }

  void _manageMusicFolders(Box settings) {
    showModalBottomSheet(
      context: context,
      backgroundColor: BentoTheme.background,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            List<dynamic> raw = settings.get('music_folders', defaultValue: []);
            List<String> folders = raw.cast<String>().toList();

            return Container(
              padding: const EdgeInsets.all(24),
              height: 400,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Music Folders",
                      style: TextStyle(
                          color: BentoTheme.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                      "Select which folders the app should scan for music. If empty, the entire device will be scanned.",
                      style: TextStyle(
                          color: BentoTheme.textSecondary, fontSize: 13)),
                  const SizedBox(height: 16),
                  Expanded(
                    child: folders.isEmpty
                        ? Center(
                            child: Text("Scanning all files",
                                style: TextStyle(
                                    color: BentoTheme.textSecondary,
                                    fontStyle: FontStyle.italic)))
                        : ListView.builder(
                            prototypeItem: const ListTile(
                                title: Text(''), subtitle: Text('')),
                            itemCount: folders.length,
                            itemBuilder: (context, i) {
                              return ListTile(
                                leading: Icon(LucideIcons.folder,
                                    color: BentoTheme.accent),
                                title: Text(
                                  folders[i].split('/').last,
                                  style:
                                      TextStyle(color: BentoTheme.textPrimary),
                                ),
                                subtitle: Text(
                                  folders[i],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: BentoTheme.textSecondary,
                                      fontSize: 10),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(LucideIcons.x,
                                      color: Colors.redAccent),
                                  onPressed: () {
                                    setModalState(() {
                                      folders.removeAt(i);
                                      settings.put('music_folders', folders);
                                    });
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            BentoTheme.accent.withValues(alpha: 0.2),
                        foregroundColor: BentoTheme.accent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        String? selectedDirectory =
                            await FilePicker.platform.getDirectoryPath();
                        if (selectedDirectory != null) {
                          if (!folders.contains(selectedDirectory)) {
                            setModalState(() {
                              folders.add(selectedDirectory);
                              settings.put('music_folders', folders);
                            });
                          }
                        }
                      },
                      icon: const Icon(LucideIcons.plus),
                      label: const Text("Add Folder",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }
}
