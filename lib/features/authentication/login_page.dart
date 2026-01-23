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
          // Crear una fila mínima para este usuario (no dar admin por defecto)
          final up = {
              'id': user.id,
              'nombres': user.email ?? user.id,
              'telefono': null,
              'active': true,
              // Marcar admin si el usuario seleccionó Administrador
              'is_admin': _userType == 'Administrador' ? true : false,
              // Usar nombres de roles coherentes con la base: 'administrador'/'veterinario'
              'role': _userType == 'Administrador' ? 'administrador' : 'veterinario'
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

        // Determinar si el usuario es administrador
        final roleVal = (staffRow['role'] ?? '').toString().toLowerCase();
        final isAdmin = (staffRow['is_admin'] == true) || roleVal == 'admin' || roleVal == 'administrador';
        final wantsAdmin = _userType == 'Administrador';

        if (wantsAdmin && !isAdmin) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Acceso denegado: no tiene privilegios de administrador')));
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
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Top curved header
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: size.height * 0.33,
                  decoration: const BoxDecoration(
                    color: Color(0xFF0E7C76),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(40),
                      bottomRight: Radius.circular(40),
                    ),
                  ),
                ),
                Positioned(
                  top: 60,
                  child: Column(
                    children: const [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.pets, size: 40, color: Color(0xFF0E7C76)),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'ECOVAC',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 18,
                  child: Text(
                    'Inicio de Sesión',
                    style: const TextStyle(color: Color.fromRGBO(255,255,255,0.95), fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                )
              ],
            ),

            const SizedBox(height: 18),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Tipo de usuario dropdown (styled like image)
                    const Text('TIPO DE USUARIO', style: TextStyle(color: Colors.black54, fontSize: 12)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _userType,
                          items: const [
                            DropdownMenuItem(value: 'Veterinario', child: Text('Veterinario')),
                            DropdownMenuItem(value: 'Administrador', child: Text('Administrador')),
                          ],
                          onChanged: (v) => setState(() => _userType = v ?? 'Usuario'),
                          icon: const Icon(Icons.arrow_drop_down),
                          isExpanded: true,
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    const Text('USUARIO', style: TextStyle(color: Colors.black54, fontSize: 12)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _userController,
                      decoration: InputDecoration(
                        hintText: 'Email',
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      ),
                      validator: _validateUser,
                    ),

                    const SizedBox(height: 12),
                    const Text('CONTRASEÑA:', style: TextStyle(color: Colors.black54, fontSize: 12)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        hintText: '***************',
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      ),
                      validator: _validatePassword,
                    ),

                    const SizedBox(height: 18),

                    // Decorative row (neutral icons) — estilo académico: elementos UI decorativos.
                    SizedBox(
                      height: 100,
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            CircleAvatar(radius: 28, backgroundColor: Colors.white, child: Icon(Icons.person, size: 28)),
                            SizedBox(width: 8),
                            CircleAvatar(radius: 28, backgroundColor: Colors.white, child: Icon(Icons.work, size: 28)),
                            SizedBox(width: 8),
                            CircleAvatar(radius: 28, backgroundColor: Colors.white, child: Icon(Icons.group, size: 28)),
                            SizedBox(width: 8),
                            CircleAvatar(radius: 28, backgroundColor: Colors.white, child: Icon(Icons.business, size: 28)),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Ingresar button
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0E7C76),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _loading ? null : _signIn,
                        child: _loading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('INGRESAR', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
