// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/services/api_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/lock_service.dart';

// --- IMPORTACIONES DE LA ARQUITECTURA ---
// Comentarios reescritos en estilo académico: explico motivos de diseño brevemente.
// Se mantiene la separación por capas (Core, Servicios, Presentación). No usamos
// librerías de LLM ni lógica de veterinaria en esta versión.
import 'features/authentication/login_page.dart';
import 'features/authentication/user_type_page.dart';
import 'features/admin/admin_home.dart';
import 'features/vet/vet_home.dart';


// Instancia global para Service Locator
final GetIt sl = GetIt.instance; // sl = Service Locator

// --- FUNCIÓN PRINCIPAL DE SETUP DE DEPENDENCIAS ---
// Prefer keys passed with --dart-define, fallback to .env file.
const _supabaseUrlDefine = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
const _supabaseAnonKeyDefine = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

// Inicializa las dependencias de la aplicación.
// Explicación simple: aquí registramos servicios que la app usará,
// como el cliente de Supabase y el `ApiService`. Si no hay claves
// de Supabase, registramos un `ApiService` de respaldo que no falla,
// de forma que la interfaz todavía pueda abrirse en modo demo.
Future<void> initDependencies() async {
  // === 1. CORE Y UTILIDADES ===
  // No se registra Connectivity ni NetworkInfo (operación sólo online)

  // === 2. INICIALIZACIÓN DE BACKEND Y DB LOCAL ===
  
  // 2.1 Supabase: prefer --dart-define values, else use dotenv
  String? supabaseUrl;
  String? supabaseAnonKey;
  if (_supabaseUrlDefine.isNotEmpty) {
    supabaseUrl = _supabaseUrlDefine;
  } else {
    try {
      supabaseUrl = dotenv.env['SUPABASE_URL'];
    } catch (_) {
      supabaseUrl = null;
    }
  }

  if (_supabaseAnonKeyDefine.isNotEmpty) {
    supabaseAnonKey = _supabaseAnonKeyDefine;
  } else {
    try {
      supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];
    } catch (_) {
      supabaseAnonKey = null;
    }
  }

  if (supabaseUrl == null || supabaseAnonKey == null || supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    // Si no hay credenciales de Supabase, usamos un servicio de API vacío.
    // Esto permite ejecutar la app localmente sin depender de la nube.
    if (!sl.isRegistered<ApiService>()) sl.registerLazySingleton<ApiService>(() => ApiService());
  } else {
    // Debug: mostrar valores usados para inicializar Supabase (anon key parcialmente oculto)
    // Esto ayuda a detectar problemas de --dart-define o .env mal formateado.
    try {
      final maskedKey = supabaseAnonKey.length > 8 ? '${supabaseAnonKey.substring(0, 4)}...${supabaseAnonKey.substring(supabaseAnonKey.length - 4)}' : supabaseAnonKey;
      // ignore: avoid_print
      print('Initializing Supabase with URL: $supabaseUrl ANON_KEY: $maskedKey');
    } catch (_) {}
    // Aquí se establece la conexión con Supabase.
    // Comentario simple: Supabase es la base de datos y autenticación remota;
    // `Supabase.initialize` crea el cliente que usaremos para leer/escribir datos.
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
    // ignore: avoid_print
    print('Supabase.initialize completed. client: ${Supabase.instance.client}');
    // Registramos el cliente en el Service Locator para usarlo desde otros servicios.
    sl.registerLazySingleton<SupabaseClient>(() => Supabase.instance.client);
    // Registramos el ApiService que depende del cliente de Supabase.
    if (!sl.isRegistered<ApiService>()) sl.registerLazySingleton<ApiService>(() => ApiService(sl<SupabaseClient>()));
  }

  // No se inicializa Isar (modo offline eliminado)

  // === 3. INYECCIÓN DE CAPA DE DATOS (IMPLEMENTACIONES) ===
  // En esta purga hemos eliminado modelos y repositorios específicos de veterinaria.
  // Si la app requiere persistencia adicional se pueden registrar aquí adaptadores
  // que implementen contratos genéricos; por ahora dejamos la capa de datos vacía.
}

