import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ecovac/features/admin/providers/jornadas_provider.dart';
import 'jornada_form_page.dart';

class JornadasListPage extends StatefulWidget {
  final String? statusFilter; // optional substring to filter estado
  final String? dateFilter; // optional yyyy-MM-dd to filter fecha
  final bool canEdit; // whether edit/delete/add controls are shown

  const JornadasListPage({super.key, this.statusFilter, this.dateFilter, this.canEdit = true});

  @override
  State<JornadasListPage> createState() => _JornadasListPageState();
}

class _JornadasListPageState extends State<JornadasListPage> {
  String _query = '';

  // Nota: la agrupación por día para el calendario se implementa en
  // `CalendarPage` (mantenerla allí evita duplicación).
  // Esta lista muestra únicamente las jornadas en formato de lista.
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prov = context.read<JornadasProvider>();
      prov.loadCounts();
      prov.startRealtime();
    });
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<JornadasProvider>();
    var items = prov.items.where((it) {
      final term = _query.toLowerCase();
      final nombre = (it['nombre'] ?? '').toString().toLowerCase();
      final fecha = (it['fecha'] ?? '').toString().toLowerCase();
      final marca = (it['marca'] ?? '').toString().toLowerCase();
      return nombre.contains(term) || fecha.contains(term) || marca.contains(term);
    }).toList();

    // apply optional status filter
    if (widget.statusFilter != null && widget.statusFilter!.isNotEmpty) {
      final sf = widget.statusFilter!.toLowerCase();
      items = items.where((it) {
        final estado = (it['estado'] ?? '').toString().toLowerCase();
        return estado.contains(sf);
      }).toList();
    }

    // apply optional date filter (expects yyyy-MM-dd prefix)
    if (widget.dateFilter != null && widget.dateFilter!.isNotEmpty) {
      final df = widget.dateFilter!;
      items = items.where((it) {
        final fecha = (it['fecha'] ?? '').toString();
        return fecha.startsWith(df);
      }).toList();
    }

    // NOTE: agrupación para uso en la vista Calendario está disponible
    // mediante la función `_groupedByDay`, pero aquí no se usa directamente.

    return Scaffold(
      body: prov.loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header with gradient and curved bottom
                Container(
                  height: 180,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                    borderRadius: BorderRadius.only(bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28)),
                  ),
                  child: SafeArea(
                    child: Stack(
                      children: [
                        Positioned(
                          left: 8,
                          top: 8,
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 20.0),
                            child: Text(
                              'Lista\nJornadas\nde Vacunación',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                              maxLines: 3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // White curved container overlapping
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12),
                    decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28))),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                      child: Column(
                        children: [
                                                // Note: calendar removed from this list view. Use the Calendario screen to view jornadas by month/day.
                                                const SizedBox(height: 12),
                          Container(
                            decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(24)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: TextField(
                              decoration: InputDecoration(border: InputBorder.none, hintText: 'Buscar Jornada...'),
                              onChanged: (v) => setState(() => _query = v),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: items.isEmpty
                                ? const Center(child: Text('No hay registros'))
                                : ListView.separated(
                                    itemCount: items.length,
                                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                                    itemBuilder: (context, i) {
                                      final it = items[i];
                                      final estado = (it['estado'] ?? 'Pendiente').toString();
                                      Color dotColor = Colors.grey;
                                      if (estado.toLowerCase().contains('culminada') || estado.toLowerCase().contains('completada')) dotColor = Colors.green;
                                      if (estado.toLowerCase().contains('pendiente')) dotColor = Colors.red;
                                      if (estado.toLowerCase().contains('proceso') || estado.toLowerCase().contains('en proceso')) dotColor = Colors.black54;

                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                        decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(18)),
                                        child: Row(
                                          children: [
                                            Container(width: 10, height: 10, margin: const EdgeInsets.only(right: 8), decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
                                            Expanded(
                                              child: ListTile(
                                                title: Text(it['nombre']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                                                subtitle: Text('Estado: $estado'),
                                              ),
                                            ),
                                            // view button (always available)
                                            IconButton(
                                              icon: const Icon(Icons.remove_red_eye),
                                              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => JornadaFormPage(initial: it, readOnly: !widget.canEdit))),
                                            ),
                                            if (widget.canEdit) ...[
                                              const SizedBox(width: 8),
                                              IconButton(icon: const Icon(Icons.edit), onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => JornadaFormPage(initial: it)))),
                                              IconButton(
                                                icon: const Icon(Icons.delete),
                                                onPressed: () async {
                                                  final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Confirmar'), content: const Text('Eliminar jornada?'), actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')), TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Eliminar'))]));
                                                  if (ok == true) await prov.delete(it['id'].toString());
                                                },
                                              ),
                                            ],
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                          ),
                          const SizedBox(height: 8),
                          if (widget.canEdit)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const JornadaFormPage())),
                                child: const Text('Añadir Jornada', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                              ),
                            ),
                          const SizedBox(height: 6),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
