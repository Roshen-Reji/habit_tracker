import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/expressive_tokens.dart';
import 'package:habit_tracker/core/utils/format_utils.dart';
import 'package:habit_tracker/features/finance/data/finance_controller.dart';
import 'package:habit_tracker/features/finance/engine/loan_engine.dart';
import 'package:habit_tracker/features/finance/models/models.dart';
import 'package:habit_tracker/features/finance/ui/accounts/account_detail_page.dart';
import 'package:habit_tracker/features/finance/ui/debt/loan_simulator_sheet.dart';
import 'package:habit_tracker/features/finance/ui/transactions/transaction_sheet.dart';

class DebtPage extends StatefulWidget {
  const DebtPage({super.key});

  @override
  State<DebtPage> createState() => _DebtPageState();
}

class _DebtPageState extends State<DebtPage> {
  final FinanceController _controller = FinanceController();
  bool _showSnowball = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final totalDebt = _controller.getTotalDebt();
        final weightedRate = _controller.getWeightedAverageInterestRate();
        final monthlyEmi = _controller.getTotalMonthlyEmiObligation();

        final cards = _controller.creditCardAccounts;
        final loans = _controller.loanAccounts;

        final strategies = loans.isNotEmpty
            ? _controller.comparePayoffStrategies()
            : null;

