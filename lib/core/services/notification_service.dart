import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Lightweight NotificationService stub.
/// The real `flutter_local_notifications` plugin was removed to avoid
/// Android build issues; this class preserves the same surface used
/// by the app but performs no native notifications — it requests
/// permissions and logs calls.
class NotificationService {
  NotificationService._internal();
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    // No native initialization without the plugin.
    _initialized = true;
    if (kDebugMode) print('NotificationService initialized (stub)');
  }

  /// Requests notification permission from the OS. Returns true if granted.
  Future<bool> requestPermissions() async {
    try {
      final status = await Permission.notification.status;
      if (status.isGranted) return true;
      final result = await Permission.notification.request();
      return result.isGranted;
    } catch (e) {
      if (kDebugMode) print('Permission request failed: $e');
      return false;
    }
  }

  /// Stub for showing notifications. Logs the call when in debug mode.
  Future<void> showNotification(int id, String title, String body) async {
    if (!_initialized) await init();
    if (kDebugMode) {
      print('showNotification (stub) id=$id title="$title" body="$body"');
    }
    // No-op on platforms without the plugin.
  }
}
