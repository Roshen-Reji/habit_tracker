import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/expressive_tokens.dart';
import 'package:habit_tracker/features/wearables/data/wearable_repository.dart';
import 'package:habit_tracker/features/wearables/models/ages_sample.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class AgesLogSheet extends StatefulWidget {
  final AgesSample? initialSample;

  const AgesLogSheet({super.key, this.initialSample});

  static Future<void> show(BuildContext context, {AgesSample? sample}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: BentoTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => AgesLogSheet(initialSample: sample),
    );
  }

  @override
  State<AgesLogSheet> createState() => _AgesLogSheetState();
}

class _AgesLogSheetState extends State<AgesLogSheet> {
  late final TextEditingController _scoreController;
  late final TextEditingController _noteController;
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;

  @override
  void initState() {
    super.initState();
    final init = widget.initialSample;
    _scoreController = TextEditingController(
      text: init != null ? init.score.toString() : '',
    );
    _noteController = TextEditingController(
      text: init?.extraJson != null
          ? (tryExtractNote(init!.extraJson!) ?? '')
          : '',
    );
    _selectedDate = init?.timestamp ?? DateTime.now();
    _selectedTime = TimeOfDay.fromDateTime(_selectedDate);
  }

  static String? tryExtractNote(String jsonStr) {
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is Map && decoded['note'] != null) {
        return decoded['note'].toString();
      }
    } catch (_) {}
    return null;
  }

  @override
  void dispose() {
    _scoreController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _save() async {
    final text = _scoreController.text.trim();
    final score = double.tryParse(text);
    if (score == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter a valid numeric AGEs score')),
      );
      return;
    }

    final combinedTs = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final id = widget.initialSample?.id ??
        'manual_ages_${combinedTs.millisecondsSinceEpoch}';
    final extraMap = <String, dynamic>{
      'source': 'manual',
    };
    if (_noteController.text.trim().isNotEmpty) {
      extraMap['note'] = _noteController.text.trim();
    }

    final sample = AgesSample(
      id: id,
      timestamp: combinedTs,
      score: score,
      sourceDevice: 'manual',
      extraJson: jsonEncode(extraMap),
    );

    await WearableRepository.instance.upsertAges(sample);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AGEs reading recorded ($score)')),
      );
    }
  }

  Future<void> _delete() async {
    if (widget.initialSample == null) return;
    await WearableRepository.instance.agesBox.delete(widget.initialSample!.id);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AGEs reading removed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = BentoTheme.accent;
    final isEditing = widget.initialSample != null;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(LucideIcons.sparkles, color: accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isEditing ? 'EDIT AGEs READING' : 'RECORD AGEs READING',
                  style: TextStyle(
                    color: BentoTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              if (isEditing)
                IconButton(
                  icon: const Icon(LucideIcons.trash2,
                      color: Colors.redAccent, size: 18),
                  tooltip: 'Delete reading',
                  onPressed: _delete,
                ),
              IconButton(
                icon: const Icon(LucideIcons.x, size: 18),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Enter the AGEs index reading displayed in your Samsung Health app.',
            style: TextStyle(color: BentoTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 18),

          // Score Input
          Text(
            'INDEX VALUE',
            style: TextStyle(
              color: BentoTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _scoreController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: !isEditing,
            style: TextStyle(
              color: BentoTheme.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              hintText: 'e.g. 45.0',
              hintStyle: TextStyle(
                  color: BentoTheme.textSecondary.withValues(alpha: 0.5)),
              filled: true,
              fillColor: BentoTheme.surfaceElevated,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: accent.withValues(alpha: 0.5)),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Date & Time pickers
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: BentoTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Row(
                      children: [
                        Icon(LucideIcons.calendar, size: 16, color: accent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            DateFormat('MMM d, yyyy').format(_selectedDate),
                            style: TextStyle(
                                color: BentoTheme.textPrimary, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: _pickTime,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: BentoTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Row(
                      children: [
                        Icon(LucideIcons.clock, size: 16, color: accent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _selectedTime.format(context),
                            style: TextStyle(
                                color: BentoTheme.textPrimary, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Optional note
          TextField(
            controller: _noteController,
            style: TextStyle(color: BentoTheme.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Optional label or note (e.g. Optimal, After dinner)',
              hintStyle: TextStyle(
                  color: BentoTheme.textSecondary.withValues(alpha: 0.5)),
              filled: true,
              fillColor: BentoTheme.surfaceElevated,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Save button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(ExpressiveTokens.radiusSm),
                ),
              ),
              icon: const Icon(LucideIcons.check, size: 18),
              label: Text(
                isEditing ? 'Update Reading' : 'Save Reading',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              onPressed: _save,
            ),
          ),
        ],
      ),
    );
  }
}
