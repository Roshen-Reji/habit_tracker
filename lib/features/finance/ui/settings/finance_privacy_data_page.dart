import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/features/finance/data/finance_controller.dart';
import 'package:habit_tracker/features/finance/data/backup/finance_backup_service.dart';
import 'package:habit_tracker/features/finance/data/finance_encryption_service.dart';
import 'package:habit_tracker/features/finance/data/finance_lock_service.dart';
import 'package:habit_tracker/features/finance/data/finance_repository.dart';
import 'package:habit_tracker/features/finance/ui/ai/ai_privacy_page.dart';

class FinancePrivacyDataPage extends StatefulWidget {
  const FinancePrivacyDataPage({super.key});

  @override
  State<FinancePrivacyDataPage> createState() => _FinancePrivacyDataPageState();
}

class _FinancePrivacyDataPageState extends State<FinancePrivacyDataPage> {
  final FinanceLockService _lockService = FinanceLockService.instance;
  final FinanceEncryptionService _encryptionService =
      FinanceEncryptionService.instance;
  final FinanceController _controller = FinanceController();
  late final FinanceRepository _repository = _controller.repository;

  bool _isLockEnabled = false;
  int _timeoutMinutes = 0;
  bool _lockOnBackground = true;
  bool _isEncrypted = false;
  bool _hasUnencryptedBackup = false;

  int _receiptCount = 0;

  @override
  void initState() {
    super.initState();
    _isLockEnabled = _lockService.isLockEnabled;
    _timeoutMinutes = _lockService.timeoutMinutes;
    _lockOnBackground = _lockService.lockOnBackground;
    _isEncrypted = _encryptionService.isEncrypted;
    _hasUnencryptedBackup = _encryptionService.hasUnencryptedBackup;
    _loadReceiptStats();
  }

