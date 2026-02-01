import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';
import 'package:ecovac/features/admin/providers/jornadas_provider.dart';
import 'package:ecovac/core/services/api_service.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final api = GetIt.instance<ApiService>();
    final j = context.watch<JornadasProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header section with profile
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF10B981), // Emerald Green más brillante
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  // Profile section
                  Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.person,
                          size: 30,
                          color: Color(0xFF10B981), // Emerald Green
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '¡Hola, Admin!',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Bienvenido de nuevo',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Statistics cards with real data
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  // FutureBuilder for staff and vaccines stats
                  FutureBuilder<Map<String, dynamic>>(
                    future: _getAllStats(api),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      
                      final stats = snapshot.data ?? {
                        'totalStaff': 0,
                        'activeStaff': 0,
                        'totalVacunas': 0,
                        'totalJornadas': 0,
                      };
                      
                      return Column(
                        children: [
                          // First row of stats
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  context,
                                  'Total de Personal',
                                  stats['totalStaff'].toString(),
                                  Icons.people,
                                  const Color(0xFF2196F3), // Azul
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildStatCard(
                                  context,
                                  'Vacunas Registradas',
                                  stats['totalVacunas'].toString(),
                                  Icons.vaccines,
                                  const Color(0xFF059669), // Green más oscuro
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Second row of stats
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  context,
                                  'Jornadas Activas',
                                  stats['totalJornadas'].toString(),
                                  Icons.event,
                                  const Color(0xFF047857), // Green más intenso
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildStatCard(
                                  context,
                                  'Personal Activo',
                                  stats['activeStaff'].toString(),
                                  Icons.verified_user,
                                  const Color(0xFFE53935), // Rojo
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 100), // Space for bottom nav
          ],
        ),
      ),
    );
  }

  // Method to get all statistics
  Future<Map<String, dynamic>> _getAllStats(ApiService api) async {
    try {
      // Get staff statistics
      final staffStats = await api.getStaffStats();
      
      // Get vaccines count
      final vacunas = await api.getVacunas();
      
      // Get jornadas count
      final jornadas = await api.getJornadas();
      
      return {
        'totalStaff': staffStats['total'] ?? 0,
        'activeStaff': staffStats['active'] ?? 0,
        'totalVacunas': vacunas.length,
        'totalJornadas': jornadas.length,
      };
    } catch (e) {
      print('Error getting stats: $e');
      return {
        'totalStaff': 0,
        'activeStaff': 0,
        'totalVacunas': 0,
        'totalJornadas': 0,
      };
    }
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
