import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' hide Category;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:habit_tracker/data/services/gemini_client.dart';
import 'package:habit_tracker/features/finance/engine/money.dart';
import 'package:habit_tracker/features/finance/models/models.dart';

/// Draft transaction produced by a TransactionSource (CSV, SMS, etc.)
class TransactionDraft {
  DateTime date;
  double amount; // signed: negative for expense, positive for income
  String title;
  String? merchant;
  String? categoryId;
  String? accountId;
  String? toAccountId;
  String kind; // 'expense', 'income', 'transfer', etc.
  String? paymentMethod;
  String? notes;
  List<String> tags;
  String? sourceRef;
  List<String> receiptPaths;
  bool isDuplicate;
  bool isSuggestedTransfer;
  int? matchedTransferIndex;

  TransactionDraft({
    required this.date,
    required this.amount,
    required this.title,
    this.merchant,
    this.categoryId,
    this.accountId,
    this.toAccountId,
    this.kind = 'expense',
    this.paymentMethod,
    this.notes,
    this.tags = const [],
    this.sourceRef,
    this.receiptPaths = const [],
    this.isDuplicate = false,
    this.isSuggestedTransfer = false,
    this.matchedTransferIndex,
  });

  String get effectiveKind => kind;
}

/// Abstract contract for transaction capture sources (CSV, SMS) per P10-6
abstract class TransactionSource {
  Future<List<TransactionDraft>> fetch();
}

/// Normalizer for merchant and payee descriptions
class MerchantNormalizer {
  static final RegExp _upiRefRegex = RegExp(
      r'(?:upi|ref|rrn|txn|id)[:\-\s]*[0-9a-zA-Z]+',
      caseSensitive: false);
  static final RegExp _digitsRegex = RegExp(r'\b\d+\b');
  static final RegExp _domainRegex =
      RegExp(r'\.(?:com|in|co|org|net|io|app)\b', caseSensitive: false);
  static final RegExp _punctRegex = RegExp(r'[*_#@/\\:;,\-\[\]()]');

  /// Normalizes a raw bank or merchant string into a clean lookup token
  static String normalize(String raw) {
    if (raw.trim().isEmpty) return '';
    var s = raw.toLowerCase();

    // Remove domains
    s = s.replaceAll(_domainRegex, '');

    // Remove UPI / RRN / Txn reference tokens
    s = s.replaceAll(_upiRefRegex, '');

    // Remove common prefixes
    s = s.replaceAll(
        RegExp(r'\b(?:pos|ecom|vpa|ach|neft|rtgs|imps|autopay|mandate)\b'), '');

    // Remove punctuation
    s = s.replaceAll(_punctRegex, ' ');

    // Remove isolated digits
    s = s.replaceAll(_digitsRegex, ' ');

    // Normalize whitespace
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Map common merchant keywords
    if (s.contains('swiggy')) return 'swiggy';
    if (s.contains('zomato')) return 'zomato';
    if (s.contains('amazon')) return 'amazon';
    if (s.contains('flipkart')) return 'flipkart';
    if (s.contains('uber')) return 'uber';
    if (s.contains('ola')) return 'ola';
    if (s.contains('netflix')) return 'netflix';
    if (s.contains('spotify')) return 'spotify';
    if (s.contains('starbucks')) return 'starbucks';
    if (s.contains('blinkit') || s.contains('grofers')) return 'blinkit';
    if (s.contains('zepto')) return 'zepto';
    if (s.contains('instamart')) return 'instamart';

    return s;
  }
}

