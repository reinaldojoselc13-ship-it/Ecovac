import 'package:flutter/material.dart';
import 'package:ecovac/core/services/api_service.dart';
import 'vet_profile_form_page.dart';

/// Página: Consultar Veterinario
/// Diseño moderno solicitado: encabezado esmeralda, buscador con iconos,
/// tarjetas redondeadas y botón grande de registro. No se modifica la
/// barra de navegación inferior (BottomNavigationBar) — queda intacta.
class VetProfilesPage extends StatefulWidget {
  final ApiService api;
  final bool canEdit;
  const VetProfilesPage(this.api, {this.canEdit = true, super.key});

  @override
  State<VetProfilesPage> createState() => _VetProfilesPageState();
}

class _VetProfilesPageState extends State<VetProfilesPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Encabezado: fondo verde esmeralda y texto blanco centrado
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E7C76),
        centerTitle: true,
        title: const Text('Veterinario', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),

      // Cuerpo: buscador + lista conectada a Supabase
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          children: [
            // Barra de búsqueda con icono de lupa y filtro
            Container(
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Icon(Icons.search, color: Colors.black45)),
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(border: InputBorder.none, hintText: 'Buscar por nombre o código'),
                      onChanged: (v) => setState(() => _query = v.trim()),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.filter_list, color: Colors.black45),
                    onPressed: () {
                      // Filtro simple: aquí se puede abrir un dialogo avanzado
                      showDialog<void>(context: context, builder: (ctx) => AlertDialog(title: const Text('Filtrar'), content: const Text('Opciones de filtro...'), actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cerrar'))]));
                    },
                  )
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Lista: carga desde Supabase mediante ApiService
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: widget.api.getStaffProfiles(),
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
                  final items = snap.data ?? [];
                  // Aplicar búsqueda simple en cliente
                  final filtered = items.where((it) {
                    final term = _query.toLowerCase();
                    if (term.isEmpty) return true;
                    final name = (it['nombre'] ?? '').toString().toLowerCase();
                    final id = (it['id'] ?? '').toString().toLowerCase();
                    return name.contains(term) || id.contains(term);
                  }).toList();

                  if (filtered.isEmpty) return const Center(child: Text('No hay perfiles registrados'));

                  return ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final it = filtered[i];
                      final active = (it['active'] == true) || it['active']?.toString() == 'true';
                      final name = (it['nombre'] ?? '').toString();
                      final code = (it['id'] ?? '').toString();

                      return Container(
                        decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            // Texto principal a la izquierda
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('$name ${code.isNotEmpty ? '#$code' : ''}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                Text('Estado: ${active ? 'Activo' : 'Inactivo'}', style: const TextStyle(color: Colors.black54)),
                              ]),
                            ),

                            // Icono de flecha y punto de estado a la derecha
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.arrow_forward_ios, color: Colors.black54),
                                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => VetProfileFormPage(api: widget.api, initial: it, readOnly: true))),
                                ),
                                const SizedBox(width: 6),
                                Container(width: 14, height: 14, decoration: BoxDecoration(color: active ? Colors.green : Colors.red, shape: BoxShape.circle)),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),

      // Botón grande de registrar (no modifica la barra inferior)
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: FloatingActionButton.extended(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => VetProfileFormPage(api: widget.api))),
          label: const Padding(padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0), child: Text('REGISTRAR', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
          backgroundColor: const Color(0xFF00C853),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
      ),
    );
  }

  // Ya no hay diálogo de asignación aquí; si se necesita, rehacer según
  // requerimientos futuros.
}