  Future<void> _loadReceiptStats() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final receiptsDir = Directory('${dir.path}/receipts');
      if (await receiptsDir.exists()) {
        final files =
            receiptsDir.listSync(recursive: true).whereType<File>().toList();
        if (mounted) setState(() => _receiptCount = files.length);
      }
    } catch (e) {
      debugPrint('Receipts count scan error: $e');
    }
  }

  Future<void> _toggleLock(bool val) async {
    if (val) {
      final success = await _lockService.authenticateAndUnlock();
      if (!success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Authentication required to enable app lock')),
          );
        }
        return;
      }
    }
    await _lockService.setLockEnabled(val);
    setState(() => _isLockEnabled = val);
    HapticFeedback.selectionClick();
  }

  Future<void> _handleEncryptBoxes() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BentoTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Encrypt Finance Data',
            style: TextStyle(
                color: BentoTheme.textPrimary, fontWeight: FontWeight.bold)),
        content: Text(
          'This will AES-256 encrypt all your accounts, transactions, budgets and goals at rest using device secure storage.\n\nA backup copy is kept until you verify everything works.',
          style: TextStyle(
              color: BentoTheme.textSecondary, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: TextStyle(color: BentoTheme.textSecondary))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: BentoTheme.accent,
                foregroundColor: Colors.black),
            child: const Text('Encrypt Now'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final success = await _encryptionService.migrateToEncryptedBoxes();
    if (mounted) {
      setState(() {
        _isEncrypted = _encryptionService.isEncrypted;
        _hasUnencryptedBackup = _encryptionService.hasUnencryptedBackup;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? '✓ Finance boxes successfully encrypted!'
              : 'Encryption migration failed. Reverted safely.'),
          backgroundColor: success ? const Color(0xFF22C55E) : Colors.red,
        ),
      );
    }
  }

  Future<void> _handleDeleteUnencryptedBackup() async {
    await _encryptionService.deleteUnencryptedBackup();
    if (mounted) {
      setState(() => _hasUnencryptedBackup = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unencrypted backup deleted.')),
      );
    }
  }

  Future<void> _exportJson() async {
    final jsonStr = await FinanceBackupService.exportJson();
    final tempDir = await getTemporaryDirectory();
    final file = File(
        '${tempDir.path}/finance_backup_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.json');
    await file.writeAsString(jsonStr);
    await Share.shareXFiles([XFile(file.path)], text: 'Money OS JSON Export');
  }

  Future<void> _exportCsv() async {
    final csv = _controller.exportTransactionsToCsv();
    final tempDir = await getTemporaryDirectory();
    final file = File(
        '${tempDir.path}/transactions_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv');
    await file.writeAsString(csv);
    await Share.shareXFiles([XFile(file.path)],
        text: 'Transactions CSV Export');
  }

  Future<void> _confirmDeleteAllFinanceData() async {
    final inputController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          final isMatched = inputController.text.trim() == 'DELETE';

          return AlertDialog(
            backgroundColor: BentoTheme.surface,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(LucideIcons.alertTriangle,
                    color: Colors.red, size: 24),
                const SizedBox(width: 8),
                Text('Delete All Finance Data',
                    style: TextStyle(
                        color: BentoTheme.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This will permanently wipe all transactions, accounts, budgets, goals, recurring rules, receipts, and settings. This action CANNOT be undone.',
                  style: TextStyle(
                      color: BentoTheme.textSecondary,
                      fontSize: 13,
                      height: 1.4),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _exportJson,
                  icon: const Icon(LucideIcons.download, size: 14),
                  label: const Text('Export Backup First (Recommended)'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: BentoTheme.accent,
                    side: BorderSide(color: BentoTheme.accent),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Type "DELETE" to confirm:',
                  style: TextStyle(
                      color: BentoTheme.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: inputController,
                  autofocus: true,
                  style: const TextStyle(
                      color: Colors.red, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: 'DELETE',
                    hintStyle: TextStyle(color: Colors.white24),
                    filled: true,
                    fillColor: BentoTheme.background,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none),
                  ),
                  onChanged: (_) => setDlgState(() {}),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text('Cancel',
                      style: TextStyle(color: BentoTheme.textSecondary))),
              ElevatedButton(
                onPressed: isMatched ? () => Navigator.pop(ctx, true) : null,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red, foregroundColor: Colors.white),
                child: const Text('WIPE EVERYTHING'),
              ),
            ],
          );
        },
      ),
    );

    if (result != true) return;

    // Execute wipe per P13-4
    await _executeFullWipe();
  }

  Future<void> _executeFullWipe() async {
    // 1. Wipe all finance boxes
    final storage = _repository.storage;
    await storage.transactionBox.clear();
    await storage.accountBox.clear();
    await storage.categoryBox.clear();
    await storage.ruleBox.clear();
    await storage.recurringBox.clear();
    await storage.budgetLineBox.clear();
    await storage.budgetOverrideBox.clear();
    await storage.goalBox.clear();
    await storage.goalEntryBox.clear();
    await storage.valuationBox.clear();
    await storage.splitGroupBox.clear();
    await storage.splitEntryBox.clear();

    // 2. Wipe receipts directory
    try {
      final dir = await getApplicationDocumentsDirectory();
      final receiptsDir = Directory('${dir.path}/receipts');
      if (await receiptsDir.exists()) {
        await receiptsDir.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('Receipts wipe directory error: $e');
    }

    // 3. Reset settings and fin_schema_version
    await storage.settingsBox.clear();
    await storage.settingsBox.put('fin_schema_version', 0);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('All finance data has been wiped.'),
            backgroundColor: Colors.red),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final txCount = _controller.allTransactions.length;
    final accCount = _controller.activeAccounts.length;

    return Scaffold(
      backgroundColor: BentoTheme.background,
      appBar: AppBar(
        backgroundColor: BentoTheme.background,
        elevation: 0,
        title: Text(
          'Privacy, Security & Data',
          style: TextStyle(
              color: BentoTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: BentoTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Storage Footprint Summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: BentoTheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(LucideIcons.hardDrive,
                        color: BentoTheme.accent, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'LOCAL DATA FOOTPRINT',
                      style: TextStyle(
                          color: BentoTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatCol('Transactions', txCount.toString()),
                    _buildStatCol('Accounts', accCount.toString()),
                    _buildStatCol('Receipts', _receiptCount.toString()),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // App Lock Section (P13-2)
          Text('SECURITY & APP LOCK', style: _sectionHeaderStyle),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: BentoTheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  value: _isLockEnabled,
                  activeColor: BentoTheme.accent,
                  title: Text('Require Biometrics / Device PIN',
                      style: TextStyle(
                          color: BentoTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  subtitle: Text(
                      'Lock Money OS with fingerprint, face or passcode',
                      style: TextStyle(
                          color: BentoTheme.textSecondary, fontSize: 12)),
                  onChanged: _toggleLock,
                ),
                if (_isLockEnabled) ...[
                  Divider(color: BentoTheme.divider, height: 1),
                  ListTile(
                    title: Text('Auto-lock timeout',
                        style: TextStyle(
                            color: BentoTheme.textPrimary, fontSize: 14)),
                    trailing: DropdownButton<int>(
                      value: _timeoutMinutes,
                      dropdownColor: BentoTheme.surface,
                      style: TextStyle(
                          color: BentoTheme.accent,
                          fontSize: 13,
                          fontWeight: FontWeight.bold),
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('Immediately')),
                        DropdownMenuItem(value: 1, child: Text('1 minute')),
                        DropdownMenuItem(value: 5, child: Text('5 minutes')),
                        DropdownMenuItem(value: 15, child: Text('15 minutes')),
                      ],
                      onChanged: (val) async {
                        if (val != null) {
                          await _lockService.setTimeoutMinutes(val);
                          setState(() => _timeoutMinutes = val);
                        }
                      },
                    ),
                  ),
                  Divider(color: BentoTheme.divider, height: 1),
                  SwitchListTile(
                    value: _lockOnBackground,
                    activeColor: BentoTheme.accent,
                    title: Text('Lock when app sent to background',
                        style: TextStyle(
                            color: BentoTheme.textPrimary, fontSize: 14)),
                    onChanged: (val) async {
                      await _lockService.setLockOnBackground(val);
                      setState(() => _lockOnBackground = val);
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // At-Rest Encryption (P13-3)
          Text('AT-REST ENCRYPTION', style: _sectionHeaderStyle),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: BentoTheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isEncrypted ? LucideIcons.lock : LucideIcons.unlock,
                          color: _isEncrypted
                              ? BentoTheme.positive
                              : BentoTheme.warning,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isEncrypted
                              ? 'AES-256 Encrypted'
                              : 'Standard Hive Storage',
                          style: TextStyle(
                            color: _isEncrypted
                                ? BentoTheme.positive
                                : BentoTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    if (!_isEncrypted)
                      ElevatedButton(
                        onPressed: _handleEncryptBoxes,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: BentoTheme.accent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text('Encrypt',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _isEncrypted
                      ? 'Your local database is encrypted on flash storage using a secure key in the Android Keystore.'
                      : 'Data is saved in local app storage without custom encryption.',
                  style:
                      TextStyle(color: BentoTheme.textSecondary, fontSize: 12),
                ),
                if (_hasUnencryptedBackup) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Unencrypted backup available',
                          style: TextStyle(
                              color: BentoTheme.textSecondary, fontSize: 12)),
                      TextButton(
                        onPressed: _handleDeleteUnencryptedBackup,
                        child: Text('Delete Backup',
                            style: TextStyle(
                                color: BentoTheme.negative, fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // AI & Privacy Link (P11-4)
          ListTile(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            tileColor: BentoTheme.surface,
            leading: Icon(LucideIcons.sparkles, color: BentoTheme.accent),
            title: Text('AI & Privacy Controls',
                style: TextStyle(
                    color: BentoTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            subtitle: Text(
                'Manage what is shared with Gemini and rewording settings',
                style:
                    TextStyle(color: BentoTheme.textSecondary, fontSize: 12)),
            trailing: Icon(LucideIcons.chevronRight,
                size: 16, color: BentoTheme.textSecondary),
            onTap: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AiPrivacyPage()));
            },
          ),
          const SizedBox(height: 20),

          // Backup & Export
          Text('EXPORT & BACKUP', style: _sectionHeaderStyle),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _exportJson,
                  icon: const Icon(LucideIcons.fileJson, size: 16),
                  label: const Text('JSON Backup'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: BentoTheme.accent,
                    side: BorderSide(color: Colors.white12),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _exportCsv,
                  icon: const Icon(LucideIcons.fileSpreadsheet, size: 16),
                  label: const Text('CSV Export'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: BentoTheme.accent,
                    side: BorderSide(color: BentoTheme.divider),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Danger Zone (P13-4)
          Text('DANGER ZONE',
              style: TextStyle(
                  color: BentoTheme.negative,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: BentoTheme.negative.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Delete All Finance Data',
                  style: TextStyle(
                      color: BentoTheme.negative,
                      fontWeight: FontWeight.bold,
                      fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  'Permanently clear all accounts, transactions, recurring rules, receipts, and settings. Habits and diet data are not affected.',
                  style: TextStyle(
                      color: BentoTheme.textSecondary,
                      fontSize: 12,
                      height: 1.4),
                ),
                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: _confirmDeleteAllFinanceData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BentoTheme.negative,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Delete All Finance Data'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildStatCol(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: BentoTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(color: BentoTheme.textSecondary, fontSize: 11)),
      ],
    );
  }

  TextStyle get _sectionHeaderStyle => TextStyle(
        color: BentoTheme.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
      );
}