/// Category Rule Matcher per P10-2
class CategorizationRulesEngine {
  /// Matches a transaction against active rules, ordered by priority descending
  static String? matchCategory({
    required String rawTitle,
    required String? rawMerchant,
    required List<CategoryRule> rules,
  }) {
    if (rules.isEmpty) return null;

    final sortedRules = List<CategoryRule>.from(rules)
      ..sort((a, b) => b.priority.compareTo(a.priority));

    final normMerchant = MerchantNormalizer.normalize(rawMerchant ?? rawTitle);
    final normTitle = rawTitle.toLowerCase();

    for (final rule in sortedRules) {
      final pattern = rule.pattern.toLowerCase();
      bool isMatch = false;

      switch (rule.matchType) {
        case 'exact':
          isMatch = (normMerchant == pattern || normTitle == pattern);
          break;
        case 'regex':
          try {
            final reg = RegExp(rule.pattern, caseSensitive: false);
            isMatch = reg.hasMatch(rawTitle) ||
                (rawMerchant != null && reg.hasMatch(rawMerchant));
          } catch (_) {
            isMatch = false;
          }
          break;
        case 'contains':
        default:
          isMatch =
              normMerchant.contains(pattern) || normTitle.contains(pattern);
          break;
      }

      if (isMatch) {
        return rule.categoryId;
      }
    }

    return null;
  }
}

/// CSV Mapping Profile for saving and reusing bank-specific formats
class CsvMappingProfile {
  final String name;
  final String delimiter;
  final int dateColumn;
  final String dateFormat;
  final int descriptionColumn;
  final int? amountColumn; // for single signed column
  final int? debitColumn; // for separate debit
  final int? creditColumn; // for separate credit
  final bool hasHeader;

  const CsvMappingProfile({
    required this.name,
    this.delimiter = ',',
    required this.dateColumn,
    this.dateFormat = 'dd/MM/yyyy',
    required this.descriptionColumn,
    this.amountColumn,
    this.debitColumn,
    this.creditColumn,
    this.hasHeader = true,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'delimiter': delimiter,
        'dateColumn': dateColumn,
        'dateFormat': dateFormat,
        'descriptionColumn': descriptionColumn,
        'amountColumn': amountColumn,
        'debitColumn': debitColumn,
        'creditColumn': creditColumn,
        'hasHeader': hasHeader,
      };

  factory CsvMappingProfile.fromJson(Map<String, dynamic> json) =>
      CsvMappingProfile(
        name: json['name'] as String? ?? 'Default Profile',
        delimiter: json['delimiter'] as String? ?? ',',
        dateColumn: json['dateColumn'] as int? ?? 0,
        dateFormat: json['dateFormat'] as String? ?? 'dd/MM/yyyy',
        descriptionColumn: json['descriptionColumn'] as int? ?? 1,
        amountColumn: json['amountColumn'] as int?,
        debitColumn: json['debitColumn'] as int?,
        creditColumn: json['creditColumn'] as int?,
        hasHeader: json['hasHeader'] as bool? ?? true,
      );
}

/// Robust CSV Parser handling RFC 4180, delimiter auto-detection and dedupe
class CsvParser {
  /// Auto-detects delimiter from the first few lines of CSV content
  static String autoDetectDelimiter(String content) {
    final lines = content.split(RegExp(r'\r?\n')).take(5).toList();
    if (lines.isEmpty) return ',';

    int commaCount = 0;
    int semicolonCount = 0;
    int tabCount = 0;

    for (final line in lines) {
      commaCount += ','.allMatches(line).length;
      semicolonCount += ';'.allMatches(line).length;
      tabCount += '\t'.allMatches(line).length;
    }

    if (semicolonCount > commaCount && semicolonCount > tabCount) return ';';
    if (tabCount > commaCount && tabCount > semicolonCount) return '\t';
    return ',';
  }

