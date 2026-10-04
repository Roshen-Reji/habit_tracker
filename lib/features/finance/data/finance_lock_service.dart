import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:local_auth/local_auth.dart';

class FinanceLockService {
  static final FinanceLockService instance = FinanceLockService._internal();
  factory FinanceLockService() => instance;
  FinanceLockService._internal();

  LocalAuthentication _localAuth = LocalAuthentication();
  final ValueNotifier<bool> isUnlocked = ValueNotifier<bool>(true);
  DateTime? _lastActiveTime;

  @visibleForTesting
  void setMockDependencies({LocalAuthentication? localAuth}) {
    if (localAuth != null) _localAuth = localAuth;
  }

  Box get _settingsBox => Hive.box('finance_settings');

  bool get isLockEnabled => _settingsBox.get('lock_enabled', defaultValue: false) as bool;
  int get timeoutMinutes => _settingsBox.get('lock_timeout_minutes', defaultValue: 0) as int;
  bool get lockOnBackground => _settingsBox.get('lock_on_background', defaultValue: true) as bool;
  bool get hideFromRecents => _settingsBox.get('hide_from_recents', defaultValue: false) as bool;

  Future<void> setLockEnabled(bool value) async {
    await _settingsBox.put('lock_enabled', value);
    if (!value) {
      isUnlocked.value = true;
    }
  }

  Future<void> setTimeoutMinutes(int minutes) async {
    await _settingsBox.put('lock_timeout_minutes', minutes);
  }

  Future<void> setLockOnBackground(bool value) async {
    await _settingsBox.put('lock_on_background', value);
  }

  Future<void> setHideFromRecents(bool value) async {
    await _settingsBox.put('hide_from_recents', value);
  }

  void initializeAtStartup() {
    if (isLockEnabled) {
      isUnlocked.value = false;
    } else {
      isUnlocked.value = true;
    }
  }

  /// Authenticate using device biometrics or credentials via local_auth
  Future<bool> authenticateAndUnlock() async {
    if (!isLockEnabled) {
      isUnlocked.value = true;
      return true;
    }

    try {
      final canAuthenticate = await _localAuth.canCheckBiometrics ||
          await _localAuth.isDeviceSupported();

      if (!canAuthenticate) {
        isUnlocked.value = true;
        _lastActiveTime = DateTime.now();
        return true;
      }

      final success = await _localAuth.authenticate(
        localizedReason: 'Authenticate to access Money OS',
      );

      if (success) {
        isUnlocked.value = true;
        _lastActiveTime = DateTime.now();
      }
      return success;
    } catch (e) {
      debugPrint('Finance localAuth error: $e');
      return false;
    }
  }

  void lock() {
    if (isLockEnabled) {
      isUnlocked.value = false;
      _lastActiveTime = null;
    }
  }

  void recordActivity() {
    _lastActiveTime = DateTime.now();
  }

  /// Checks if the timeout has passed since the last activity.
  void checkTimeout() {
    if (!isLockEnabled || !isUnlocked.value) return;
    if (_lastActiveTime == null) {
      lock();
      return;
    }

    final diff = DateTime.now().difference(_lastActiveTime!).inMinutes;
    if (diff >= timeoutMinutes) {
      lock();
    }
  }

  void onAppPaused() {
    if (isLockEnabled && lockOnBackground) {
      lock();
    }
  }
}
