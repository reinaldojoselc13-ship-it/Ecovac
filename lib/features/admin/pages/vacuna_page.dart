import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ecovac/features/admin/providers/jornadas_provider.dart';
import 'package:ecovac/features/admin/providers/vacunas_provider.dart';
import 'package:ecovac/core/services/api_service.dart';
import 'vacuna_form_page.dart';

class VacunaPage extends StatefulWidget {
  final ApiService api;
  final bool canAdd;
  const VacunaPage(this.api, {super.key, this.canAdd = true});

  @override
  State<VacunaPage> createState() => _VacunaPageState();
}

class _VacunaPageState extends State<VacunaPage> {
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // ensure vacunas are loaded when the page appears (if provider provided)
      try {
        final vprov = context.read<VacunasProvider>();
        vprov.startRealtime();
      } catch (_) {}
      // keep jornadas counts updated as well
      try {
        final jprov = context.read<JornadasProvider>();
        jprov.loadCounts();
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    VacunasProvider? prov;
    try {
      prov = context.watch<VacunasProvider>();
    } catch (_) {
      prov = null;
    }

    final items = (prov?.items ?? []).where((it) {
      final term = _query.toLowerCase();
      final nombre = (it['nombre'] ?? '').toString().toLowerCase();
      final fecha = (it['fecha'] ?? '').toString().toLowerCase();
      final marca = (it['laboratorio'] ?? '').toString().toLowerCase();
      return nombre.contains(term) || fecha.contains(term) || marca.contains(term);
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Vacunas')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: 'Buscar...', filled: true, fillColor: Colors.grey.shade200, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: (prov?.loading ?? false)
                ? const Center(child: CircularProgressIndicator())
                : items.isEmpty
                      ? const Center(child: Text('No hay registros'))
                      : Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: ListView.separated(
                            itemCount: items.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, i) {
                              final it = items[i];
                              final estado = (it['estado'] ?? 'Pendiente').toString();
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(18)),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: ListTile(
                                        title: Text(it['nombre']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                                        subtitle: Text('Estado: $estado'),
                                      ),
                                    ),
                                    // view button (always available)
                                    IconButton(icon: const Icon(Icons.remove_red_eye), onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => VacunaFormPage(initial: it, api: widget.api, readOnly: !widget.canAdd)))),
                                    if (prov != null && widget.canAdd) ...[ 
                                      const SizedBox(width: 8),
                                      IconButton(icon: const Icon(Icons.edit), onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => VacunaFormPage(initial: it, api: widget.api)))),
                                      IconButton(
                                        icon: const Icon(Icons.delete),
                                        onPressed: () async {
                                          final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Confirmar'), content: const Text('Eliminar lote de vacuna?'), actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')), TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Eliminar'))]));
                                          if (ok == true) await prov!.delete(it['id'].toString());
                                        },
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
            ),
            const SizedBox(height: 8),
            if (widget.canAdd) ...[
              Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF09A656), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14)),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => VacunaFormPage(api: widget.api, readOnly: false))),
                  child: const Text('AÑADIR', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}
