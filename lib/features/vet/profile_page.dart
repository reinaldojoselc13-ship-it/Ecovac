import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ecovac/core/services/api_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final ApiService api;
  bool _loading = true;
  Map<String, dynamic>? _profile;

  late TextEditingController _nombres;
  late TextEditingController _apellidos;
  late TextEditingController _telefono;
  late TextEditingController _direccion;

  @override
  void initState() {
    super.initState();
    api = GetIt.instance.isRegistered<ApiService>() ? GetIt.instance<ApiService>() : ApiService();
    _nombres = TextEditingController();
    _apellidos = TextEditingController();
    _telefono = TextEditingController();
    _direccion = TextEditingController();
    _loadProfile();
  }

  @override
  void dispose() {
    _nombres.dispose();
    _apellidos.dispose();
    _telefono.dispose();
    _direccion.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      final row = await api.getStaffById(user.id);
      if (row != null) {
        _profile = row;
        _nombres.text = (row['nombres'] ?? row['nombre'] ?? '').toString();
        _apellidos.text = (row['apellidos'] ?? '').toString();
        _telefono.text = (row['telefono'] ?? '').toString();
        _direccion.text = (row['direccion'] ?? '').toString();
      }
    } catch (e) {
      // ignore
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Perfil no cargado')));
      return;
    }
    setState(() => _loading = true);
    final data = {
      'nombres': _nombres.text.trim(),
      'apellidos': _apellidos.text.trim(),
      'telefono': _telefono.text.trim(),
      'direccion': _direccion.text.trim(),
    };
    try {
      final id = _profile!['id']?.toString() ?? '';
      if (id.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ID de perfil no disponible')));
        return;
      }
      final updated = await api.updateStaffProfile(id, data);
      if (updated == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error actualizando perfil')));
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Perfil actualizado')));
        await _loadProfile();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi Perfil')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(controller: _nombres, decoration: const InputDecoration(labelText: 'Nombres'), validator: (v) => v == null || v.isEmpty ? 'Ingrese nombres' : null),
                      const SizedBox(height: 12),
                      TextFormField(controller: _apellidos, decoration: const InputDecoration(labelText: 'Apellidos')),
                      const SizedBox(height: 12),
                      TextFormField(controller: _telefono, decoration: const InputDecoration(labelText: 'Teléfono')),
                      const SizedBox(height: 12),
                      TextFormField(controller: _direccion, decoration: const InputDecoration(labelText: 'Dirección')),
                      const SizedBox(height: 20),
                      ElevatedButton(onPressed: _loading ? null : _save, child: const Text('Guardar')),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
