import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ecovac/core/services/api_service.dart';
// Se removió la dependencia al provider específico. Este formulario usa ahora
// directamente `ApiService` para persistencia neutral.

class VetProfileFormPage extends StatefulWidget {
  final Map<String, dynamic>? initial;
  final ApiService api;
  final bool readOnly;
  const VetProfileFormPage({this.initial, required this.api, this.readOnly = false, super.key});

  @override
  State<VetProfileFormPage> createState() => _VetProfileFormPageState();
}

class _VetProfileFormPageState extends State<VetProfileFormPage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nombres;
  late TextEditingController _apellidos;
  late TextEditingController _cedula;
  late TextEditingController _telefono;
  late TextEditingController _direccion;
  late TextEditingController _numeroColegio;
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  late TextEditingController _newPasswordController;

  String _sector = 'Público';
  String? _avatarPath;
  String _selectedRole = 'Veterinario';

  @override
  void initState() {
    super.initState();
    _nombres = TextEditingController(text: widget.initial?['nombres']?.toString() ?? widget.initial?['nombre']?.toString() ?? '');
    _apellidos = TextEditingController(text: widget.initial?['apellidos']?.toString() ?? '');
    _cedula = TextEditingController(text: widget.initial?['cedula']?.toString() ?? '');
    _telefono = TextEditingController(text: widget.initial?['telefono']?.toString() ?? '');
    _direccion = TextEditingController(text: widget.initial?['direccion']?.toString() ?? '');
    _numeroColegio = TextEditingController(text: widget.initial?['numero_colegio']?.toString() ?? '');
    _sector = widget.initial?['sector']?.toString() ?? 'Público';
    _avatarPath = widget.initial?['avatar_path']?.toString();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _newPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _nombres.dispose();
    _apellidos.dispose();
    _cedula.dispose();
    _telefono.dispose();
    _direccion.dispose();
    _numeroColegio.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadAvatar() async {
    if (widget.readOnly) return;
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final name = 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final url = await widget.api.uploadAvatar(bytes, name);
    if (!mounted) return;
    setState(() => _avatarPath = url);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(url == null ? 'Error subiendo imagen' : 'Imagen subida')));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(color: Colors.grey.shade200, border: Border.all(color: Colors.black54)),
          padding: const EdgeInsets.all(12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.warning_amber_rounded, size: 56, color: Colors.amber),
            const SizedBox(height: 8),
            const Text('¿Está seguro que desea registrar este perfil?', textAlign: TextAlign.center, style: TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            const Text('Una vez registrado podrá acceder a funciones del sistema según su rol.'),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
              ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.green), onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Confirmar')),
            ])
          ]),
        ),
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    // Persistencia neutralizada: usamos la API centralizada en lugar del provider.
    final Map<String, dynamic> data = {
      'nombres': _nombres.text.trim(),
      'apellidos': _apellidos.text.trim(),
      'cedula': _cedula.text.trim(),
      'telefono': _telefono.text.trim(),
      'direccion': _direccion.text.trim(),
      'numero_colegio': _numeroColegio.text.trim(),
      'sector': _sector,
      'avatar_path': _avatarPath,
    };

    if (widget.readOnly) return;
    if (widget.initial == null) {
      // Nuevo perfil: requerimos email y password provistos por el admin.
      var email = _emailController.text.trim();
      final password = _passwordController.text;
      // Normalize email
      email = email.toLowerCase();
      // Basic validation before calling Auth
      if (!_isValidEmail(email)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Correo inválido. Ingrese un correo con formato válido (ej: correo@dominio.com)')));
        return;
      }
      String? uid;
      if (email.isNotEmpty && password.isNotEmpty) {
        // Crear usuario en Auth y obtener uid — enviar metadatos para trigger server-side
        try {
          final meta = {
            'nombres': _nombres.text.trim(),
            'apellidos': _apellidos.text.trim(),
            'cedula_identidad': _cedula.text.trim(),
            'cedula': _cedula.text.trim(),
            'email': email,
          };
          uid = await widget.api.signUpAuthUser(email, password, userMetadata: meta);
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error creando cuenta de autenticación: $e')));
          return;
        }
        // Asociar el uid a la fila staff para mantener referencia
        data['id'] = uid;
        data['email'] = email;
      }

      // Añadir flags/rol según selección del admin
      final roleValue = (_selectedRole == 'Administrador') ? 'administrador' : 'veterinario';
      data['role'] = roleValue;
      data['is_admin'] = (_selectedRole == 'Administrador') ? true : false;

      // Crear perfil en tabla 'staff'
      final created = await widget.api.createStaffProfile(data);
      if (created != null) {
        final id = created['id']?.toString() ?? (uid ?? '');
        if (id.isNotEmpty) {
          // Asignar rol en tabla 'perfil' y comprobar resultado
          try {
            final ok = await widget.api.assignRoleToStaff(id, roleValue);
            if (!ok) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Perfil creado, pero no fue posible asignar rol (ver permisos en DB).')));
            }
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error asignando rol en perfil: $e')));
            return;
          }
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error creando perfil. Revise permisos/registro del servidor.')));
        return;
      }
    } else {
      final id = widget.initial!['id']?.toString() ?? '';
      try {
        final updated = await widget.api.updateStaffProfile(id, data);
        if (updated == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error actualizando perfil (sin respuesta)')));
          return;
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error actualizando perfil: $e')));
        return;
      }
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initial == null ? 'Registrar Perfil' : 'Editar Perfil', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF9DBFC0),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 6),
                // Si es creación (initial == null) mostramos email/contraseña y selector de rol
                if (widget.initial == null) ...[
                  _label('Correo electrónico'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _emailController,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Ingrese correo';
                      if (!_isValidEmail(v.trim())) return 'Correo con formato inválido';
                      return null;
                    },
                    decoration: InputDecoration(
                      hintText: 'correo@dominio.com',
                      filled: true,
                      fillColor: Colors.grey.shade300,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _label('Contraseña'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    validator: (v) => (v == null || v.isEmpty) ? 'Ingrese contraseña' : null,
                    decoration: InputDecoration(
                      hintText: 'Contraseña',
                      filled: true,
                      fillColor: Colors.grey.shade300,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _label('Tipo de usuario'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedRole,
                        items: const [
                          DropdownMenuItem(value: 'Veterinario', child: Text('Veterinario')),
                          DropdownMenuItem(value: 'Administrador', child: Text('Administrador')),
                        ],
                        onChanged: (v) => setState(() => _selectedRole = v ?? 'Veterinario'),
                        isExpanded: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                _label('Nombres'),
                const SizedBox(height: 8),
                _roundedField(_nombres, hint: 'Nombres'),
                const SizedBox(height: 12),
                _label('Apellidos'),
                const SizedBox(height: 8),
                _roundedField(_apellidos, hint: 'Apellidos'),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _label('Cédula'),
                    const SizedBox(height: 8),
                    _roundedField(_cedula, hint: 'Cédula'),
                  ])),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _label('Teléfono'),
                    const SizedBox(height: 8),
                    _roundedField(_telefono, hint: 'Teléfono'),
                  ])),
                ]),
                const SizedBox(height: 12),
                _label('Dirección'),
                const SizedBox(height: 8),
                _roundedField(_direccion, hint: 'Dirección'),
                const SizedBox(height: 12),
                _label('Identificador profesional'),
                const SizedBox(height: 8),
                _roundedField(_numeroColegio, hint: 'Número de colegio'),
                const SizedBox(height: 12),
                _label('Sector'),
                const SizedBox(height: 8),
                Row(children: [
                  _sectorRadio('Público'),
                  const SizedBox(width: 12),
                  _sectorRadio('Privado'),
                ]),
                const SizedBox(height: 16),
                _label('Foto de perfil'),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: widget.readOnly ? null : _pickAndUploadAvatar,
                  child: Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black26, style: BorderStyle.solid),
                    ),
                    child: Center(
                      child: _avatarPath == null || _avatarPath!.isEmpty
                          ? Column(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.cloud_upload_outlined, size: 36), SizedBox(height: 6), Text('Subir o seleccionar imagen')])
                          : Column(mainAxisSize: MainAxisSize.min, children: [Image.network(_avatarPath!, height: 64), const SizedBox(height: 8), const Text('Imagen seleccionada')]),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Sección para cambiar contraseña cuando se edita un perfil existente
                if (widget.initial != null) ...[
                  _label('Cambiar contraseña (Admin)'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _newPasswordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: 'Nueva contraseña (opcional)'
                    ,filled: true,fillColor: Colors.grey.shade300,border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),),
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final id = widget.initial!['id']?.toString() ?? '';
                          final pwd = _newPasswordController.text;
                          if (id.isEmpty) {
                            messenger.showSnackBar(const SnackBar(content: Text('ID de usuario no disponible')));
                            return;
                          }
                          if (pwd.isEmpty) {
                            messenger.showSnackBar(const SnackBar(content: Text('Ingrese la nueva contraseña')));
                            return;
                          }
                          final ok = await widget.api.adminUpdateUserPassword(id, pwd);
                          if (ok) {
                            if (!mounted) return;
                            messenger.showSnackBar(const SnackBar(content: Text('Contraseña actualizada correctamente')));
                            _newPasswordController.clear();
                          } else {
                            if (!mounted) return;
                            // Fallback: intentar enviar email de restablecimiento si no fue posible cambiar directamente
                            final email = widget.initial!['email']?.toString() ?? '';
                            if (email.isEmpty) {
                              messenger.showSnackBar(const SnackBar(content: Text('No fue posible cambiar la contraseña y el correo no está disponible')));
                              return;
                            }
                            final sent = await widget.api.sendResetPasswordEmail(email);
                            if (!mounted) return;
                            messenger.showSnackBar(SnackBar(content: Text(sent ? 'No fue posible cambiar directamente; se envió correo de restablecimiento' : 'No fue posible cambiar ni enviar correo')));
                          }
                        },
                        child: const Text('Aplicar contraseña'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final email = widget.initial!['email']?.toString() ?? '';
                          if (email.isEmpty) {
                            messenger.showSnackBar(const SnackBar(content: Text('Correo no disponible')));
                            return;
                          }
                          final sent = await widget.api.sendResetPasswordEmail(email);
                          if (!mounted) return;
                          messenger.showSnackBar(SnackBar(content: Text(sent ? 'Correo de restablecimiento enviado' : 'Error enviando correo')));
                        },
                        child: const Text('Enviar email de restablecimiento'),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                ],
                if (!widget.readOnly)
                  Center(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0E7C76), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14)),
                      onPressed: _save,
                      child: const Text('REGISTRAR', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                const SizedBox(height: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _isValidEmail(String email) {
    final re = RegExp(r"^[\w\.-]+@[\w\.-]+\.[a-zA-Z]{2,}");
    return re.hasMatch(email);
  }

  Widget _label(String text) => Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54));

  Widget _roundedField(TextEditingController controller, {String hint = ''}) {
    return TextFormField(
      controller: controller,
      validator: (v) => (controller == _nombres || controller == _cedula) ? (v == null || v.isEmpty ? 'Ingrese valor' : null) : null,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.grey.shade300,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _sectorRadio(String value) {
    final selected = _sector == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _sector = value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: selected ? Colors.green.shade50 : Colors.transparent, border: Border.all(color: selected ? Colors.green : Colors.black26)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: selected ? Colors.green : Colors.black45),
            const SizedBox(width: 6),
            Text(value),
          ]),
        ),
      ),
    );
  }
}
