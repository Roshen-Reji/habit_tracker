import 'package:flutter/material.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/expressive_tokens.dart';
import 'package:habit_tracker/core/utils/format_utils.dart';
import 'package:habit_tracker/features/finance/data/finance_controller.dart';
import 'package:habit_tracker/models/finance_model.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class LegacyDebitReviewSheet extends StatefulWidget {
  final FinanceController controller;

  const LegacyDebitReviewSheet({super.key, required this.controller});

  static Future<void> show(BuildContext context, FinanceController controller) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => LegacyDebitReviewSheet(controller: controller),
    );
  }

  @override
  State<LegacyDebitReviewSheet> createState() => _LegacyDebitReviewSheetState();
}

class _LegacyDebitReviewSheetState extends State<LegacyDebitReviewSheet> {
  bool _isLoading = true;
  List<Transaction> _duplicates = [];
  List<Transaction> _legacyDebits = [];

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    final allTxs = widget.controller.storage.transactionBox.values.toList();

    final dups = <Transaction>[];
    final legacy = <Transaction>[];

    for (final tx in allTxs) {
      if (tx.sourceRef != null && tx.sourceRef!.startsWith('sip_')) {
        // format: sip_{id}_{yyyy-MM}
        final parts = tx.sourceRef!.split('_');
        if (parts.length >= 3) {
          final ruleId = parts[1];
          final monthStr = parts[2]; // yyyy-MM
          
          // Find matching rec:{id}:{yyyy-MM-dd}
          final hasNewEquivalent = allTxs.any((other) {
            return other.sourceRef != null &&
                   other.sourceRef!.startsWith('rec:$ruleId:$monthStr');
          });

          if (hasNewEquivalent) {
            dups.add(tx);
          } else {
            legacy.add(tx);
          }
        }
      } else if (tx.title.startsWith('SIP · ') && tx.toAccountId == null && (tx.sourceRef == null || !tx.sourceRef!.startsWith('rec:'))) {
        legacy.add(tx);
      }
    }

    if (mounted) {
      setState(() {
        _duplicates = dups;
        _legacyDebits = legacy;
        _isLoading = false;
      });
    }
  }

  Future<void> _resolveDuplicate(Transaction tx) async {
    await widget.controller.storage.transactionBox.delete(tx.id);
    _scan();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: BentoTheme.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            height: 5,
            width: 40,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Review Legacy Debits',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_duplicates.isEmpty && _legacyDebits.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.checkCircle2, size: 48, color: BentoTheme.accent),
                    const SizedBox(height: 16),
                    const Text('All clean! No legacy debits found.', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  if (_duplicates.isNotEmpty) ...[
                    const Text(
                      'Duplicates Found',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orangeAccent),
                    ),
                    const SizedBox(height: 10),
                    ..._duplicates.map((tx) => ListTile(
                          title: Text(tx.title),
                          subtitle: Text(FormatUtils.formatMoney(tx.amount)),
                          trailing: ElevatedButton(
                            onPressed: () => _resolveDuplicate(tx),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                            child: const Text('Delete'),
                          ),
                        )),
                    const SizedBox(height: 20),
                  ],
                  if (_legacyDebits.isNotEmpty) ...[
                    const Text(
                      'Legacy Expenses',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                    ),
                    const SizedBox(height: 10),
                    ..._legacyDebits.map((tx) => ListTile(
                          title: Text(tx.title),
                          subtitle: Text(FormatUtils.formatMoney(tx.amount)),
                          trailing: const Text('Needs Fund', style: TextStyle(color: Colors.white54)),
                        )),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
