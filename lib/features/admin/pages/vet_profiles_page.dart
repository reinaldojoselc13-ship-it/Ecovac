import 'package:flutter/material.dart';
import 'package:ecovac/core/services/api_service.dart';
import 'vet_profile_form_page.dart';
import 'vet_profile_detail_page.dart';

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
  int _reloadTick = 0;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadAdminFlag();
  }

  Future<void> _loadAdminFlag() async {
    try {
      final isAdmin = await widget.api.currentUserIsAdmin();
      if (!mounted) return;
      setState(() => _isAdmin = isAdmin);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isAdmin = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Encabezado: fondo verde esmeralda y texto blanco centrado
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E7C76),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        centerTitle: true,
        title: const Text('Veterinario', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),

      // Cuerpo: buscador + lista conectada a Supabase
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        child: Column(
          children: [
            // Barra de búsqueda con icono de lupa y filtro
            Container(
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                  )
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Icon(Icons.search, color: Color(0xFF94A3B8))),
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Buscar por nombre o código',
                        hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                      ),
                      onChanged: (v) => setState(() => _query = v.trim()),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.tune, color: Color(0xFF0E7C76)),
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
                key: ValueKey(_reloadTick),
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

                      final subtitle = <Widget>[];
                      if (code.isNotEmpty) {
                        subtitle.add(
                          Text(
                            code,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                          ),
                        );
                        subtitle.add(const SizedBox(height: 4));
                      }
                      subtitle.add(
                        Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(color: active ? const Color(0xFF22C55E) : const Color(0xFFEF4444), shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'ESTADO: ${active ? 'ACTIVO' : 'INACTIVO'}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: active ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                              ),
                            ),
                          ],
                        ),
                      );

                      return Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => VetProfileDetailPage(
                                profile: it,
                                api: widget.api,
                                canEdit: (widget.canEdit && _isAdmin),
                              ),
                            ),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 14,
                                  offset: const Offset(0, 8),
                                )
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEAF7F6),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(Icons.person_outline, color: Color(0xFF0E7C76)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                      ),
                                      const SizedBox(height: 4),
                                      ...subtitle,
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.chevron_right, color: Color(0xFF64748B)),
                                if (widget.canEdit && _isAdmin)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                    onPressed: () async {
                                      final id = (it['id'] ?? '').toString();
                                      if (id.isEmpty) return;
                                      final ok = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Eliminar usuario'),
                                          content: const Text('¿Desea eliminar este usuario? Esta acción no se puede deshacer.'),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                              onPressed: () => Navigator.of(ctx).pop(true),
                                              child: const Text('Eliminar'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (ok != true) return;

                                      var deleted = await widget.api.deleteAuthUserAndData(id);
                                      if (!deleted) {
                                        // Fallback: borrar solo en tablas si la función no está disponible
                                        deleted = await widget.api.deleteStaffProfile(id);
                                      }
                                      if (!mounted) return;
                                      if (!deleted) {
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No fue posible eliminar el usuario (ver permisos/RLS).')));
                                        return;
                                      }

                                      setState(() => _reloadTick++);
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usuario eliminado')));
                                    },
                                  ),
                              ],
                            ),
                          ),
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

      // Botón grande de registrar (solo para administradores)
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: (widget.canEdit && _isAdmin) ? Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: FloatingActionButton.extended(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => VetProfileFormPage(api: widget.api))),
          label: const Padding(padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0), child: Text('REGISTRAR', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
          icon: const Icon(Icons.add, color: Colors.white),
          backgroundColor: const Color(0xFF0E7C76),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
      ) : null,
    );
  }

  // Ya no hay diálogo de asignación aquí; si se necesita, rehacer según
  // requerimientos futuros.
}
