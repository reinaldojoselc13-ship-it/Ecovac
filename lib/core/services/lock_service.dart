// LockService stub: biometric authentication (local_auth) removed.
// This file intentionally provides a no-op API so callers do not need
// conditional imports elsewhere. All methods return false (not authenticated).
class LockService {
  LockService._internal();
  static final LockService _instance = LockService._internal();
  factory LockService() => _instance;

  Future<bool> canAuthenticate() async => false;

  Future<bool> authenticate({String reason = 'Authenticate'}) async => false;
}
