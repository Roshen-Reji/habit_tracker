import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/expressive_tokens.dart';
import 'package:habit_tracker/data/models/health_models.dart';
import 'package:habit_tracker/data/services/medicine_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/features/wearables/ui/fitness_tab.dart';

class HealthPage extends StatefulWidget {
  final int initialTab; // 0: Medicine, 1: Weight

  const HealthPage({super.key, this.initialTab = 0});

  @override
  State<HealthPage> createState() => _HealthPageState();
}

class _HealthPageState extends State<HealthPage> {
  late int _selectedTab;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BentoTheme.background,
      appBar: AppBar(
        backgroundColor: BentoTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: BentoTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'HEALTH & WELLNESS',
          style: TextStyle(
            color: BentoTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Expressive Tab Switcher
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: BentoTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildTabButton(0, 'MEDICINE', LucideIcons.pill),
                ),
                Expanded(
                  child: _buildTabButton(1, 'WEIGHT', LucideIcons.scale),
                ),
                Expanded(
                  child: _buildTabButton(2, 'GALAXY WATCH', LucideIcons.watch),
                ),
              ],
            ),
          ),

          // Tab content
          Expanded(
            child: _selectedTab == 0
                ? const _MedicineTab()
                : (_selectedTab == 1 ? const _WeightTab() : const FitnessTab()),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _selectedTab = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? BentoTheme.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color:
                  isSelected ? BentoTheme.background : BentoTheme.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? BentoTheme.background
                    : BentoTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== MEDICINE TAB ====================
class _MedicineTab extends StatefulWidget {
  const _MedicineTab();

  @override
  State<_MedicineTab> createState() => _MedicineTabState();
}

class _MedicineTabState extends State<_MedicineTab> {
  void _openAddMedicineDialog([Medicine? existing]) {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final doseController =
        TextEditingController(text: existing?.doseLabel ?? '');
    final notesController = TextEditingController(text: existing?.notes ?? '');

    List<int> times =
        existing?.timesMinutes.toList() ?? [480]; // default 8:00 AM
    List<int> weekdays = existing?.weekdays.toList() ?? [];
    DateTime startDate = existing?.startDate ?? DateTime.now();
    DateTime? endDate = existing?.endDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.fromLTRB(
                24,
                20,
                24,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: BentoTheme.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 1,
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      existing == null ? 'NEW MEDICINE' : 'EDIT MEDICINE',
                      style: TextStyle(
                        color: BentoTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Name
                    TextField(
                      controller: nameController,
                      style: TextStyle(color: BentoTheme.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Medicine Name',
                        labelStyle: TextStyle(color: BentoTheme.textSecondary),
                        filled: true,
                        fillColor: BentoTheme.surfaceElevated,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Dose
                    TextField(
                      controller: doseController,
                      style: TextStyle(color: BentoTheme.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Dose (e.g. 500mg, 1 tablet)',
                        labelStyle: TextStyle(color: BentoTheme.textSecondary),
                        filled: true,
                        fillColor: BentoTheme.surfaceElevated,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Reminder Times
                    Text(
                      'REMINDER TIMES',
                      style: TextStyle(
                        color: BentoTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ...times.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final mins = entry.value;
                          final timeStr =
                              '${(mins ~/ 60).toString().padLeft(2, '0')}:${(mins % 60).toString().padLeft(2, '0')}';
                          return Chip(
                            backgroundColor: BentoTheme.surfaceElevated,
                            label: Text(timeStr,
                                style:
                                    TextStyle(color: BentoTheme.textPrimary)),
                            deleteIcon: const Icon(LucideIcons.x, size: 14),
                            deleteIconColor: Colors.redAccent,
                            onDeleted: times.length > 1
                                ? () {
                                    setModalState(() => times.removeAt(idx));
                                  }
                                : null,
                          );
                        }),
                        ActionChip(
                          avatar: Icon(LucideIcons.plus,
                              size: 14, color: BentoTheme.accent),
                          backgroundColor:
                              BentoTheme.accent.withValues(alpha: 0.15),
                          label: Text('Add Time',
                              style: TextStyle(color: BentoTheme.accent)),
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: const TimeOfDay(hour: 8, minute: 0),
                            );
                            if (picked != null) {
                              final total = picked.hour * 60 + picked.minute;
                              if (!times.contains(total)) {
                                setModalState(() {
                                  times.add(total);
                                  times.sort();
                                });
                              }
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Days of week
                    Text(
                      'ACTIVE DAYS (Empty = Every Day)',
                      style: TextStyle(
                        color: BentoTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (int i = 1; i <= 7; i++)
                          _buildDayChip(i, weekdays, (day) {
                            setModalState(() {
                              if (weekdays.contains(day)) {
                                weekdays.remove(day);
                              } else {
                                weekdays.add(day);
                                weekdays.sort();
                              }
                            });
                          }),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Notes
                    TextField(
                      controller: notesController,
                      style: TextStyle(color: BentoTheme.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Notes (Optional, e.g. After meal)',
                        labelStyle: TextStyle(color: BentoTheme.textSecondary),
                        filled: true,
                        fillColor: BentoTheme.surfaceElevated,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: BentoTheme.accent,
                          foregroundColor: BentoTheme.background,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () async {
                          final name = nameController.text.trim();
                          if (name.isEmpty) return;

                          final med = Medicine(
                            id: existing?.id ??
                                'med_${DateTime.now().millisecondsSinceEpoch}',
                            name: name,
                            doseLabel: doseController.text.trim().isEmpty
                                ? '1 dose'
                                : doseController.text.trim(),
                            timesMinutes: times,
                            weekdays: weekdays,
                            startDate: startDate,
                            endDate: endDate,
                            notes: notesController.text.trim(),
                            active: existing?.active ?? true,
                          );

                          final box = Hive.box<Medicine>('medicines');
                          await box.put(med.id, med);
                          await MedicineService.scheduleMedicine(med);

                          if (mounted) Navigator.pop(sheetContext);
                        },
                        child: Text(
                          existing == null
                              ? 'CREATE MEDICINE'
                              : 'UPDATE MEDICINE',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDayChip(
      int day, List<int> selectedDays, Function(int) onToggle) {
    const dayNames = ['', 'M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final isSelected = selectedDays.contains(day);

    return GestureDetector(
      onTap: () => onToggle(day),
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? BentoTheme.accent : BentoTheme.surfaceElevated,
          shape: BoxShape.circle,
        ),
        child: Text(
          dayNames[day],
          style: TextStyle(
            color:
                isSelected ? BentoTheme.background : BentoTheme.textSecondary,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box<Medicine>>(
      valueListenable: Hive.box<Medicine>('medicines').listenable(),
      builder: (context, medBox, _) {
        return ValueListenableBuilder<Box<MedicineLog>>(
          valueListenable: Hive.box<MedicineLog>('medicine_logs').listenable(),
          builder: (context, logBox, _) {
            final stats = MedicineService.getDailyStats(
              medicines: medBox.values.toList(),
              logs: logBox.values.toList(),
            );

            final medicines = medBox.values.toList();

            return Scaffold(
              backgroundColor: Colors.transparent,
              floatingActionButton: FloatingActionButton(
                backgroundColor: BentoTheme.accent,
                foregroundColor: BentoTheme.background,
                onPressed: () => _openAddMedicineDialog(),
                child: const Icon(LucideIcons.plus),
              ),
              body: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
                children: [
                  // Daily Progress Card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: BentoTheme.surface,
                      borderRadius:
                          BorderRadius.circular(ExpressiveTokens.radiusCard),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "TODAY'S ADHERENCE",
                              style: TextStyle(
                                color: BentoTheme.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${stats.takenDosesToday} / ${stats.totalDosesToday} TAKEN',
                                style: const TextStyle(
                                  color: Color(0xFF10B981),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: stats.complianceRate,
                            minHeight: 6,
                            backgroundColor: Colors.white12,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFF10B981)),
                          ),
                        ),
                        if (stats.nextDoseMedicine != null &&
                            stats.nextDoseTime != null) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(LucideIcons.clock,
                                  size: 14, color: BentoTheme.accent),
                              const SizedBox(width: 6),
                              Text(
                                'Next: ${stats.nextDoseMedicine!.name} at ${DateFormat('h:mm a').format(stats.nextDoseTime!)}',
                                style: TextStyle(
                                  color: BentoTheme.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (medicines.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      alignment: Alignment.center,
                      child: Column(
                        children: [
                          Icon(LucideIcons.pill,
                              size: 48, color: BentoTheme.textSecondary),
                          const SizedBox(height: 12),
                          Text(
                            'No medicines added yet',
                            style: TextStyle(
                              color: BentoTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap + below to add your first medicine reminder',
                            style: TextStyle(
                              color: BentoTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...medicines.map((med) => _buildMedicineTile(med)),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMedicineTile(Medicine med) {
    final timesStr = med.timesMinutes
        .map((m) =>
            '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}')
        .join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BentoTheme.surface,
        borderRadius: BorderRadius.circular(ExpressiveTokens.radiusCard),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: med.active
                  ? BentoTheme.accent.withValues(alpha: 0.15)
                  : Colors.white10,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              LucideIcons.pill,
              color: med.active ? BentoTheme.accent : BentoTheme.textSecondary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  med.name,
                  style: TextStyle(
                    color: BentoTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${med.doseLabel} • $timesStr',
                  style: TextStyle(
                    color: BentoTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
                if (med.notes.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    med.notes,
                    style: TextStyle(
                      color: BentoTheme.textSecondary.withValues(alpha: 0.7),
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Action buttons: Take today & Edit
          IconButton(
            icon: const Icon(LucideIcons.check, color: Color(0xFF10B981)),
            onPressed: () async {
              HapticFeedback.mediumImpact();
              await MedicineService.markTaken(med.id, DateTime.now());
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Logged ${med.name} as taken!'),
                    backgroundColor: const Color(0xFF10B981),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
          PopupMenuButton<String>(
            icon: Icon(LucideIcons.moreVertical,
                color: BentoTheme.textSecondary, size: 18),
            color: BentoTheme.surface,
            onSelected: (val) async {
              if (val == 'edit') {
                _openAddMedicineDialog(med);
              } else if (val == 'toggle') {
                final updated = Medicine(
                  id: med.id,
                  name: med.name,
                  doseLabel: med.doseLabel,
                  timesMinutes: med.timesMinutes,
                  weekdays: med.weekdays,
                  startDate: med.startDate,
                  endDate: med.endDate,
                  notes: med.notes,
                  active: !med.active,
                );
                final box = Hive.box<Medicine>('medicines');
                await box.put(updated.id, updated);
                await MedicineService.scheduleMedicine(updated);
              } else if (val == 'delete') {
                await MedicineService.cancelMedicine(med);
                await med.delete();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'edit',
                child: Text('Edit',
                    style: TextStyle(color: BentoTheme.textPrimary)),
              ),
              PopupMenuItem(
                value: 'toggle',
                child: Text(
                  med.active ? 'Pause Reminders' : 'Resume Reminders',
                  style: TextStyle(color: BentoTheme.textPrimary),
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child:
                    Text('Delete', style: TextStyle(color: Colors.redAccent)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ==================== WEIGHT TAB ====================
class _WeightTab extends StatefulWidget {
  const _WeightTab();

  @override
  State<_WeightTab> createState() => _WeightTabState();
}

class _WeightTabState extends State<_WeightTab> {
  void _openLogWeightDialog() {
    final weightController = TextEditingController();
    final noteController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          padding: EdgeInsets.fromLTRB(
            24,
            20,
            24,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          decoration: BoxDecoration(
            color: BentoTheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'LOG TODAY\'S WEIGHT',
                style: TextStyle(
                  color: BentoTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: weightController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                style: TextStyle(
                  color: BentoTheme.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  labelText: 'Weight (kg)',
                  labelStyle: TextStyle(color: BentoTheme.textSecondary),
                  filled: true,
                  fillColor: BentoTheme.surfaceElevated,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                style: TextStyle(color: BentoTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Note (Optional, e.g. Morning, fasted)',
                  labelStyle: TextStyle(color: BentoTheme.textSecondary),
                  filled: true,
                  fillColor: BentoTheme.surfaceElevated,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BentoTheme.accent,
                    foregroundColor: BentoTheme.background,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () async {
                    final val = double.tryParse(weightController.text.trim());
                    if (val == null || val <= 0) return;

                    final today =
                        DateFormat('yyyy-MM-dd').format(DateTime.now());
                    final entry = WeightEntry(
                      date: today,
                      kg: val,
                      note: noteController.text.trim(),
                    );

                    final box = Hive.box<WeightEntry>('weight_entries');
                    await box.put(today, entry);

                    if (mounted) Navigator.pop(sheetContext);
                  },
                  child: const Text(
                    'SAVE WEIGHT',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openSettingsDialog() {
    final settingsBox = Hive.box('settings');
    final startController = TextEditingController(
        text: settingsBox.get('weight_start')?.toString() ?? '');
    final goalController = TextEditingController(
        text: settingsBox.get('weight_goal')?.toString() ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BentoTheme.surface,
        title: Text('Weight Journey Goals',
            style: TextStyle(color: BentoTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: startController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(color: BentoTheme.textPrimary),
              decoration: InputDecoration(
                labelText: 'Starting Weight (kg)',
                labelStyle: TextStyle(color: BentoTheme.textSecondary),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: goalController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(color: BentoTheme.textPrimary),
              decoration: InputDecoration(
                labelText: 'Target / Goal Weight (kg)',
                labelStyle: TextStyle(color: BentoTheme.textSecondary),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: BentoTheme.accent,
              foregroundColor: BentoTheme.background,
            ),
            onPressed: () {
              final start = double.tryParse(startController.text.trim());
              final goal = double.tryParse(goalController.text.trim());
              if (start != null) settingsBox.put('weight_start', start);
              if (goal != null) settingsBox.put('weight_goal', goal);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box<WeightEntry>>(
      valueListenable: Hive.box<WeightEntry>('weight_entries').listenable(),
      builder: (context, box, _) {
        final entries = box.values.toList();
        entries.sort((a, b) => a.date.compareTo(b.date));

        final settingsBox = Hive.box('settings');
        final startWeight =
            (settingsBox.get('weight_start') as num?)?.toDouble();
        final goalWeight = (settingsBox.get('weight_goal') as num?)?.toDouble();
        final latestWeight = entries.isNotEmpty ? entries.last.kg : startWeight;

        return Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: FloatingActionButton(
            backgroundColor: BentoTheme.accent,
            foregroundColor: BentoTheme.background,
            onPressed: _openLogWeightDialog,
            child: const Icon(LucideIcons.plus),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
            children: [
              // Summary Banner
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: BentoTheme.surface,
                  borderRadius:
                      BorderRadius.circular(ExpressiveTokens.radiusCard),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStatColumn('START',
                            startWeight != null ? '$startWeight kg' : '--'),
                        _buildStatColumn('CURRENT',
                            latestWeight != null ? '$latestWeight kg' : '--',
                            isCurrent: true),
                        _buildStatColumn('TARGET',
                            goalWeight != null ? '$goalWeight kg' : '--'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _openSettingsDialog,
                      icon: const Icon(LucideIcons.settings, size: 14),
                      label: const Text('Configure Start & Goal',
                          style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: BentoTheme.textSecondary,
                        side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.1)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Full Weight LineChart
              if (entries.length >= 2) ...[
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                  height: 220,
                  decoration: BoxDecoration(
                    color: BentoTheme.surface,
                    borderRadius:
                        BorderRadius.circular(ExpressiveTokens.radiusCard),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                      width: 1,
                    ),
                  ),
                  child: LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: false),
                      titlesData: const FlTitlesData(
                        topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: entries
                              .asMap()
                              .entries
                              .map((e) => FlSpot(e.key.toDouble(), e.value.kg))
                              .toList(),
                          isCurved: true,
                          color: BentoTheme.accent,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: true),
                          belowBarData: BarAreaData(
                            show: true,
                            color: BentoTheme.accent.withValues(alpha: 0.15),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // History list
              Text(
                'WEIGHT LOG HISTORY',
                style: TextStyle(
                  color: BentoTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),

              if (entries.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  alignment: Alignment.center,
                  child: Text(
                    'No weight logs recorded yet',
                    style: TextStyle(color: BentoTheme.textSecondary),
                  ),
                )
              else
                ...entries.reversed.map((e) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: BentoTheme.surface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e.date,
                              style: TextStyle(
                                color: BentoTheme.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            if (e.note.isNotEmpty)
                              Text(
                                e.note,
                                style: TextStyle(
                                  color: BentoTheme.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                        Text(
                          '${e.kg} kg',
                          style: TextStyle(
                            color: BentoTheme.accent,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatColumn(String label, String value,
      {bool isCurrent = false}) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: BentoTheme.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: isCurrent ? BentoTheme.accent : BentoTheme.textPrimary,
            fontSize: isCurrent ? 20 : 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
