import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';
import 'package:ecovac/features/admin/providers/jornadas_provider.dart';
import 'package:ecovac/core/services/api_service.dart';

class _StatCard extends StatelessWidget {
  final String label;
  final String value;

  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final api = GetIt.instance<ApiService>();
    final j = context.watch<JornadasProvider>();

    // Uso de FutureBuilder para obtener estadísticas de personal (modo asincrónico).
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              height: 120,
              color: const Color(0xFF0E7C76),
              alignment: Alignment.center,
              child: const Padding(
                padding: EdgeInsets.only(top: 36.0),
                child: Text('¡Hola, Admin!', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  FutureBuilder<Map<String, int>>(
                    future: api.getStaffStats(),
                    builder: (context, snap) {
                      final stats = snap.data ?? {'total': 0, 'active': 0, 'inactive': 0};
                      return Column(children: [
                        _StatCard(label: 'Total de Personal Registrado', value: stats['total'].toString()),
                        const SizedBox(height: 12),
                        Row(children: [Expanded(child: _StatCard(label: 'Personal Activo', value: stats['active'].toString())), const SizedBox(width: 8), Expanded(child: _StatCard(label: 'Personal Inactivo', value: stats['inactive'].toString()))]),
                      ]);
                    },
                  ),
                  const SizedBox(height: 16),
                  _StatCard(label: 'Total de Jornadas Realizadas (Mes/Año)', value: j.totalJornadas.toString()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
