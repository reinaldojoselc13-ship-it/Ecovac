import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:ecovac/core/services/api_service.dart';

class VetProfilesProvider extends ChangeNotifier {
  final ApiService _api;

  /// Provider mantenido por compatibilidad; usa la API neutralizada.
  ///
  /// Explicación técnica: la clase expone conteos y operaciones CRUD pero
  /// delega en los métodos genéricos de `ApiService` para evitar lógica
  /// domain-specific residual.
  VetProfilesProvider(this._api);

  int total = 0;
  int active = 0;
  int inactive = 0;

  bool loading = false;
  Timer? _pollTimer;

  Future<void> loadCounts() async {
    if (loading) return;
    loading = true;
    notifyListeners();
    final stats = await _api.getStaffStats();
    total = stats['total'] ?? 0;
    active = stats['active'] ?? 0;
    inactive = stats['inactive'] ?? 0;
    loading = false;
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> fetchProfiles() async {
    return await _api.getStaffProfiles();
  }

  Future<void> createProfile(Map<String, dynamic> data) async {
    await _api.createStaffProfile(data);
    await loadCounts();
  }

  Future<void> updateProfile(String id, Map<String, dynamic> data) async {
    try {
      final updated = await _api.updateStaffProfile(id, data);
      if (updated == null) {
        // possible permission issue or not found
        return;
      }
    } catch (e) {
      if (kDebugMode) print('VetProfilesProvider.updateProfile error: $e');
    }
    await loadCounts();
  }

  /// Permite al administrador asignar una nota/tarea a un perfil.
  /// Se guarda como campo `assigned_task` en la fila de `staff`.
  Future<void> assignTask(String staffId, String task) async {
    await _api.updateStaffProfile(staffId, {'assigned_task': task, 'assigned_at': DateTime.now().toIso8601String()});
    await loadCounts();
  }

  /// Auto-refresh para que veterinarios reciban cambios del administrador.
  void startAutoRefresh([int seconds = 5]) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(Duration(seconds: seconds), (_) async {
      await loadCounts();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> deauthorizeDevice(String staffId, String deviceId) async {
    await _api.deauthorizeDevice(staffId, deviceId);
  }
}