  /// RFC 4180 compliant CSV line tokenizer
  static List<List<String>> parseCsv(String input, {String delimiter = ','}) {
    final rows = <List<String>>[];
    final currentField = StringBuffer();
    final currentRow = <String>[];
    bool inQuotes = false;

    for (int i = 0; i < input.length; i++) {
      final char = input[i];

      if (char == '"') {
        if (inQuotes && i + 1 < input.length && input[i + 1] == '"') {
          currentField.write('"');
          i++; // Skip escaped quote
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == delimiter && !inQuotes) {
        currentRow.add(currentField.toString().trim());
        currentField.clear();
      } else if ((char == '\n' || char == '\r') && !inQuotes) {
        if (char == '\r' && i + 1 < input.length && input[i + 1] == '\n') {
          i++; // Skip \n after \r
        }
        currentRow.add(currentField.toString().trim());
        currentField.clear();
        if (currentRow.any((c) => c.isNotEmpty)) {
          rows.add(List<String>.from(currentRow));
        }
        currentRow.clear();
      } else {
        currentField.write(char);
      }
    }

    if (currentField.isNotEmpty || currentRow.isNotEmpty) {
      currentRow.add(currentField.toString().trim());
      if (currentRow.any((c) => c.isNotEmpty)) {
        rows.add(currentRow);
      }
    }

    return rows;
  }

  /// Parses date with fallback formats
  static DateTime parseDate(String raw, String preferredFormat) {
    final clean = raw.trim();
    final formats = [
      preferredFormat,
      'yyyy-MM-dd',
      'dd/MM/yyyy',
      'MM/dd/yyyy',
      'dd-MM-yyyy',
      'yyyy/MM/dd',
      'd/M/yyyy',
      'd-M-yyyy',
    ];

    for (final fmt in formats) {
      try {
        return DateFormat(fmt).parseStrict(clean);
      } catch (_) {}
    }

    // Try standard DateTime parse as last resort
    try {
      return DateTime.parse(clean);
    } catch (_) {
      return DateTime.now();
    }
  }

  /// Generates deterministic dedupe hash for sourceRef = import:{hash}
  static String generateDedupeKey({
    required DateTime date,
    required double amount,
    required String normalizedDesc,
    String? accountId,
  }) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final amtStr = amount.abs().toStringAsFixed(2);
    final raw = '$dateStr|$amtStr|$normalizedDesc|${accountId ?? ''}';
    return 'import:${raw.hashCode.abs()}';
  }

  /// Parse rows into TransactionDrafts using a profile
  static List<TransactionDraft> parseDrafts({
    required List<List<String>> rows,
    required CsvMappingProfile profile,
    String? accountId,
    List<CategoryRule> rules = const [],
    Set<String> existingSourceRefs = const {},
  }) {
    final drafts = <TransactionDraft>[];
    final startIndex = profile.hasHeader ? 1 : 0;

    for (var i = startIndex; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty) continue;

      // Extract Date
      if (profile.dateColumn >= row.length) continue;
      final date = parseDate(row[profile.dateColumn], profile.dateFormat);

      // Extract Description / Title
      if (profile.descriptionColumn >= row.length) continue;
      final rawDesc = row[profile.descriptionColumn];
      final normMerchant = MerchantNormalizer.normalize(rawDesc);

      // Extract Amount
      double amount = 0.0;
      String kind = 'expense';

      if (profile.debitColumn != null || profile.creditColumn != null) {
        double debit = 0.0;
        double credit = 0.0;

        if (profile.debitColumn != null && profile.debitColumn! < row.length) {
          debit = _cleanNumber(row[profile.debitColumn!]);
        }
        if (profile.creditColumn != null &&
            profile.creditColumn! < row.length) {
          credit = _cleanNumber(row[profile.creditColumn!]);
        }

        if (debit > 0) {
          amount = -debit;
          kind = 'expense';
        } else if (credit > 0) {
          amount = credit;
          kind = 'income';
        }
      } else if (profile.amountColumn != null &&
          profile.amountColumn! < row.length) {
        amount = _cleanNumber(row[profile.amountColumn!]);
        kind = amount < 0 ? 'expense' : 'income';
      }

      if (amount == 0.0) continue;

      // Categorisation rule lookup
      final matchedCatId = CategorizationRulesEngine.matchCategory(
        rawTitle: rawDesc,
        rawMerchant: normMerchant,
        rules: rules,
      );

      // Deduplication check
      final sourceRef = generateDedupeKey(
        date: date,
        amount: amount,
        normalizedDesc:
            normMerchant.isNotEmpty ? normMerchant : rawDesc.toLowerCase(),
        accountId: accountId,
      );

      final isDuplicate = existingSourceRefs.contains(sourceRef);

      drafts.add(TransactionDraft(
        date: date,
        amount: Money.r2(amount),
        title: rawDesc,
        merchant: normMerchant.isNotEmpty ? normMerchant : null,
        categoryId: matchedCatId,
        accountId: accountId,
        kind: kind,
        sourceRef: sourceRef,
        isDuplicate: isDuplicate,
      ));
    }

