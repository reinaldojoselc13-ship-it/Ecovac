import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:ecovac/core/services/api_service.dart';
import 'package:get_it/get_it.dart';
import 'package:ecovac/core/services/notification_service.dart';

class JornadasProvider extends ChangeNotifier {
  final ApiService _api;

  JornadasProvider([ApiService? api]) : _api = api ?? (GetIt.instance.isRegistered<ApiService>() ? GetIt.instance<ApiService>() : ApiService());

  int totalJornadas = 0;
  List<Map<String, dynamic>> items = [];
  bool loading = false;
  StreamSubscription<List<Map<String, dynamic>>>? _sub;

  Future<void> loadCounts() async {
    if (loading) return;
    loading = true;
    notifyListeners();
    totalJornadas = await _api.getJornadasCount();
    items = await _api.getJornadas();
    loading = false;
    notifyListeners();
  }

  /// Inicia un refresco periódico para que cambios en la base se reflejen
  /// Inicia una suscripción realtime contra la tabla `jornadas`.
  /// Actualiza `items` automáticamente cuando llegan eventos.
  void startRealtime() {
    _sub?.cancel();
    try {
      _sub = _api.streamJornadas().listen((rows) {
        items = rows;
        totalJornadas = rows.length;
        notifyListeners();
      });
    } catch (_) {}
  }

  /// Compatibilidad con código anterior que esperaba startAutoRefresh.
  void startAutoRefresh([int seconds = 5]) {
    // startRealtime no usa polling pero exponemos el método para compatibilidad
    startRealtime();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<bool> create(Map<String, dynamic> data) async {
    final created = await _api.createJornada(data);
    if (created == null) return false;
    await loadCounts();
    try {
      final notif = NotificationService();
      final granted = await notif.requestPermissions();
      if (granted) {
        final id = DateTime.now().millisecondsSinceEpoch.remainder(100000);
        final title = 'Nueva jornada creada';
        final body = data['title'] ?? data['name'] ?? 'Se ha creado una nueva jornada.';
        await notif.showNotification(id, title, body);
      }
    } catch (e) {
      if (kDebugMode) print('Notification error: $e');
    }
    return true;
  }

  Future<void> update(String id, Map<String, dynamic> data) async {
    await _api.updateJornada(id, data);
    await loadCounts();
  }

  Future<void> delete(String id) async {
    await _api.deleteJornada(id);
    await loadCounts();
  }
}
