import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/data/models/productivity_models.dart';
import 'package:habit_tracker/data/services/journal_service.dart';
import 'package:habit_tracker/features/journal/data/journal_day_repository.dart';
import 'package:habit_tracker/features/journal/journal_editor_page.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class JournalListPage extends StatefulWidget {
  const JournalListPage({super.key});

  @override
  State<JournalListPage> createState() => _JournalListPageState();
}

class _JournalListPageState extends State<JournalListPage>
    with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _searchController.addListener(() {
      setState(
          () => _searchQuery = _searchController.text.trim().toLowerCase());
    });

    // Auto-prompt unlock if not unlocked
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!JournalService.instance.isUnlocked.value) {
        _authenticate();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      JournalService.instance.lock();
    }
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return;
    setState(() => _isAuthenticating = true);
    try {
      final success = await JournalService.instance.authenticateAndUnlock();
      if (success) {
        await JournalService.instance.openEncryptedBox();
        await JournalService.instance.migrateDayKeysIfNeeded();
      }
    } finally {
      if (mounted) {
        setState(() => _isAuthenticating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: JournalService.instance.isUnlocked,
      builder: (context, isUnlocked, _) {
        if (!isUnlocked) {
          return _buildLockScreen();
        }
        return _buildTimelineView();
      },
    );
  }

  Widget _buildLockScreen() {
    return Scaffold(
      backgroundColor: BentoTheme.background,
      appBar: AppBar(
        backgroundColor: BentoTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: BentoTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: BentoTheme.accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  LucideIcons.lock,
                  color: BentoTheme.accent,
                  size: 36,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'JOURNAL VAULT',
                style: TextStyle(
                  color: BentoTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Protected with device credentials & AES-256 hardware encryption.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: BentoTheme.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: BentoTheme.accent,
                  foregroundColor: Colors.black,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(LucideIcons.fingerprint, size: 20),
                label: Text(
                  _isAuthenticating ? 'Authenticating...' : 'Unlock Journal',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                onPressed: _isAuthenticating ? null : _authenticate,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineView() {
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
          'DAY JOURNAL',
          style: TextStyle(
            color: BentoTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.calendarDays, size: 20),
            tooltip: 'Calendar Jump',
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null && mounted) {
                final dayKey = DateFormat('yyyy-MM-dd').format(picked);
                final dayDoc = await JournalDayRepository.instance.getOrCreateDay(dayKey);
                if (mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => JournalEditorPage(initialEntry: dayDoc),
                    ),
                  );
                }
              }
            },
          ),
          IconButton(
            icon: Icon(LucideIcons.lock,
                color: BentoTheme.textSecondary, size: 20),
            tooltip: 'Lock Vault',
            onPressed: () => JournalService.instance.lock(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: BentoTheme.accent,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        icon: const Icon(LucideIcons.penLine, size: 18),
        label: const Text('Today', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () async {
          final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
          final dayDoc = await JournalDayRepository.instance.getOrCreateDay(todayKey);
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => JournalEditorPage(initialEntry: dayDoc),
              ),
            );
          }
        },
      ),
      body: ValueListenableBuilder(
        valueListenable:
            Hive.box<JournalEntry>(JournalService.boxName).listenable(),
        builder: (context, Box<JournalEntry> box, _) {
          final allEntries = JournalService.instance.getEntries();
          final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());

          // Gather unique days (newest first, today always included)
          final dayKeysSet = <String>{todayKey};
          for (final e in allEntries) {
            final key = e.dayKey ?? DateFormat('yyyy-MM-dd').format(e.createdAt);
            dayKeysSet.add(key);
          }

          final sortedDayKeys = dayKeysSet.toList()
            ..sort((a, b) => b.compareTo(a));

          final filteredDayKeys = sortedDayKeys.where((dayKey) {
            if (_searchQuery.isEmpty) return true;
            final dayDoc = allEntries.where((e) => e.id == 'day_$dayKey').firstOrNull;
            final leg = JournalDayRepository.instance.legacyEntriesFor(dayKey);

            final matchesDoc = dayDoc != null &&
                (dayDoc.title.toLowerCase().contains(_searchQuery) ||
                    _extractPlainText(dayDoc.bodyDelta).toLowerCase().contains(_searchQuery) ||
                    dayDoc.tags.any((t) => t.toLowerCase().contains(_searchQuery)));
            final matchesLeg = leg.any((l) =>
                l.title.toLowerCase().contains(_searchQuery) ||
                _extractPlainText(l.bodyDelta).toLowerCase().contains(_searchQuery) ||
                l.tags.any((t) => t.toLowerCase().contains(_searchQuery)));

            return matchesDoc || matchesLeg || dayKey.contains(_searchQuery);
          }).toList();

          return Column(
            children: [
              // Search Bar
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: BentoTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search timeline or #tags...',
                    hintStyle: TextStyle(
                        color: BentoTheme.textSecondary.withValues(alpha: 0.6)),
                    prefixIcon: Icon(LucideIcons.search,
                        color: BentoTheme.textSecondary, size: 18),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(LucideIcons.x,
                                color: BentoTheme.textSecondary, size: 16),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    filled: true,
                    fillColor: BentoTheme.surface,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: BentoTheme.accent),
                    ),
                  ),
                ),
              ),

              // Day Timeline List
              Expanded(
                child: filteredDayKeys.isEmpty
                    ? Center(
                        child: Text(
                          'No journal entries match "$_searchQuery"',
                          style: TextStyle(color: BentoTheme.textSecondary),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
                        itemCount: filteredDayKeys.length,
                        itemBuilder: (context, index) {
                          final dayKey = filteredDayKeys[index];
                          return _buildDayTimelineSection(
                            dayKey: dayKey,
                            isToday: dayKey == todayKey,
                            allEntries: allEntries,
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDayTimelineSection({
    required String dayKey,
    required bool isToday,
    required List<JournalEntry> allEntries,
  }) {
    DateTime date;
    try {
      final parts = dayKey.split('-');
      date = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    } catch (_) {
      date = DateTime.now();
    }

    final dateHeader = isToday
        ? 'TODAY · ${DateFormat('EEE, d MMM').format(date).toUpperCase()}'
        : DateFormat('EEEE, d MMM yyyy').format(date).toUpperCase();

    final dayDoc = allEntries.where((e) => e.id == 'day_$dayKey').firstOrNull;
    final legacy = JournalDayRepository.instance.legacyEntriesFor(dayKey);
    final autoLogs = dayDoc != null
        ? JournalDayRepository.instance.getAutoLogs(dayDoc)
        : <AutoLogEvent>[];

    final snippet = dayDoc != null ? _extractPlainText(dayDoc.bodyDelta) : '';
    final hasContent = snippet.isNotEmpty || autoLogs.isNotEmpty || legacy.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sticky Date Header
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isToday ? BentoTheme.accent : BentoTheme.textSecondary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                dateHeader,
                style: TextStyle(
                  color: isToday ? BentoTheme.accent : BentoTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Day Card
          GestureDetector(
            onTap: () async {
              final doc = await JournalDayRepository.instance.getOrCreateDay(dayKey);
              if (mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => JournalEditorPage(initialEntry: doc),
                  ),
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: BentoTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isToday
                      ? BentoTheme.accent.withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Auto-log chips (if present)
                  if (autoLogs.isNotEmpty) ...[
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: autoLogs.map((log) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: BentoTheme.surfaceElevated,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_getIconForKind(log.kind),
                                  size: 13, color: BentoTheme.accent),
                              const SizedBox(width: 4),
                              Text(
                                log.text,
                                style: TextStyle(
                                  color: BentoTheme.textPrimary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Owner's Text Snippet or Placeholder
                  if (snippet.isNotEmpty)
                    Text(
                      snippet,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: BentoTheme.textPrimary,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    )
                  else if (!hasContent)
                    Text(
                      isToday ? 'Write today’s reflection...' : 'No entry for this day. Tap to write.',
                      style: TextStyle(
                        color: BentoTheme.textSecondary.withValues(alpha: 0.5),
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                    ),

                  // Legacy entries group
                  if (legacy.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(LucideIcons.history, size: 14, color: BentoTheme.textSecondary),
                        const SizedBox(width: 6),
                        Text(
                          'Earlier entries (${legacy.length})',
                          style: TextStyle(
                            color: BentoTheme.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () async {
                            await JournalDayRepository.instance.mergeLegacyEntries(dayKey);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('Merged into day document'),
                                  action: SnackBarAction(
                                    label: 'Undo',
                                    onPressed: () async {
                                      await JournalDayRepository.instance.undoMergeLegacyEntries(dayKey);
                                    },
                                  ),
                                ),
                              );
                            }
                          },
                          child: const Text('Merge all', style: TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ...legacy.map((l) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            const Text('• ', style: TextStyle(color: Colors.white38)),
                            Expanded(
                              child: Text(
                                '${l.title} (${DateFormat('h:mm a').format(l.createdAt)})',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: BentoTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _extractPlainText(String bodyDelta) {
    try {
      final decoded = jsonDecode(bodyDelta);
      if (decoded is List) {
        final buffer = StringBuffer();
        for (final op in decoded) {
          if (op is Map && op.containsKey('insert')) {
            buffer.write(op['insert']);
          }
        }
        return buffer.toString().trim();
      }
    } catch (_) {}
    return bodyDelta.trim();
  }

  IconData _getIconForKind(String kind) {
    switch (kind) {
      case 'wake':
        return LucideIcons.sunMedium;
      case 'sleep':
        return LucideIcons.moon;
      case 'workout':
        return LucideIcons.dumbbell;
      case 'steps':
        return LucideIcons.footprints;
      case 'energy':
        return LucideIcons.zap;
      default:
        return LucideIcons.stickyNote;
    }
  }
}
