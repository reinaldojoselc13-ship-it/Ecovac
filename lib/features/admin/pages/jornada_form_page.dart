import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ecovac/features/admin/providers/jornadas_provider.dart';
import 'package:get_it/get_it.dart';
import 'package:ecovac/core/services/api_service.dart';
import 'package:ecovac/features/admin/providers/vacunas_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class JornadaFormPage extends StatefulWidget {
  final Map<String, dynamic>? initial;
  final bool readOnly;
  const JornadaFormPage({super.key, this.initial, this.readOnly = false});

  @override
  State<JornadaFormPage> createState() => _JornadaFormPageState();
}

class _JornadaFormPageState extends State<JornadaFormPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _name;
  late TextEditingController _date;
  late TextEditingController _location;
  late TextEditingController _description;

  DateTime? _selectedDate;
  List<Map<String, dynamic>> _vets = [];
  List<String> _selectedVetIds = [];
  List<Map<String, dynamic>> _vacunas = [];
  List<String> _selectedVacunaIds = [];

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initial?['nombre']?.toString() ?? '');
    _date = TextEditingController(text: widget.initial?['fecha']?.toString() ?? '');
    _location = TextEditingController(text: widget.initial?['ubicacion']?.toString() ?? '');
    _description = TextEditingController(text: widget.initial?['descripcion']?.toString() ?? '');
    if (widget.initial?['fecha'] != null) {
      try {
        _selectedDate = DateTime.parse(widget.initial!['fecha'].toString());
      } catch (_) {}
    }
    // Load staff and vacunas using ApiService (neutralizado)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final api = GetIt.instance<ApiService>();
        final vacunasProv = context.read<VacunasProvider>();
        final staffs = await api.getStaffProfiles();
        await vacunasProv.load();
        final vacunas = vacunasProv.items;
        if (!mounted) return;
        setState(() {
          _vets = staffs; // variable conservada por compatibilidad visual
          _vacunas = vacunas;
          // restore selections if editing
          if (widget.initial != null) {
            final assigned = widget.initial!['staff'] as List<dynamic>?;
            if (assigned != null) _selectedVetIds = assigned.map((e) => e.toString()).toList();
            final lotes = widget.initial!['vacunas'] as List<dynamic>?;
            if (lotes != null) _selectedVacunaIds = lotes.map((e) => e.toString()).toList();
          }
        });
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _date.dispose();
    _location.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (widget.readOnly) return;
    if (!_formKey.currentState!.validate()) return;
    if (_selectedVetIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seleccione al menos 1 personal asignado')));
      return;
    }
    if (_selectedVetIds.length > 5) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Máximo 5 miembros seleccionados')));
      return;
    }
    if (_selectedVacunaIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seleccione al menos 1 lote de vacuna')));
      return;
    }
    final prov = context.read<JornadasProvider>();
    final data = {
      'nombre': _name.text.trim(),
      'fecha': _selectedDate != null ? _selectedDate!.toIso8601String() : _date.text.trim(),
      'ubicacion': _location.text.trim(),
      'descripcion': _description.text.trim(),
      // Ensure staff contains UUIDs (ids) from staff table
      'staff': _selectedVetIds,
      'vacunas': _selectedVacunaIds,
      'estado': 'pendiente',
    };
    // Attach organizador_id as the authenticated user when available
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) data['organizador_id'] = user.id;
    } catch (_) {}
    if (widget.initial == null) {
      final ok = await prov.create(data);
      if (!ok) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error creando jornada. Revise permisos/registro del servidor.')));
        return;
      }
    } else {
      await prov.update(widget.initial!['id'].toString(), data);
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.readOnly ? 'Ver Jornada' : (widget.initial == null ? 'Registrar Jornada' : 'Editar Jornada')),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Nombre de la Jornada'), readOnly: widget.readOnly, validator: (v) => v == null || v.isEmpty ? 'Ingrese nombre' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _location, decoration: const InputDecoration(labelText: 'Ubicación'), readOnly: widget.readOnly, validator: (v) => v == null || v.isEmpty ? 'Ingrese ubicación' : null),
              const SizedBox(height: 12),
              // Date picker button
              InputDecorator(
                decoration: const InputDecoration(labelText: 'Fecha'),
                child: Row(children: [
                  Expanded(child: Text(_selectedDate != null ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}' : 'Seleccione fecha')),
                  IconButton(
                    onPressed: widget.readOnly
                        ? null
                        : () async {
                            final now = DateTime.now();
                            final picked = await showDatePicker(context: context, initialDate: _selectedDate ?? now, firstDate: DateTime(now.year - 2), lastDate: DateTime(now.year + 2));
                            if (picked != null) setState(() => _selectedDate = picked);
                          },
                    icon: const Icon(Icons.calendar_month),
                  )
                ]),
              ),
              const SizedBox(height: 12),
              TextFormField(controller: _description, decoration: const InputDecoration(labelText: 'Descripción de la Jornada'), readOnly: widget.readOnly, maxLines: 3),
              const SizedBox(height: 16),
              // Personal asignado selector (neutralizado)
              ExpansionTile(
                title: const Text('Personal Asignado'),
                subtitle: Text(_selectedVetIds.isEmpty ? 'Selecciona personal' : '${_selectedVetIds.length} seleccionados'),
                children: [
                  if (_vets.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('Cargando personal...')),
                  for (final v in _vets)
                    CheckboxListTile(
                      // preferir el UUID 'id' como valor
                      value: _selectedVetIds.contains(v['id']?.toString()),
                      title: Text('${v['nombres'] ?? ''} ${v['apellidos'] ?? ''}'),
                      subtitle: Text(v['telefono']?.toString() ?? ''),
                      onChanged: widget.readOnly
                          ? null
                          : (val) {
                              final String? idNullable = v['id']?.toString();
                              if (idNullable == null) return;
                              setState(() {
                                if (val == true) {
                                  if (_selectedVetIds.length < 5) _selectedVetIds.add(idNullable);
                                } else {
                                  _selectedVetIds.remove(idNullable);
                                }
                              });
                            },
                    ),
                ],
              ),
              const SizedBox(height: 12),
              // Vacunas selector
              ExpansionTile(
                title: const Text('Vacunas (Lote)'),
                subtitle: Text(_selectedVacunaIds.isEmpty ? 'Selecciona lotes de vacunas' : '${_selectedVacunaIds.length} seleccionados'),
                children: [
                  if (_vacunas.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('Cargando lotes...')),
                  for (final v in _vacunas)
                    CheckboxListTile(
                      // usar el id UUID del lote como valor
                      value: _selectedVacunaIds.contains(v['id']?.toString()),
                      title: Text(v['nombre']?.toString() ?? ''),
                      subtitle: Text(v['descripcion']?.toString() ?? ''),
                      onChanged: widget.readOnly
                          ? null
                          : (val) {
                              final String? idNullable = v['id']?.toString();
                              if (idNullable == null) return;
                              setState(() {
                                if (val == true) {
                                  if (_selectedVacunaIds.length < 5) _selectedVacunaIds.add(idNullable);
                                } else {
                                  _selectedVacunaIds.remove(idNullable);
                                }
                              });
                            },
                    ),
                ],
              ),
              const SizedBox(height: 18),
              if (!widget.readOnly)
                Center(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14)),
                    onPressed: _save,
                    child: const Text('REGISTRAR', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              const SizedBox(height: 18),
            ],
          ),
        ),
      ),
    );
  }
}