    // Detect transfer pairs
    detectTransferPairs(drafts);

    return drafts;
  }

  /// Detects transfer pairs: same amount, opposite sign, different accounts, dated <= 2 days apart
  static void detectTransferPairs(List<TransactionDraft> drafts) {
    for (var i = 0; i < drafts.length; i++) {
      final d1 = drafts[i];
      if (d1.isSuggestedTransfer || d1.isDuplicate) continue;

      for (var j = i + 1; j < drafts.length; j++) {
        final d2 = drafts[j];
        if (d2.isSuggestedTransfer || d2.isDuplicate) continue;

        // Opposite sign, same absolute amount
        if ((d1.amount.abs() - d2.amount.abs()).abs() < 0.01 &&
            ((d1.amount < 0 && d2.amount > 0) ||
                (d1.amount > 0 && d2.amount < 0))) {
          // Different accounts (if both assigned)
          if (d1.accountId != null &&
              d2.accountId != null &&
              d1.accountId == d2.accountId) {
            continue;
          }
          // Date within 2 days
          final diffDays = d1.date.difference(d2.date).inDays.abs();
          if (diffDays <= 2) {
            d1.isSuggestedTransfer = true;
            d1.matchedTransferIndex = j;
            d2.isSuggestedTransfer = true;
            d2.matchedTransferIndex = i;
            break;
          }
        }
      }
    }
  }

  static double _cleanNumber(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^0-9.\-]'), '');
    return double.tryParse(cleaned) ?? 0.0;
  }
}

/// Optional AI Categorisation via Gemini (P10-3)
/// Only sends normalized merchant strings; never amounts or account numbers
class AiCategorizer {
  final GeminiClient _client;

  AiCategorizer({GeminiClient? client}) : _client = client ?? GeminiClient();

  Future<Map<String, String>> categorizeMerchants({
    required List<String> normalizedMerchants,
    required List<Category> availableCategories,
    required String apiKey,
  }) async {
    if (normalizedMerchants.isEmpty || availableCategories.isEmpty) return {};

    final categoriesList = availableCategories
        .map((Category c) => '${c.id}: ${c.name}')
        .join('\n');
    final merchantsList = normalizedMerchants.toSet().take(20).join(', ');

    final prompt = '''
You are a personal finance assistant. Map each of these merchants to the best matching Category ID from the provided categories list.
Categories:
$categoriesList

Merchants to categorize:
$merchantsList

Return ONLY a valid JSON object mapping each merchant to its Category ID, for example:
{"swiggy": "cat_food", "uber": "cat_transport"}
Do not include any explanation or markdown formatting other than raw JSON.
''';

    try {
      final result = await _client.generateContent(
        requestBody: {
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ]
        },
        apiKey: apiKey,
      );

      if (result.isSuccess && result.text != null) {
        var text = result.text!.trim();
        if (text.startsWith('```json')) {
          text = text.replaceAll('```json', '').replaceAll('```', '').trim();
        } else if (text.startsWith('```')) {
          text = text.replaceAll('```', '').trim();
        }
        final Map<String, dynamic> decoded = jsonDecode(text);
        return decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
    } catch (e) {
      debugPrint('AI Categorisation error: $e');
    }

    return {};
  }
}

