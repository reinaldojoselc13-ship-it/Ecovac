import 'package:flutter/material.dart';
import 'package:ecovac/core/services/api_service.dart';
import 'package:provider/provider.dart';
import 'package:ecovac/features/admin/providers/vacunas_provider.dart';
// no DI import required; ApiService is injected via constructor

class VacunaFormPage extends StatefulWidget {
  final Map<String, dynamic>? initial;
  final ApiService api;
  final bool readOnly;
  const VacunaFormPage({this.initial, required this.api, this.readOnly = false, super.key});

  @override
  State<VacunaFormPage> createState() => _VacunaFormPageState();
}

class _VacunaFormPageState extends State<VacunaFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _lab = TextEditingController();
  final _codigo = TextEditingController();
  final _cantidad = TextEditingController();
  final _fechaIngreso = TextEditingController();
  final _fechaVenc = TextEditingController();
  final _lote = TextEditingController();
  final _factura = TextEditingController();
  final _proveedor = TextEditingController();
  final _dosisPorFrasco = TextEditingController();
  final _cantidadFrascos = TextEditingController();
  String _presentacion = 'Monodosis';

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      _name.text = widget.initial!['nombre']?.toString() ?? '';
      _codigo.text = widget.initial!['lote']?.toString() ?? widget.initial!['n_lote']?.toString() ?? '';
      _cantidad.text = widget.initial!['cantidad']?.toString() ?? '';
      _lab.text = widget.initial!['laboratorio']?.toString() ?? '';
      _fechaIngreso.text = widget.initial!['fecha_ingreso']?.toString() ?? '';
      _fechaVenc.text = widget.initial!['fecha_vencimiento']?.toString() ?? '';
      _lote.text = widget.initial!['n_lote']?.toString() ?? '';
      _factura.text = widget.initial!['n_factura']?.toString() ?? '';
      _proveedor.text = widget.initial!['proveedor']?.toString() ?? '';
      _dosisPorFrasco.text = widget.initial!['dosis_por_frasco']?.toString() ?? '';
      _cantidadFrascos.text = widget.initial!['cantidad_frascos']?.toString() ?? '';
      _presentacion = widget.initial!['presentacion']?.toString() ?? _presentacion;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _lab.dispose();
    _codigo.dispose();
    _cantidad.dispose();
    _fechaIngreso.dispose();
    _fechaVenc.dispose();
    _lote.dispose();
    _factura.dispose();
    _proveedor.dispose();
    _dosisPorFrasco.dispose();
    _cantidadFrascos.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    // capture provider synchronously before any await to avoid using
    // BuildContext after async gaps
    VacunasProvider? vprov;
    try {
      vprov = Provider.of<VacunasProvider>(context, listen: false);
    } catch (_) {
      vprov = null;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar registro'),
        content: const Text('¿Desea registrar este lote de vacuna?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Confirmar')),
        ],
      ),
    );
    if (confirmed != true) return;

    final api = widget.api;
    final data = {
      'nombre': _name.text.trim(),
      // map Código -> lote
      'lote': _codigo.text.trim().isNotEmpty ? _codigo.text.trim() : _lote.text.trim(),
      // cantidad as integer (total units)
      'cantidad': int.tryParse(_cantidad.text.trim()) ?? int.tryParse(_cantidadFrascos.text.trim()) ?? 0,
      'laboratorio': _lab.text.trim(),
      'fecha_ingreso': _fechaIngreso.text.trim(),
      'fecha_vencimiento': _fechaVenc.text.trim(),
      'n_lote': _lote.text.trim(),
      'n_factura': _factura.text.trim(),
      'proveedor': _proveedor.text.trim(),
      'presentacion': _presentacion,
      'dosis_por_frasco': _dosisPorFrasco.text.trim(),
      'cantidad_frascos': _cantidadFrascos.text.trim(),
    };

    String? rawErr;
    try {
      if (widget.initial == null) {
        final created = await api.createVacuna(data);
        if (created == null) rawErr = 'Creación retornó nulo';
      } else {
        final updated = await api.updateVacuna(widget.initial!['id'].toString(), data);
        if (updated == null) rawErr = 'Actualización retornó nulo';
      }
    } catch (e) {
      rawErr = e.toString();
    }

    // refresh provider if we captured one earlier (best-effort)
    if (vprov != null) {
      try {
        // provider is realtime; calling load to ensure immediate consistency
        await vprov.load();
      } catch (_) {}
    }

    if (rawErr != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error guardando vacuna: $rawErr')));
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Widget _field(TextEditingController c, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        TextFormField(
          controller: c,
          enabled: !widget.readOnly,
          validator: (v) => v == null || v.isEmpty ? 'Ingrese valor' : null,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey.shade300,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vacuna')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SizedBox(height: 8),
              const Text('Registrar Nuevo Lote De Vacuna', textAlign: TextAlign.center, style: TextStyle(fontSize: 18)),
              const SizedBox(height: 12),
              _field(_name, 'NOMBRE:'),
              const SizedBox(height: 12),
              _field(_lab, 'LABORATORIO:'),
              const SizedBox(height: 12),
              Row(children: [Expanded(child: _field(_fechaIngreso, 'FECHA DE INGRESO:')), const SizedBox(width: 12), Expanded(child: _field(_fechaVenc, 'FECHA DE VENCIMIENTO:'))]),
              const SizedBox(height: 12),
              Row(children: [Expanded(child: _field(_lote, 'Nº DE LOTE:')), const SizedBox(width: 12), Expanded(child: _field(_factura, 'Nº DE FACTURA:'))]),
              const SizedBox(height: 12),
              _field(_proveedor, 'PROVEEDOR:'),
              const SizedBox(height: 12),
              // Simplified required fields requested by product owner
              _field(_codigo, 'CÓDIGO:'),
              const SizedBox(height: 12),
              _field(_cantidad, 'CANTIDAD:'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(border: Border.all(color: Colors.black54), borderRadius: BorderRadius.circular(8)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('PRESENTACIÓN:'),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _presentacion,
                      items: [
                        DropdownMenuItem(value: 'Monodosis', child: Text('Monodosis')),
                        DropdownMenuItem(value: 'Multidosis', child: Text('Multidosis')),
                      ],
                      onChanged: (v) => setState(() => _presentacion = v ?? 'Monodosis'),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.grey.shade200,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(children: [Expanded(child: _field(_dosisPorFrasco, 'DOSIS POR FRASCO:')), const SizedBox(width: 12), Expanded(child: _field(_cantidadFrascos, 'CANTIDAD DE FRASCOS RECIBIDOS:'))]),
              const SizedBox(height: 18),
              if (!widget.readOnly)
                ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF09A656), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))), onPressed: _save, child: const Text('REGISTRAR', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white))),
            ]),
          ),
        ),
      ),
    );
  }
}
