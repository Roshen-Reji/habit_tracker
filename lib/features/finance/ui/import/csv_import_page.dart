import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/expressive_tokens.dart';
import 'package:habit_tracker/core/utils/format_utils.dart';
import 'package:habit_tracker/features/finance/data/finance_controller.dart';
import 'package:habit_tracker/features/finance/data/finance_repository.dart';
import 'package:habit_tracker/features/finance/engine/capture_engine.dart';
import 'package:habit_tracker/features/finance/models/models.dart';

class CsvImportPage extends StatefulWidget {
  const CsvImportPage({super.key});

  @override
  State<CsvImportPage> createState() => _CsvImportPageState();
}

class _CsvImportPageState extends State<CsvImportPage> {
  final FinanceController _controller = FinanceController();
  final FinanceRepository _repository = FinanceRepository();

  String? _filePath;
  String? _fileContent;
  List<List<String>> _parsedRows = [];

  String _delimiter = ',';
  int _dateCol = 0;
  String _dateFormat = 'dd/MM/yyyy';
  int _descCol = 1;
  int? _amountCol = 2;
  int? _debitCol;
  int? _creditCol;
  bool _useDebitCredit = false;
  bool _hasHeader = true;

  String? _selectedAccountId;
  List<TransactionDraft> _drafts = [];
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    final spendable = _controller.activeAccounts.where((a) => a.spendable).toList();
    if (spendable.isNotEmpty) {
      _selectedAccountId = spendable.first.id;
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'txt'],
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final content = await file.readAsString();
      final detectedDelim = CsvParser.autoDetectDelimiter(content);