/// Receipts storage manager (P10-4)
class ReceiptManager {
  /// Save receipt file to local `receipts/{txId}/` folder
  static Future<String> saveReceipt({
    required String txId,
    required File sourceFile,
  }) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final receiptDir = Directory('${docsDir.path}/receipts/$txId');
    if (!receiptDir.existsSync()) {
      receiptDir.createSync(recursive: true);
    }
    final extension = sourceFile.path.split('.').last;
    final filename =
        'receipt_${DateTime.now().millisecondsSinceEpoch}.$extension';
    final targetPath = '${receiptDir.path}/$filename';
    await sourceFile.copy(targetPath);
    return targetPath;
  }

  /// Delete receipts for a transaction
  static Future<void> deleteReceipts(String txId) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final receiptDir = Directory('${docsDir.path}/receipts/$txId');
    if (receiptDir.existsSync()) {
      receiptDir.deleteSync(recursive: true);
    }
  }
}

/// Optional On-Device SMS Parser for Indian Banks & UPI (P10-5)
class SmsTransactionParser {
  // Common Indian Bank SMS regex patterns
  static final RegExp _debitPattern = RegExp(
    r'(?:debited by|spent|withdrawn|debited)\s+(?:rs\.?|inr)\s*([0-9,.]+)\s+(?:at|to|for|via)\s+([a-zA-Z0-9\s._\-*]+?)(?:\s+on|\s+ref|\s+upi|\s+avl|\s+bal|\.|$)',
    caseSensitive: false,
  );

  static final RegExp _creditPattern = RegExp(
    r'(?:credited with|deposited|credited)\s+(?:rs\.?|inr)\s*([0-9,.]+)\s+(?:from|by)\s+([a-zA-Z0-9\s._\-*]+?)(?:\s+on|\s+ref|\s+upi|\s+avl|\s+bal|\.|$)',
    caseSensitive: false,
  );

  static final RegExp _accountPattern = RegExp(
    r'(?:a/c|acct|ac)\s+(?:no\.?)?\s*[xX*]+([0-9]{3,4})',
    caseSensitive: false,
  );

  /// Parse a raw SMS text into a TransactionDraft suggestion
  static TransactionDraft? parseSms(String body, {DateTime? receivedDate}) {
    final clean = body.replaceAll('\n', ' ');
    final date = receivedDate ?? DateTime.now();

    final accMatch = _accountPattern.firstMatch(clean);
    final accSuffix = accMatch != null ? ' (A/c ...${accMatch.group(1)})' : '';

    // Check Debit
    final debitMatch = _debitPattern.firstMatch(clean);
    if (debitMatch != null) {
      final amtStr = debitMatch.group(1)?.replaceAll(',', '') ?? '0';
      final merchantRaw = debitMatch.group(2)?.trim() ?? 'Expense';
      final amt = double.tryParse(amtStr) ?? 0.0;
      if (amt > 0) {
        final normMerchant = MerchantNormalizer.normalize(merchantRaw);
        return TransactionDraft(
          date: date,
          amount: -Money.r2(amt),
          title: merchantRaw,
          merchant: normMerchant.isNotEmpty ? normMerchant : null,
          kind: 'expense',
          paymentMethod: 'UPI',
          notes: 'Auto-parsed from SMS$accSuffix',
        );
      }
    }

    // Check Credit
    final creditMatch = _creditPattern.firstMatch(clean);
    if (creditMatch != null) {
      final amtStr = creditMatch.group(1)?.replaceAll(',', '') ?? '0';
      final senderRaw = creditMatch.group(2)?.trim() ?? 'Deposit';
      final amt = double.tryParse(amtStr) ?? 0.0;
      if (amt > 0) {
        return TransactionDraft(
          date: date,
          amount: Money.r2(amt),
          title: senderRaw,
          kind: 'income',
          paymentMethod: 'Bank Transfer',
          notes: 'Auto-parsed from SMS',
        );
      }
    }

    return null;
  }
}
