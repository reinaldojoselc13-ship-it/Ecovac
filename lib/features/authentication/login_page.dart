import 'package:flutter/material.dart';
import 'package:ecovac/core/services/auth_service.dart' as auth_service;
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginPage extends StatefulWidget {
  final String initialUserType;
  const LoginPage({super.key, this.initialUserType = 'Veterinario'});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  late String _userType;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _userType = widget.initialUserType;
  }

  @override
  void dispose() {
    _userController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateUser(String? v) => auth_service.AuthService.validateUser(v);

  String? _validatePassword(String? v) => auth_service.AuthService.validatePassword(v);

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    final userText = _userController.text.trim();
    final password = _passwordController.text;

    try {
      if (userText.contains('@')) {
        // Intentar iniciar sesión directamente con Supabase
        try {
          final res = await Supabase.instance.client.auth.signInWithPassword(email: userText, password: password);
          final user = res.user ?? Supabase.instance.client.auth.currentUser;
          if (user == null) {
            final debugMsg = 'Auth failed. response: $res, currentUser: ${Supabase.instance.client.auth.currentUser}';
            debugPrint(debugMsg);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('DEBUG AUTH: ${res.toString()}')));
            return;
          }

          // Después del inicio de sesión, verificamos en la tabla `staff`
          // si el usuario existe y qué rol tiene. Si no existe, creamos
          // una fila mínima. Esto evita que la app permita accesos no
          // autorizados simplemente por seleccionar el tipo en la UI.
          
          if (!mounted) return;
        } on auth_service.AuthException catch (e) {
          debugPrint('AuthException: ${e.message}');
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('DEBUG AUTH EX: ${e.message}')));
          return;
        } catch (e, st) {
          debugPrint('Auth error: $e');
          debugPrintStack(stackTrace: st);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('DEBUG AUTH ERROR: ${e.toString()}')));
          return;
        }

        final user = Supabase.instance.client.auth.currentUser;
        if (user == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: usuario no encontrado tras autenticación')));
          return;
        }

        final client = Supabase.instance.client;
        // Intentar leer la fila staff
        Map<String, dynamic>? staffRow;
        try {
          final sel = await client.from('staff').select().eq('id', user.id).limit(1).maybeSingle();
          if (sel != null) {
            staffRow = Map<String, dynamic>.from(sel as Map);
          }
        } catch (_) {
          // Ignorar: intentaremos crear la fila si no existe
        }

        if (staffRow == null) {
          // Crear una fila mínima para este usuario (siempre como veterinario por defecto)
          final up = {
              'id': user.id,
              'nombres': user.userMetadata?['nombres'] ?? user.email?.split('@')[0] ?? 'Usuario',
              'apellidos': user.userMetadata?['apellidos'] ?? '',
              'email': user.email,
              'telefono': user.userMetadata?['telefono'],
              'active': true,
              // Por defecto no es administrador, el rol debe ser asignado manualmente
              'is_admin': false,
              'role': 'veterinario'
            };
          try {
            final ins = await client.from('staff').upsert(up).select().maybeSingle();
            if (ins != null) {
              staffRow = Map<String, dynamic>.from(ins as Map);
            } else {
              // if database didn't return the row, fallback to our local map
              staffRow = Map<String, dynamic>.from(up);
            }
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error guardando perfil: ${e.toString()}')));
            return;
          }
        }

        // Determinar el rol real del usuario desde la base de datos
        final roleVal = (staffRow['role'] ?? '').toString().toLowerCase();
        final isAdmin = (staffRow['is_admin'] == true) || roleVal == 'admin' || roleVal == 'administrador';
        final wantsAdmin = _userType == 'Administrador';
        
        // Validar que el rol seleccionado coincida con el rol real del usuario
        if (wantsAdmin && !isAdmin) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Acceso denegado: su perfil no es de administrador. Seleccione "Veterinario".'),
            backgroundColor: Colors.red,
          ));
          await Supabase.instance.client.auth.signOut();
          return;
        }
        
        if (!wantsAdmin && isAdmin) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Acceso denegado: su perfil es de administrador. Seleccione "Administrador".'),
            backgroundColor: Colors.red,
          ));
          await Supabase.instance.client.auth.signOut();
          return;
        }

        // Redirigir según rol y selección
        _navigateToRoleHome();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingrese un email válido o implemente login por username')));
      }
    } on auth_service.AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.message}')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _navigateToRoleHome() {
    if (_userType == 'Administrador') {
      Navigator.of(context).pushReplacementNamed('/admin');
    } else {
      // Veterinario debe ir a su home específico
      Navigator.of(context).pushReplacementNamed('/vet');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              children: [
                const SizedBox(height: 60),
                
                // Logo
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.pets,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Title
                const Text(
                  'ECOVAC',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF10B981),
                  ),
                ),
                
                const SizedBox(height: 8),
                
                const Text(
                  'Sistema de Gestión de Vacunación',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                
                const SizedBox(height: 60),
                  
                  // Form
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Email field
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: TextFormField(
                            controller: _userController,
                            decoration: const InputDecoration(
                              labelText: 'Correo Electrónico',
                              hintText: 'ejemplo@correo.com',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                              prefixIcon: Icon(Icons.email, color: Color(0xFF10B981)),
                              labelStyle: TextStyle(color: Color(0xFF10B981)),
                              hintStyle: TextStyle(color: Colors.grey),
                            ),
                            validator: _validateUser,
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Password field
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Contraseña',
                              hintText: '••••••••',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                              prefixIcon: Icon(Icons.lock, color: Color(0xFF10B981)),
                              labelStyle: TextStyle(color: Color(0xFF10B981)),
                              hintStyle: TextStyle(color: Colors.grey),
                            ),
                            validator: _validatePassword,
                          ),
                        ),
                        
                        const SizedBox(height: 30),
                        
                        // Role selection
                        const Text(
                          'Tipo de Usuario',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        
                        const SizedBox(height: 12),
                        
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _userType = 'Veterinario'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  decoration: BoxDecoration(
                                    color: _userType == 'Veterinario' 
                                        ? const Color(0xFF10B981) 
                                        : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _userType == 'Veterinario' 
                                          ? const Color(0xFF10B981) 
                                          : Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.person,
                                        color: _userType == 'Veterinario' 
                                            ? Colors.white 
                                            : Colors.grey.shade600,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Veterinario',
                                        style: TextStyle(
                                          color: _userType == 'Veterinario' 
                                              ? Colors.white 
                                              : Colors.grey.shade600,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _userType = 'Administrador'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  decoration: BoxDecoration(
                                    color: _userType == 'Administrador' 
                                        ? const Color(0xFF10B981) 
                                        : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _userType == 'Administrador' 
                                          ? const Color(0xFF10B981) 
                                          : Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.admin_panel_settings,
                                        color: _userType == 'Administrador' 
                                            ? Colors.white 
                                            : Colors.grey.shade600,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Administrador',
                                        style: TextStyle(
                                          color: _userType == 'Administrador' 
                                              ? Colors.white 
                                              : Colors.grey.shade600,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 40),
                        
                        // Login button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            onPressed: _loading ? null : _signIn,
                            child: _loading
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 3,
                                  )
                                : const Text(
                                    'Iniciar Sesión',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 60),
                  
                  // Footer
                  Column(
                    children: [
                      const Text(
                        'Versión 1.0.0',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '© 2024 ECOVAC. Todos los derechos reservados.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
    );
  }
}
