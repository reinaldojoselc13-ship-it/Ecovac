import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:ecovac/core/services/api_service.dart';

class VacunasProvider extends ChangeNotifier {
  final ApiService api;
  bool loading = false;
  List<Map<String, dynamic>> items = [];
  StreamSubscription<List<Map<String, dynamic>>>? _sub;

  VacunasProvider(this.api);

  Future<void> load() async {
    if (loading) return;
    loading = true;
    notifyListeners();
    try {
      items = await api.getVacunas();
    } catch (_) {
      items = [];
    }
    loading = false;
    notifyListeners();
  }

  void startRealtime() {
    _sub?.cancel();
    try {
      _sub = api.streamVacunas().listen((rows) {
        items = rows;
        loading = false;
        notifyListeners();
      });
    } catch (_) {}
  }

  /// Compatibility alias
  void startAutoRefresh([int seconds = 5]) => startRealtime();

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<bool> create(Map<String, dynamic> data) async {
    try {
      final created = await api.createVacuna(data);
      if (created == null) return false;
      // optimistic add: items will be refreshed by stream, but ensure visible immediately
      items.insert(0, created);
      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) print('VacunasProvider.create error: $e');
      return false;
    }
  }

  Future<bool> update(String id, Map<String, dynamic> data) async {
    try {
      final updated = await api.updateVacuna(id, data);
      if (updated == null) return false;
      final idx = items.indexWhere((it) => it['id']?.toString() == id);
      if (idx >= 0) items[idx] = updated;
      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) print('VacunasProvider.update error: $e');
      return false;
    }
  }

  Future<bool> delete(String id) async {
    try {
      final ok = await api.deleteVacuna(id);
      if (!ok) return false;
      items.removeWhere((it) => it['id']?.toString() == id);
      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) print('VacunasProvider.delete error: $e');
      return false;
    }
  }
}
