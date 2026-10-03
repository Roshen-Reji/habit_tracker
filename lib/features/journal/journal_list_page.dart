import 'package:flutter/material.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/expressive_tokens.dart';
import 'package:habit_tracker/data/models/productivity_models.dart';
import 'package:habit_tracker/data/services/journal_service.dart';
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
        return _buildJournalView();
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

  Widget _buildJournalView() {
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
          'PRIVATE JOURNAL',
          style: TextStyle(
            color: BentoTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(LucideIcons.lock,
                color: BentoTheme.textSecondary, size: 20),
            tooltip: 'Lock Vault',
            onPressed: () => JournalService.instance.lock(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: BentoTheme.accent,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const JournalEditorPage(),
            ),
          );
        },
        child: const Icon(LucideIcons.penTool, size: 22),
      ),
      body: ValueListenableBuilder(
        valueListenable:
            Hive.box<JournalEntry>(JournalService.boxName).listenable(),
        builder: (context, Box<JournalEntry> box, _) {
          final allEntries = JournalService.instance.getEntries();
          final filtered = allEntries.where((entry) {
            if (_searchQuery.isEmpty) return true;
            return entry.title.toLowerCase().contains(_searchQuery) ||
                entry.tags.any((t) => t.toLowerCase().contains(_searchQuery));
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
                    hintText: 'Search journals or #tags...',
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
                      borderSide: BorderSide(
                        color: BentoTheme.accent.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              ),

              // Entries List
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          _searchQuery.isEmpty
                              ? 'No journal entries yet.\nTap the pen button to write your first entry.'
                              : 'No entries matching "$_searchQuery"',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: BentoTheme.textSecondary,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final entry = filtered[index];
                          return _buildJournalCard(entry);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildJournalCard(JournalEntry entry) {
    final dateStr = DateFormat('MMM d, y · h:mm a').format(entry.updatedAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: BentoTheme.surface,
        borderRadius: BorderRadius.circular(ExpressiveTokens.radiusCard),
        border: Border.all(
          color: entry.pinned
              ? Colors.amber.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.06),
          width: 1.2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(ExpressiveTokens.radiusCard),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => JournalEditorPage(initialEntry: entry),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (entry.pinned) ...[
                      const Icon(LucideIcons.pin,
                          color: Colors.amberAccent, size: 14),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        entry.title,
                        style: TextStyle(
                          color: BentoTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.trash2,
                          color: Colors.redAccent, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: BentoTheme.surface,
                            title: Text('Delete Entry?',
                                style:
                                    TextStyle(color: BentoTheme.textPrimary)),
                            content: Text(
                                'Are you sure you want to delete "${entry.title}"?',
                                style:
                                    TextStyle(color: BentoTheme.textSecondary)),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: Text('Cancel',
                                    style: TextStyle(
                                        color: BentoTheme.textSecondary)),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await JournalService.instance.deleteEntry(entry.id);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  dateStr,
                  style: TextStyle(
                    color: BentoTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
                if (entry.tags.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: entry.tags
                        .map(
                          (t) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: BentoTheme.accent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '#$t',
                              style: TextStyle(
                                color: BentoTheme.accent,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
