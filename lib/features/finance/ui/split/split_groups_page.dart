import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/expressive_tokens.dart';
import 'package:habit_tracker/core/utils/format_utils.dart';
import 'package:habit_tracker/features/finance/data/finance_controller.dart';
import 'package:habit_tracker/features/finance/data/finance_repository.dart';
import 'package:habit_tracker/features/finance/engine/split_settle_engine.dart';
import 'package:habit_tracker/features/finance/models/split_group.dart';
import 'package:habit_tracker/features/finance/ui/split/split_group_detail_page.dart';

class SplitGroupsPage extends StatefulWidget {
  const SplitGroupsPage({super.key});

  @override
  State<SplitGroupsPage> createState() => _SplitGroupsPageState();
}

class _SplitGroupsPageState extends State<SplitGroupsPage> {
  final FinanceController _controller = FinanceController();
  late final FinanceRepository _repository = _controller.repository;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  void _openCreateGroupDialog() {
    final nameController = TextEditingController();
    final membersController = TextEditingController(text: 'You, ');
    String kind = 'trip';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: BentoTheme.surface,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              'Create Split Group',
              style: TextStyle(
                  color: BentoTheme.textPrimary, fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    style: TextStyle(color: BentoTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Group Name',
                      hintText: 'e.g. Goa Trip, Flat 402',
                      labelStyle: TextStyle(color: BentoTheme.textSecondary),
                      filled: true,
                      fillColor: BentoTheme.background,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: kind,
                    dropdownColor: BentoTheme.surface,
                    style:
                        TextStyle(color: BentoTheme.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Type',
                      labelStyle: TextStyle(color: BentoTheme.textSecondary),
                      filled: true,
                      fillColor: BentoTheme.background,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'trip', child: Text('Trip / Vacation')),
                      DropdownMenuItem(
                          value: 'household',
                          child: Text('Household / Flatmates')),
                      DropdownMenuItem(value: 'other', child: Text('Other')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => kind = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: membersController,
                    style: TextStyle(color: BentoTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Members (comma separated)',
                      hintText: 'You, Alice, Bob',
                      labelStyle: TextStyle(color: BentoTheme.textSecondary),
                      filled: true,
                      fillColor: BentoTheme.background,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel',
                    style: TextStyle(color: BentoTheme.textSecondary)),
              ),
              ElevatedButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  if (name.isEmpty) return;

                  final rawMembers = membersController.text
                      .split(',')
                      .map((m) => m.trim())
                      .where((m) => m.isNotEmpty)
                      .toList();
                  if (!rawMembers.any((m) => m.toLowerCase() == 'you')) {
                    rawMembers.insert(0, 'You');
                  }

                  final newGroup = SplitGroup(
                    id: 'grp_${DateTime.now().millisecondsSinceEpoch}',
                    name: name,
                    kind: kind,
                    members: rawMembers,
                    createdAt: DateTime.now(),
                  );

                  await _repository.addSplitGroup(newGroup);
                  if (mounted) Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: BentoTheme.accent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Create'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groups = _repository.splitGroups.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final allEntries = _repository.splitEntries.values.toList();
    final allTxs = _controller.allTransactions;

    final totalReceivables = SplitSettleEngine.calculateTotalReceivables(
      entries: allEntries,
      transactions: allTxs,
    );
    final totalPayables = SplitSettleEngine.calculateTotalPayables(
      entries: allEntries,
    );

    return Scaffold(
      backgroundColor: BentoTheme.background,
      appBar: AppBar(
        backgroundColor: BentoTheme.background,
        elevation: 0,
        title: Text(
          'Split & Settle',
          style: TextStyle(
            color: BentoTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(LucideIcons.plus, color: BentoTheme.accent),
            tooltip: 'New Group',
            onPressed: _openCreateGroupDialog,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Receivables vs Payables Hero Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: BentoTheme.surface,
              borderRadius: ExpressiveTokens.borderL,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(LucideIcons.arrowDownLeft,
                              color: const Color(0xFF22C55E), size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'YOU ARE OWED',
                            style: TextStyle(
                              color: BentoTheme.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${FormatUtils.formatMoney(totalReceivables, decimals: 0)}',
                        style: const TextStyle(
                          color: Color(0xFF22C55E),
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 48, color: Colors.white10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(LucideIcons.arrowUpRight,
                                color: const Color(0xFFEF4444), size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'YOU OWE',
                              style: TextStyle(
                                color: BentoTheme.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${FormatUtils.formatMoney(totalPayables, decimals: 0)}',
                          style: const TextStyle(
                            color: Color(0xFFEF4444),
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'SPLIT GROUPS (${groups.length})',
            style: TextStyle(
              color: BentoTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 10),

          if (groups.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: BentoTheme.surface,
                borderRadius: ExpressiveTokens.borderM,
              ),
              child: Column(
                children: [
                  Icon(LucideIcons.users,
                      size: 40, color: BentoTheme.textSecondary),
                  const SizedBox(height: 12),
                  Text(
                    'No split groups yet',
                    style: TextStyle(
                        color: BentoTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Create a group for trips, flatmates, or dinners to track shared costs and settle with minimal payments.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: BentoTheme.textSecondary,
                        fontSize: 12,
                        height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _openCreateGroupDialog,
                    icon: const Icon(LucideIcons.plus, size: 16),
                    label: const Text('Create First Group'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BentoTheme.accent,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            )
          else
            ...groups.map((g) {
              final groupEntries =
                  allEntries.where((e) => e.groupId == g.id).toList();
              final balances = SplitSettleEngine.calculateBalances(
                members: g.members,
                entries: groupEntries,
              );
              final userBalance = balances.firstWhere(
                  (b) => b.member.toLowerCase() == 'you',
                  orElse: () => MemberBalance(
                      member: 'You', totalPaid: 0, totalShare: 0, net: 0));

              IconData icon = LucideIcons.users;
              if (g.kind == 'trip') icon = LucideIcons.plane;
              if (g.kind == 'household') icon = LucideIcons.home;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: BentoTheme.surface,
                  borderRadius: ExpressiveTokens.borderM,
                ),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: BentoTheme.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: BentoTheme.accent, size: 20),
                  ),
                  title: Text(
                    g.name,
                    style: TextStyle(
                        color: BentoTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15),
                  ),
                  subtitle: Text(
                    '${g.members.length} members • ${groupEntries.length} expenses',
                    style: TextStyle(
                        color: BentoTheme.textSecondary, fontSize: 12),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (userBalance.net > 0.01)
                        Text(
                          '+${FormatUtils.formatMoney(userBalance.net, decimals: 0)}',
                          style: const TextStyle(
                              color: Color(0xFF22C55E),
                              fontWeight: FontWeight.bold,
                              fontSize: 13),
                        )
                      else if (userBalance.net < -0.01)
                        Text(
                          '-${FormatUtils.formatMoney(userBalance.net.abs(), decimals: 0)}',
                          style: const TextStyle(
                              color: Color(0xFFEF4444),
                              fontWeight: FontWeight.bold,
                              fontSize: 13),
                        )
                      else
                        Text(
                          'Settled',
                          style: TextStyle(
                              color: BentoTheme.textSecondary, fontSize: 12),
                        ),
                      Icon(LucideIcons.chevronRight,
                          size: 14, color: BentoTheme.textSecondary),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => SplitGroupDetailPage(group: g)),
                    );
                  },
                ),
              );
            }),
        ],
      ),
    );
  }
}
