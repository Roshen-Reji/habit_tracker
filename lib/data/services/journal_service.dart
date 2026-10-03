import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:habit_tracker/data/models/productivity_models.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:local_auth/local_auth.dart';

class JournalService {
  static const String _keyStorageKey = 'journal_encryption_key_v1';
  static const String boxName = 'journals';

  static final JournalService instance = JournalService._();
  JournalService._();

  FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  LocalAuthentication _localAuth = LocalAuthentication();

  final ValueNotifier<bool> isUnlocked = ValueNotifier<bool>(false);
  DateTime? _lastActiveTime;

  @visibleForTesting
  void setMockDependencies({
    FlutterSecureStorage? secureStorage,
    LocalAuthentication? localAuth,
  }) {
    if (secureStorage != null) _secureStorage = secureStorage;
    if (localAuth != null) _localAuth = localAuth;
  }

  /// Retrieves or generates the 32-byte encryption key for AES cipher.
  Future<List<int>> getOrCreateEncryptionKey({List<int>? explicitKey}) async {
    if (explicitKey != null) {
      if (explicitKey.length != 32) {
        throw ArgumentError('Encryption key must be exactly 32 bytes.');
      }
      return explicitKey;
    }

    try {
      final storedKeyString = await _secureStorage.read(key: _keyStorageKey);
      if (storedKeyString != null) {
        return base64Decode(storedKeyString);
      }
    } catch (_) {
      // Secure storage read error or not supported on this platform in test
    }

    // Generate fresh 32-byte key
    final newKey = Hive.generateSecureKey();
    try {
      await _secureStorage.write(
        key: _keyStorageKey,
        value: base64Encode(newKey),
      );
    } catch (_) {
      // Best effort in test environments
    }
    return newKey;
  }

  /// Initializes and opens the encrypted journals box.
  Future<Box<JournalEntry>> openEncryptedBox({List<int>? key}) async {
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box<JournalEntry>(boxName);
    }
    final encryptionKey = await getOrCreateEncryptionKey(explicitKey: key);
    return await Hive.openBox<JournalEntry>(
      boxName,
      encryptionCipher: HiveAesCipher(encryptionKey),
    );
  }

  /// Authenticates using device credentials or biometrics via local_auth.
  Future<bool> authenticateAndUnlock() async {
    try {
      final canAuthenticate = await _localAuth.canCheckBiometrics ||
          await _localAuth.isDeviceSupported();

      if (!canAuthenticate) {
        // Fallback for devices without biometric or PIN lock configured
        isUnlocked.value = true;
        _lastActiveTime = DateTime.now();
        return true;
      }

      final success = await _localAuth.authenticate(
        localizedReason: 'Authenticate to view your private journals',
      );

      if (success) {
        isUnlocked.value = true;
        _lastActiveTime = DateTime.now();
      }
      return success;
    } catch (e) {
      debugPrint('LocalAuth error: $e');
      return false;
    }
  }

  /// Locks the journal view.
  void lock() {
    isUnlocked.value = false;
    _lastActiveTime = null;
  }

  /// Records user activity to keep the session active.
  void recordActivity() {
    _lastActiveTime = DateTime.now();
  }

  /// Checks if the lock timeout has elapsed.
  void checkAutoLock({int? timeoutSeconds}) {
    if (!isUnlocked.value || _lastActiveTime == null) return;

    int timeout = timeoutSeconds ?? 60;
    if (timeout <= 0) timeout = 60;

    final elapsed = DateTime.now().difference(_lastActiveTime!).inSeconds;
    if (elapsed >= timeout) {
      lock();
    }
  }

  /// Call when app enters background or inactive state.
  void onAppLifecycleChanged(bool isBackgrounded) {
    if (isBackgrounded) {
      lock();
    }
  }

  // --- CRUD Operations ---

  List<JournalEntry> getEntries() {
    if (!Hive.isBoxOpen(boxName)) return [];
    final entries = Hive.box<JournalEntry>(boxName).values.toList();
    entries.sort((a, b) {
      if (a.pinned != b.pinned) {
        return a.pinned ? -1 : 1;
      }
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return entries;
  }

  JournalEntry? getEntry(String id) {
    if (!Hive.isBoxOpen(boxName)) return null;
    return Hive.box<JournalEntry>(boxName).get(id);
  }

  Future<void> saveEntry(JournalEntry entry) async {
    final box = await openEncryptedBox();
    await box.put(entry.id, entry);
    recordActivity();
  }

  Future<void> deleteEntry(String id) async {
    final box = await openEncryptedBox();
    await box.delete(id);
    recordActivity();
  }

  Future<void> togglePin(String id) async {
    final entry = getEntry(id);
    if (entry != null) {
      entry.pinned = !entry.pinned;
      entry.updatedAt = DateTime.now();
      await entry.save();
      recordActivity();
    }
  }
}