        return Scaffold(
          backgroundColor: BentoTheme.background,
          appBar: AppBar(
            backgroundColor: BentoTheme.background,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(LucideIcons.arrowLeft, size: 20),
              color: BentoTheme.textPrimary,
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              'Debt & Credit Cards',
              style: TextStyle(
                color: BentoTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            children: [
              // Summary Overview Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: BentoTheme.surface,
                  borderRadius: ExpressiveTokens.borderL,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL OUTSTANDING DEBT',
                      style: TextStyle(
                        color: BentoTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      FormatUtils.formatMoney(totalDebt),
                      style: TextStyle(
                        color: totalDebt > 0 ? Colors.redAccent : BentoTheme.textPrimary,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'WEIGHTED AVG RATE',
                                style: TextStyle(
                                  color: BentoTheme.textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$weightedRate% p.a.',
                                style: TextStyle(
                                  color: BentoTheme.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'MONTHLY EMIs',
                                style: TextStyle(
                                  color: BentoTheme.textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${FormatUtils.formatMoney(monthlyEmi)}/mo',
                                style: TextStyle(
                                  color: BentoTheme.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Payoff Strategy Comparison Card (P7-2)
              if (strategies != null) ...[
                _buildStrategyCard(strategies),
                const SizedBox(height: 24),
              ],

              // Credit Cards Section (P7-4)
              Text(
                'CREDIT CARDS (${cards.length})',
                style: TextStyle(
                  color: BentoTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 10),

              if (cards.isEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: BentoTheme.surface,
                    borderRadius: ExpressiveTokens.borderM,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Center(
                    child: Text(
                      'No credit cards tracked.',
                      style: TextStyle(color: BentoTheme.textSecondary, fontSize: 13),
                    ),
                  ),
                ),
              ] else ...[
                ...cards.map((c) => _buildCreditCardItem(c)),
              ],
              const SizedBox(height: 24),

              // Loans & EMIs Section (P7-1, P7-3)
              Text(
                'LOANS & EMIs (${loans.length})',
                style: TextStyle(
                  color: BentoTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 10),

              if (loans.isEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: BentoTheme.surface,
                    borderRadius: ExpressiveTokens.borderM,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Center(
                    child: Text(
                      'No loans or EMIs tracked.',
                      style: TextStyle(color: BentoTheme.textSecondary, fontSize: 13),
                    ),
                  ),
                ),
              ] else ...[
                ...loans.map((l) => _buildLoanItem(l)),
              ],

              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStrategyCard(({PayoffComparison avalanche, PayoffComparison snowball}) strategies) {
    final active = _showSnowball ? strategies.snowball : strategies.avalanche;
    final interestDiff = (strategies.snowball.totalInterest - strategies.avalanche.totalInterest).abs();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: BentoTheme.surface,
        borderRadius: ExpressiveTokens.borderL,
        border: Border.all(color: BentoTheme.accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.zap, color: BentoTheme.accent, size: 20),
              const SizedBox(width: 8),
              Text(
                'Debt Payoff Strategy',
                style: TextStyle(
                  color: BentoTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              // Toggle: Avalanche vs Snowball
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: BentoTheme.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => setState(() => _showSnowball = false),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: !_showSnowball ? BentoTheme.accent : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Avalanche',
                          style: TextStyle(
                            color: !_showSnowball ? Colors.black : BentoTheme.textSecondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() => _showSnowball = true),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _showSnowball ? BentoTheme.accent : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Snowball',
                          style: TextStyle(
                            color: _showSnowball ? Colors.black : BentoTheme.textSecondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _showSnowball
                ? 'Snowball tackles the smallest balance first for quick psychological momentum.'
                : 'Avalanche prioritizes the highest interest rate to mathematically minimize total interest paid.',
            style: TextStyle(color: BentoTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: BentoTheme.background,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('DEBT-FREE DATE', style: TextStyle(color: BentoTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('MMM yyyy').format(active.debtFreeDate),
                        style: TextStyle(color: BentoTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text('${active.totalMonths} months', style: TextStyle(color: BentoTheme.textSecondary, fontSize: 11)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: BentoTheme.background,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('TOTAL INTEREST', style: TextStyle(color: BentoTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        FormatUtils.formatMoney(active.totalInterest),
                        style: TextStyle(color: BentoTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        !_showSnowball && interestDiff > 100
                            ? 'Saves ${FormatUtils.formatMoney(interestDiff)} vs Snowball'
                            : 'Order: ${active.payoffOrder.firstOrNull ?? ''}',
                        style: TextStyle(color: const Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCreditCardItem(Account card) {
    final bal = _controller.getAccountBalance(card).abs();
    final limit = card.creditLimit ?? 0.0;
    final util = LoanEngine.cardUtilisation(currentBalance: bal, creditLimit: limit);
    final minDue = LoanEngine.minimumDue(statementBalance: bal);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BentoTheme.surface,
        borderRadius: ExpressiveTokens.borderM,
        border: Border.all(
          color: util.isDanger
              ? Colors.redAccent.withValues(alpha: 0.4)
              : (util.isWarning ? Colors.amberAccent.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: Colors.purpleAccent.withValues(alpha: 0.2),
                child: const Icon(LucideIcons.creditCard, size: 14, color: Colors.purpleAccent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.name,
                      style: TextStyle(
                        color: BentoTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (card.institution != null)
                      Text(
                        card.institution!,
                        style: TextStyle(color: BentoTheme.textSecondary, fontSize: 11),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    FormatUtils.formatMoney(bal),
                    style: TextStyle(
                      color: BentoTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'Limit: ${FormatUtils.formatMoney(limit)}',
                    style: TextStyle(color: BentoTheme.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Utilisation Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: limit > 0 ? (bal / limit).clamp(0.0, 1.0) : 0.0,
              minHeight: 6,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(
                util.isDanger ? Colors.redAccent : (util.isWarning ? Colors.amberAccent : const Color(0xFF10B981)),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Utilisation warning copy & due info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    '${util.utilisationPct.toStringAsFixed(0)}% utilised',
                    style: TextStyle(
                      color: util.isDanger ? Colors.redAccent : (util.isWarning ? Colors.amberAccent : BentoTheme.textSecondary),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                  if (util.isWarning || util.isDanger) ...[
                    const SizedBox(width: 6),
                    Icon(
                      LucideIcons.alertTriangle,
                      size: 13,
                      color: util.isDanger ? Colors.redAccent : Colors.amberAccent,
                    ),
                  ],
                ],
              ),
              if (card.dueDay != null)
                Text(
                  'Due Day: ${card.dueDay}',
                  style: TextStyle(color: BentoTheme.textSecondary, fontSize: 11),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Action row: Minimum Due & Pay Card Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('MINIMUM DUE (5%)', style: TextStyle(color: BentoTheme.textSecondary, fontSize: 9, fontWeight: FontWeight.bold)),
                  Text(FormatUtils.formatMoney(minDue), style: TextStyle(color: BentoTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {
                  TransactionSheet.show(
                    context,
                    initialKind: 'debt_payment',
                  );
                },
                icon: const Icon(LucideIcons.arrowUpRight, size: 14),
                label: const Text('Pay Card'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: BentoTheme.accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoanItem(Account loan) {
    final bal = _controller.getAccountBalance(loan).abs();
    final rate = loan.annualRate ?? 10.0;
    final emi = loan.emi ??
        LoanEngine.calculateEmi(
          principal: bal,
          annualRatePct: rate,
          tenureMonths: loan.tenureMonths ?? 60,
        );
    final remainingMonths = LoanEngine.remainingMonths(
      principal: bal,
      annualRatePct: rate,
      emi: emi,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BentoTheme.surface,
        borderRadius: ExpressiveTokens.borderM,
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
                child: const Icon(LucideIcons.landmark, size: 14, color: Colors.redAccent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loan.name,
                      style: TextStyle(
                        color: BentoTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$rate% interest • ${loan.kind.toUpperCase()}',
                      style: TextStyle(color: BentoTheme.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    FormatUtils.formatMoney(bal),
                    style: TextStyle(
                      color: BentoTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'EMI: ${FormatUtils.formatMoney(emi)}/mo',
                    style: TextStyle(color: BentoTheme.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                remainingMonths > 0
                    ? '$remainingMonths months remaining'
                    : 'Non-amortising!',
                style: TextStyle(
                  color: remainingMonths > 0 ? BentoTheme.textSecondary : Colors.redAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  LoanSimulatorSheet.show(context, controller: _controller, loan: loan);
                },
                icon: const Icon(LucideIcons.calculator, size: 14),
                label: const Text('Pre-payment Simulator'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: BentoTheme.accent,
                  side: BorderSide(color: BentoTheme.accent.withValues(alpha: 0.3)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