// Punto de entrada de la aplicación.
// Explicación simple: aquí cargamos variables de entorno y configuramos
// los servicios antes de mostrar la interfaz. Si algo falla en la carga
// de configuración, no detenemos la app para que el usuario vea la pantalla.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Intentar cargar variables de entorno desde el archivo .env (no comitear secrets)
  try {
    await dotenv.load(fileName: '.env');
    // ignore: avoid_print
    print('.env loaded');
  } catch (e, st) {
    // Si no existe .env o falla la carga no detenemos la app; registramos el error
    // ignore: avoid_print
    print('Warning: could not load .env — continuing without it.\n$e\n$st');
  }

  // Inicializar dependencias, pero no dejar que errores de init bloqueen la UI.
  try {
    await initDependencies(); // Ejecuta el setup
    // Inicializar servicio de notificaciones locales (no bloqueante)
    try {
      await NotificationService().init();
      // No forzamos la petición de permisos aquí para evitar diálogos inesperados,
      // pero podemos solicitar una vez al inicio para que las notificaciones aparezcan en pantalla
      await NotificationService().requestPermissions();
    } catch (e) {
      // ignore: avoid_print
      print('Warning: Notification service failed to initialize: $e');
    }
  } catch (e, st) {
    // Loggear y continuar; la app podrá mostrar la UI y fallar de forma localizada
    // ignore: avoid_print
    print('Error initializing dependencies: $e\n$st');
  }

  // Debug: prueba de conexión a Supabase (solo en modo debug)
  if (kDebugMode) {
    try {
    final SupabaseClient client = sl.isRegistered<SupabaseClient>() ? sl<SupabaseClient>() : Supabase.instance.client;
    // Ejecuta una consulta simple a la tabla 'staff' para verificar conectividad y permisos.
    // Notar: cualquier excepción se captura en el `catch` exterior.
    final res = await client.from('staff').select();
    // ignore: avoid_print
    print('DEBUG: Supabase test result: $res');
    } catch (e) {
      // ignore: avoid_print
      print('DEBUG: Supabase test exception: $e');
    }
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Construye la app principal y define las rutas.
    // Comentario simple: `routes` indica qué pantalla mostrar para cada ruta.
    // La ruta inicial muestra la página de selección de tipo de usuario.
    // Además, envolvemos la app en `LockWrapper` para pedir autenticación
    // cuando la app vuelve del fondo.
    return MaterialApp(
      title: 'Ecovac App',
      theme: ThemeData(primarySwatch: Colors.teal),
      // Colocamos `LockWrapper` dentro de `builder` para que la superposición
      // tenga acceso a la `Directionality` y al `Theme` proporcionados por
      // `MaterialApp`. Esto evita errores en tiempo de ejecución relacionados
      // con widgets de texto sin un ancestro Directionality.
      builder: (context, child) => LockWrapper(child: child ?? const SizedBox()),
      routes: {
        '/': (_) => const UserTypePage(),
        '/login': (_) => const LoginPage(),
        '/admin': (_) => const AdminHome(),
        '/vet': (_) => const VetHome(),
      },
      initialRoute: '/',
    );
  }
}

class LockWrapper extends StatefulWidget {
  final Widget child;
  const LockWrapper({super.key, required this.child});

  @override
  State<LockWrapper> createState() => _LockWrapperState();
}

class _LockWrapperState extends State<LockWrapper> with WidgetsBindingObserver {
  bool _backgrounded = false;
  bool _locked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _backgrounded = true;
    }
    if (state == AppLifecycleState.resumed && _backgrounded) {
      _backgrounded = false;
      // Intento de autenticación al volver del fondo.
      // Explicación simple: si el dispositivo soporta autenticación biométrica
      // (huella o cara), pedimos al usuario que se autentique antes de continuar.
      final locker = LockService();
      final can = await locker.canAuthenticate();
      if (can) {
        setState(() => _locked = true);
        final ok = await locker.authenticate();
        if (mounted) setState(() => _locked = !ok);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Si `_locked` es true, mostramos una capa encima de la app que obliga a
    // la autenticación. Al autenticarse, desactivamos la capa.
    return Stack(children: [widget.child, if (_locked) _LockOverlay(onAuthenticated: () => setState(() => _locked = false))]);
  }
}

class _LockOverlay extends StatelessWidget {
  final VoidCallback onAuthenticated;
  const _LockOverlay({required this.onAuthenticated});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        color: Color.fromRGBO(0, 0, 0, 0.6),
        child: Center(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
            icon: const Icon(Icons.fingerprint),
            // Botón que inicia la autenticación.
            // Explicación simple: al pulsar pedimos la biometría y si es válida
            // llamamos a `onAuthenticated` para quitar la capa de bloqueo.
            label: const Text('Autenticar para continuar'),
            onPressed: () async {
              final ok = await LockService().authenticate();
              if (ok) onAuthenticated();
            },
          ),
        ),
      ),
    );
  }
}
