# Finance Rules & Calculation Invariants

## Core Definitions

1. **Money Left**:
   - The sum of balances of all accounts that are `spendable == true`, not archived (`archived == false`), and not liabilities (`isLiability == false`), calculated **as of now** (`DateTime.now()`).
   - May be negative if spendable accounts are overdrawn, and in that state it is always displayed as a signed negative number (e.g., `-₹5,000`).
   - Tapping Money Left opens the "Why this number" breakdown sheet detailing included and excluded accounts.

2. **Safe to Spend**:
   - Money Left minus upcoming obligations, planned goal contributions, planned essential budgets, and credit card dues for the remainder of the current month.
   - S = Liquid - Obligations - GoalsEarmark - PlannedEssential - CardDues.
   - Separate from Money Left, always distinctly labeled.
   - When negative, it represents a shortfall: displayed as a signed negative figure (e.g. `Short by ₹X until month end`), never clamped to `₹0`.
   - Computed only for the active calendar month. Non-current months render a "month review" (income, spending, net, closing balance).

3. **Net Worth**:
   - Total assets minus total liabilities across all accounts with `includeInNetWorth == true`, plus unsettled receivables minus unsettled payables.
   - Never labeled as "balance" or "money left".

## Recurring & Idempotency Rules

- **Source Reference**: Every auto-posted occurrence, manual payment confirmation, or marked-paid event MUST use the canonical format: `rec:{ruleId}:{yyyy-MM-dd}`.
- **Deduplication**: Posting an occurrence must check for existing transactions with matching `sourceRef` and skip if already recorded.
- **Account Opening Date**: Transactions dated prior to an account's `openingDate` are excluded from balance folds. New accounts default to the date of their earliest transaction or today.
