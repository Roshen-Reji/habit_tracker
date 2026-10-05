import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/expressive_tokens.dart';
import 'package:habit_tracker/core/utils/format_utils.dart';
import 'package:habit_tracker/features/finance/data/finance_controller.dart';
import 'package:habit_tracker/features/finance/engine/loan_engine.dart';
import 'package:habit_tracker/features/finance/models/models.dart';
import 'package:habit_tracker/features/finance/ui/transactions/transaction_sheet.dart';

class LoanSimulatorSheet extends StatefulWidget {
  final FinanceController controller;
  final Account loan;

  const LoanSimulatorSheet({
    super.key,
    required this.controller,
    required this.loan,
  });

  static Future<void> show(
    BuildContext context, {
    required FinanceController controller,
    required Account loan,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LoanSimulatorSheet(controller: controller, loan: loan),
    );
  }

  @override
  State<LoanSimulatorSheet> createState() => _LoanSimulatorSheetState();
}

class _LoanSimulatorSheetState extends State<LoanSimulatorSheet> {
  double _extraPayment = 2000.0;

  @override
  Widget build(BuildContext context) {
    final bal = widget.controller.getAccountBalance(widget.loan).abs();
    final rate = widget.loan.annualRate ?? 10.0;
    final emi = widget.loan.emi ??
        LoanEngine.calculateEmi(
          principal: bal,
          annualRatePct: rate,
          tenureMonths: widget.loan.tenureMonths ?? 60,
        );

    final sim = LoanEngine.simulateExtraPayment(
      principal: bal,
      annualRatePct: rate,
      emi: emi,
      extraPaymentPerMonth: _extraPayment,
    );

    final schedule = LoanEngine.generateSchedule(
      principal: bal,
      annualRatePct: rate,
      emi: emi,
      extraPayment: _extraPayment,
      maxMonths: 60,
    );

    return Container(
      decoration: BoxDecoration(
        color: BentoTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Icon(LucideIcons.calculator, color: BentoTheme.accent, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Extra Payment Simulator',
                    style: TextStyle(
                      color: BentoTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white60, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.loan.name} • ${FormatUtils.formatMoney(bal)} at $rate% interest',
              style: TextStyle(color: BentoTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),

            // Extra Payment Slider
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: BentoTheme.background,
                borderRadius: ExpressiveTokens.borderM,
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'EXTRA MONTHLY PRE-PAYMENT',
                        style: TextStyle(
                          color: BentoTheme.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                        ),
                      ),
                      Text(
                        FormatUtils.formatMoney(_extraPayment),
                        style: TextStyle(
                          color: BentoTheme.accent,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _extraPayment,
                    min: 0.0,
                    max: (emi * 2).clamp(10000.0, 50000.0),
                    divisions: 50,
                    activeColor: BentoTheme.accent,
                    inactiveColor: Colors.white12,
                    onChanged: (val) {
                      setState(() => _extraPayment = val);
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(FormatUtils.formatCurrency(0), style: TextStyle(color: BentoTheme.textSecondary, fontSize: 11)),
                      Text(
                        'Base EMI: ${FormatUtils.formatMoney(emi)}/mo',
                        style: TextStyle(color: BentoTheme.textSecondary, fontSize: 11),
                      ),
                      Text(
                        FormatUtils.formatMoney((emi * 2).clamp(10000.0, 50000.0)),
                        style: TextStyle(color: BentoTheme.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Savings Cards Row
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'INTEREST SAVED',
                          style: TextStyle(
                            color: const Color(0xFF10B981),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          FormatUtils.formatMoney(sim.interestSaved),
                          style: const TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: BentoTheme.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: BentoTheme.accent.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TIME SAVED',
                          style: TextStyle(
                            color: BentoTheme.accent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${sim.monthsSaved} Months',
                          style: TextStyle(
                            color: BentoTheme.accent,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Payoff Comparison Row
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: BentoTheme.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NEW TENURE',
                        style: TextStyle(color: BentoTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${sim.newMonths} months (was ${sim.baselineMonths})',
                        style: TextStyle(color: BentoTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'TOTAL INTEREST',
                        style: TextStyle(color: BentoTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        FormatUtils.formatMoney(sim.newInterest),
                        style: TextStyle(color: BentoTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      TransactionSheet.show(
                        context,
                        initialKind: 'debt_payment',
                      );
                    },
                    icon: const Icon(LucideIcons.arrowUpRight, size: 16),
                    label: const Text('Make Pre-payment'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BentoTheme.accent,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: ExpressiveTokens.borderM,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Amortization Schedule Preview
            Text(
              'AMORTIZATION SCHEDULE (NEXT 6 MONTHS)',
              style: TextStyle(
                color: BentoTheme.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 8),

            ...schedule.months.take(6).map((m) {
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: BentoTheme.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Month ${m.monthIndex}', style: TextStyle(color: BentoTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
                    Text('Principal: ${FormatUtils.formatMoney(m.principal)}', style: TextStyle(color: const Color(0xFF10B981), fontSize: 11)),
                    Text('Interest: ${FormatUtils.formatMoney(m.interest)}', style: TextStyle(color: Colors.redAccent, fontSize: 11)),
                    Text('Bal: ${FormatUtils.formatMoney(m.remainingBalance)}', style: TextStyle(color: BentoTheme.textSecondary, fontSize: 11)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