      setState(() {
        _filePath = result.files.single.path;
        _fileContent = content;
        _delimiter = detectedDelim;
        _reparseContent();
      });
    }
  }

  void _reparseContent() {
    if (_fileContent == null) return;
    final rows = CsvParser.parseCsv(_fileContent!, delimiter: _delimiter);
    _parsedRows = rows;

    if (rows.isNotEmpty) {
      final firstRow = rows.first;
      // Auto-guess columns if possible
      for (var i = 0; i < firstRow.length; i++) {
        final val = firstRow[i].toLowerCase();
        if (val.contains('date')) _dateCol = i;
        if (val.contains('desc') || val.contains('narration') || val.contains('particular')) _descCol = i;
        if (val.contains('amount')) _amountCol = i;
        if (val.contains('debit') || val.contains('withdrawal')) _debitCol = i;
        if (val.contains('credit') || val.contains('deposit')) _creditCol = i;
      }
      if (_debitCol != null && _creditCol != null) {
        _useDebitCredit = true;
      }
    }

    _updateDrafts();
  }

  void _updateDrafts() {
    if (_parsedRows.isEmpty) return;

    final profile = CsvMappingProfile(
      name: 'Temp',
      delimiter: _delimiter,
      dateColumn: _dateCol,
      dateFormat: _dateFormat,
      descriptionColumn: _descCol,
      amountColumn: _useDebitCredit ? null : _amountCol,
      debitColumn: _useDebitCredit ? _debitCol : null,
      creditColumn: _useDebitCredit ? _creditCol : null,
      hasHeader: _hasHeader,
    );

    final existingRefs = _controller.allTransactions
        .where((t) => t.sourceRef != null)
        .map((t) => t.sourceRef!)
        .toSet();

    final drafts = CsvParser.parseDrafts(
      rows: _parsedRows,
      profile: profile,
      accountId: _selectedAccountId,
      rules: _controller.storage.ruleBox.values.toList(),
      existingSourceRefs: existingRefs,
    );

    setState(() {
      _drafts = drafts;
    });
  }

  Future<void> _executeImport() async {
    final toImport = _drafts.where((d) => !d.isDuplicate).toList();
    if (toImport.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No new transactions to import.')),
      );
      return;
    }

    setState(() => _isImporting = true);

    try {
      int imported = 0;
      for (final draft in toImport) {
        await _repository.addTransaction(
          TxDraft(
            title: draft.title,
            amount: draft.amount,
            category: draft.categoryId != null
                ? (_controller.getCategory(draft.categoryId!)?.name ?? 'Other')
                : 'Other',
            date: draft.date,
            mode: draft.kind,
            kind: draft.kind,
            accountId: draft.accountId,
            toAccountId: draft.toAccountId,
            categoryId: draft.categoryId,
            merchant: draft.merchant,
            paymentMethod: draft.paymentMethod ?? 'NetBanking',
            sourceRef: draft.sourceRef,
          ),
        );
        imported++;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully imported $imported transactions!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final newCount = _drafts.where((d) => !d.isDuplicate).length;
    final dupCount = _drafts.where((d) => d.isDuplicate).length;
    final transferCount = _drafts.where((d) => d.isSuggestedTransfer).length;

    return Scaffold(
      backgroundColor: BentoTheme.background,
      appBar: AppBar(
        title: const Text('Import CSV Statement', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: BentoTheme.surface,
        foregroundColor: BentoTheme.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // File picker card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: BentoTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: BentoTheme.accent.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  Icon(LucideIcons.fileSpreadsheet, size: 36, color: BentoTheme.accent),
                  const SizedBox(height: 10),
                  Text(
                    _filePath != null ? _filePath!.split(Platform.pathSeparator).last : 'Select CSV Bank Statement',
                    style: TextStyle(color: BentoTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _pickFile,
                    icon: const Icon(LucideIcons.upload, size: 16),
                    label: Text(_filePath != null ? 'Change File' : 'Pick CSV File'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BentoTheme.accent,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (_parsedRows.isNotEmpty) ...[
              // Configuration card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: BentoTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mapping Configuration', style: TextStyle(color: BentoTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 12),

                    // Destination Account
                    DropdownButtonFormField<String>(
                      value: _selectedAccountId,
                      decoration: const InputDecoration(labelText: 'Import Into Account'),
                      dropdownColor: BentoTheme.surface,
                      items: _controller.activeAccounts.map((a) {
                        return DropdownMenuItem(value: a.id, child: Text(a.name));
                      }).toList(),
                      onChanged: (val) {
                        setState(() => _selectedAccountId = val);
                        _updateDrafts();
                      },
                    ),
                    const SizedBox(height: 12),

                    // Date format dropdown
                    DropdownButtonFormField<String>(
                      value: _dateFormat,
                      decoration: const InputDecoration(labelText: 'Date Format'),
                      dropdownColor: BentoTheme.surface,
                      items: const [
                        DropdownMenuItem(value: 'dd/MM/yyyy', child: Text('dd/MM/yyyy (e.g. 15/10/2026)')),
                        DropdownMenuItem(value: 'yyyy-MM-dd', child: Text('yyyy-MM-dd (ISO)')),
                        DropdownMenuItem(value: 'MM/dd/yyyy', child: Text('MM/dd/yyyy (US)')),
                        DropdownMenuItem(value: 'dd-MM-yyyy', child: Text('dd-MM-yyyy')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _dateFormat = val);
                          _updateDrafts();
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    // Toggle debit/credit mode
                    SwitchListTile(
                      title: const Text('Separate Debit & Credit Columns', style: TextStyle(color: Colors.white, fontSize: 13)),
                      value: _useDebitCredit,
                      activeColor: BentoTheme.accent,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) {
                        setState(() => _useDebitCredit = val);
                        _updateDrafts();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Summary stats row
              Row(
                children: [
                  Expanded(child: _summaryBadge('New', newCount, Colors.green)),
                  const SizedBox(width: 8),
                  Expanded(child: _summaryBadge('Duplicates', dupCount, BentoTheme.textSecondary)),
                  const SizedBox(width: 8),
                  Expanded(child: _summaryBadge('Transfers', transferCount, BentoTheme.accent)),
                ],
              ),
              const SizedBox(height: 16),

              // Preview list
              Text('Preview Transactions (${_drafts.length})', style: TextStyle(color: BentoTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),

              ..._drafts.take(15).map((d) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: BentoTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: d.isDuplicate
                          ? Colors.white.withValues(alpha: 0.05)
                          : (d.isSuggestedTransfer
                              ? BentoTheme.accent.withValues(alpha: 0.3)
                              : Colors.white.withValues(alpha: 0.1)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: (d.amount >= 0 ? Colors.green : Colors.red).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          d.amount >= 0 ? LucideIcons.arrowDownLeft : LucideIcons.arrowUpRight,
                          color: d.amount >= 0 ? Colors.green : Colors.red,
                          size: 14,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              d.title,
                              style: TextStyle(
                                color: d.isDuplicate ? BentoTheme.textSecondary : BentoTheme.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${DateFormat('dd MMM yy').format(d.date)} · ${d.merchant ?? 'Uncategorised'}',
                              style: TextStyle(color: BentoTheme.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${d.amount >= 0 ? '+' : ''}₹${FormatUtils.formatMoney(d.amount.abs())}',
                            style: TextStyle(
                              color: d.amount >= 0 ? Colors.green : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          if (d.isDuplicate)
                            Text('DUPLICATE', style: TextStyle(color: BentoTheme.textSecondary, fontSize: 9, fontWeight: FontWeight.bold))
                          else if (d.isSuggestedTransfer)
                            Text('TRANSFER?', style: TextStyle(color: BentoTheme.accent, fontSize: 9, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                );
              }),

              if (_drafts.length > 15)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    '+ ${_drafts.length - 15} more records',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: BentoTheme.textSecondary, fontSize: 12),
                  ),
                ),

              const SizedBox(height: 20),

              // Action button
              ElevatedButton(
                onPressed: _isImporting ? null : _executeImport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: BentoTheme.accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isImporting
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text('Import $newCount Transactions', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const SizedBox(height: 30),
            ],
          ],
        ),
      ),
    );
  }

  Widget _summaryBadge(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: BentoTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text('$count', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: BentoTheme.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}
