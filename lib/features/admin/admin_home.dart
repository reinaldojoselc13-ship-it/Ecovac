import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:get_it/get_it.dart';
import 'package:ecovac/core/services/api_service.dart';
import 'package:ecovac/features/admin/providers/jornadas_provider.dart';
import 'package:ecovac/features/admin/providers/vacunas_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'pages/admin_dashboard_page.dart';
import 'pages/jornadas_list_page.dart';
import 'pages/profiles_page.dart';
import 'pages/vacuna_page.dart';
import 'pages/calendar_page.dart';

class AdminHome extends StatelessWidget {
  const AdminHome({super.key});

  @override
  Widget build(BuildContext context) {
    final api = GetIt.instance<ApiService>();
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => JornadasProvider(api)..loadCounts()),
      ],
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin'),
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
              navigator.pushReplacementNamed('/login');
            },
          ),
        ),
        body: const AdminDashboardPage(),
        bottomNavigationBar: _AdminBottomNav(api),
      ),
    );
  }
}

class _AdminBottomNav extends StatelessWidget {
  final ApiService api;
  const _AdminBottomNav(this.api);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
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
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProfilesPage(api))),
                    child: Column(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.account_box, color: Colors.white), SizedBox(height: 6), Text('Veterinario', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))]),
                  ),
                  GestureDetector(
                    onTap: () {
                      final vacProv = VacunasProvider(api);
                      vacProv.startRealtime();
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChangeNotifierProvider<VacunasProvider>.value(value: vacProv, child: VacunaPage(api))));
                    },
                    child: Column(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.medical_services, color: Colors.white), SizedBox(height: 6), Text('Vacuna', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))]),
                  ),
                  GestureDetector(
                    onTap: () {
                      final jprov = context.read<JornadasProvider>();
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChangeNotifierProvider<JornadasProvider>.value(value: jprov, child: const JornadasListPage())));
                    },
                    child: Column(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.event_note, color: Colors.white), SizedBox(height: 6), Text('Jornada', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))]),
                  ),
                  GestureDetector(
                    onTap: () {
                      final jprov = context.read<JornadasProvider>();
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChangeNotifierProvider<JornadasProvider>.value(value: jprov, child: const CalendarPage())));
                    },
                    child: Column(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.calendar_today, color: Colors.white), SizedBox(height: 6), Text('Calendario', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))]),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
