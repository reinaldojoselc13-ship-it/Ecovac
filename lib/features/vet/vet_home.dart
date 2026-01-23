import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';
import 'package:ecovac/core/services/api_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ecovac/features/admin/providers/jornadas_provider.dart';
import 'package:ecovac/features/admin/providers/vacunas_provider.dart';
import 'package:ecovac/features/admin/providers/vet_profiles_provider.dart';
import 'package:ecovac/features/admin/pages/jornadas_list_page.dart';
import 'package:ecovac/features/admin/pages/vacuna_page.dart';
import 'package:ecovac/features/admin/pages/vet_profiles_page.dart';
import 'package:ecovac/features/admin/pages/calendar_page.dart';
import 'package:ecovac/features/vet/profile_page.dart';

/// Página principal para Veterinarios (vista en modo solo-lectura).
///
/// El `Veterinario` puede ver Jornadas, Lotes, Perfiles y Calendario,
/// pero no puede modificar nada: las acciones de edición están ocultas.
class VetHome extends StatefulWidget {
  const VetHome({super.key});

  @override
  State<VetHome> createState() => _VetHomeState();
}

class _VetHomeState extends State<VetHome> {
  late final ApiService api;
  late final JornadasProvider jornadasProv;
  late final VacunasProvider vacunasProv;
  late final VetProfilesProvider profilesProv;

  @override
  void initState() {
    super.initState();
    api = GetIt.instance.isRegistered<ApiService>() ? GetIt.instance<ApiService>() : ApiService();
    jornadasProv = JornadasProvider(api)..loadCounts()..startAutoRefresh();
    vacunasProv = VacunasProvider(api)..load()..startAutoRefresh();
    profilesProv = VetProfilesProvider(api)..loadCounts()..startAutoRefresh();
    _loadMyProfile();
  }

  @override
  void dispose() {
    jornadasProv.dispose();
    vacunasProv.dispose();
    profilesProv.dispose();
    super.dispose();
  }

  Future<void> _loadMyProfile() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      final row = await api.getStaffById(user.id);
      if (row != null) {
        final n = (row['nombres'] ?? row['nombre'] ?? '').toString();
        final a = (row['apellidos'] ?? '').toString();
        final display = n.isNotEmpty ? 'Dr. $n${a.isNotEmpty ? ' $a' : ''}' : (user.email ?? '');
        setState(() => _greetingName = display);
      } else {
        setState(() => _greetingName = user.email ?? '');
      }
    } catch (_) {
      // ignore
    }
  }

  String _greetingName = '';

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<JornadasProvider>.value(value: jornadasProv),
        ChangeNotifierProvider<VacunasProvider>.value(value: vacunasProv),
        ChangeNotifierProvider<VetProfilesProvider>.value(value: profilesProv),
      ],
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Veterinario'),
          leading: IconButton(
            icon: const Icon(Icons.exit_to_app),
            tooltip: 'Cerrar sesión',
            onPressed: () async {
              final navigator = Navigator.of(context);
              try {
                await Supabase.instance.client.auth.signOut();
              } catch (e) {
                // ignore: avoid_print
                print('Error signing out: $e');
              }
              // usar el Navigator capturado evita usar BuildContext tras un await
              navigator.pushReplacementNamed('/login');
            },
          ),
          actions: [
            IconButton(
              tooltip: 'Mi Perfil',
              icon: const Icon(Icons.person),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfilePage())),
            ),
          ],
        ),
        body: Consumer<JornadasProvider>(
          builder: (context, jProv, _) {
            final total = jProv.totalJornadas;
            final items = jProv.items;
            int completed = 0;
            int inProcess = 0;
            int today = 0;
            final now = DateTime.now();
            for (final it in items) {
              final estado = (it['estado'] ?? '').toString().toLowerCase();
              if (estado == 'culminada' || estado == 'finalizada' || estado == 'completada') {
                completed++;
              } else {
                inProcess++;
              }
              try {
                final fechaRaw = it['fecha'];
                if (fechaRaw != null) {
                  final fecha = DateTime.parse(fechaRaw.toString()).toLocal();
                  if (fecha.year == now.year && fecha.month == now.month && fecha.day == now.day) today++;
                }
              } catch (_) {}
            }

            final double ratio = total > 0 ? (inProcess / total) : 0.0;

            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Align(alignment: Alignment.topLeft, child: Text(_greetingName.isNotEmpty ? '¡Hola, $_greetingName!' : '¡Hola!', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple),)),
                    const SizedBox(height: 18),
                    Text('Jornadas Registrada', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),),
                    const SizedBox(height: 6),
                    Text('$total', style: Theme.of(context).textTheme.displayLarge?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 18),
                    // Donut indicator
                    SizedBox(
                      width: 220,
                      height: 220,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 220,
                            height: 220,
                            child: CircularProgressIndicator(
                              value: 1.0,
                              strokeWidth: 28,
                              color: Colors.grey.shade300,
                            ),
                          ),
                          SizedBox(
                            width: 220,
                            height: 220,
                            child: CircularProgressIndicator(
                              value: ratio,
                              strokeWidth: 28,
                              color: Colors.deepPurple,
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('$inProcess', style: const TextStyle(color: Colors.deepPurple, fontSize: 28, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              const Text('En Proceso', style: TextStyle(color: Colors.deepPurple)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(alignment: Alignment.centerLeft, child: Text('$completed Culminadas', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))),
                    const SizedBox(height: 28),
                    const Text('Jornadas para hoy', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                    const SizedBox(height: 6),
                    Text('$today', style: const TextStyle(fontSize: 18, color: Colors.green, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 36),
                  ],
                ),
              ),
            );
          },
        ),
        bottomNavigationBar: SizedBox(
          height: 90,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Material(
                elevation: 10,
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF007C78), Color(0xFF09A656)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.all(Radius.circular(24)),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => VetProfilesPage(api, canEdit: false))),
                        child: Column(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.account_box, color: Colors.white), SizedBox(height: 6), Text('Veterinario', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))]),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChangeNotifierProvider<VacunasProvider>.value(value: vacunasProv, child: VacunaPage(api, canAdd: false)))),
                        child: Column(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.medical_services, color: Colors.white), SizedBox(height: 6), Text('Vacuna', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))]),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChangeNotifierProvider<JornadasProvider>.value(value: jornadasProv, child: const JornadasListPage(canEdit: false)))),
                        child: Column(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.event_note, color: Colors.white), SizedBox(height: 6), Text('Jornada', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))]),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChangeNotifierProvider<JornadasProvider>.value(value: jornadasProv, child: const CalendarPage()))),
                        child: Column(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.calendar_today, color: Colors.white), SizedBox(height: 6), Text('Calendario', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))]),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
