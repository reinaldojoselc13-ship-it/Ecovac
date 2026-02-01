import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ecovac/core/services/api_service.dart';
import 'vet_profile_form_page.dart';

class VetProfileDetailPage extends StatelessWidget {
  final Map<String, dynamic> profile;
  final ApiService api;
  final bool canEdit;
  const VetProfileDetailPage({required this.profile, required this.api, this.canEdit = true, super.key});

  String _buildShareText(Map<String, dynamic> p) {
    final nombres = (p['nombres'] ?? p['nombre'] ?? '-').toString();
    final apellidos = (p['apellidos'] ?? p['apellido'] ?? '-').toString();
    final cedula = (p['cedula'] ?? '-').toString();
    final telefono = (p['telefono'] ?? '-').toString();
    final direccion = (p['direccion'] ?? '-').toString();
    final colegio = (p['numero_colegio'] ?? '-').toString();
    final sector = (p['sector'] ?? '-').toString();
    return 'Veterinario: $nombres $apellidos\nCédula: $cedula\nTeléfono: $telefono\nDirección: $direccion\nColegio: $colegio\nSector: $sector';
  }

  @override
  Widget build(BuildContext context) {
    final name = (profile['nombres'] ?? profile['nombre'] ?? '').toString();
    final last = (profile['apellidos'] ?? profile['apellido'] ?? '').toString();
    final ced = (profile['cedula'] ?? '').toString();
    final phone = (profile['telefono'] ?? '').toString();
    final address = (profile['direccion'] ?? '').toString();
    final colegio = (profile['numero_colegio'] ?? '').toString();
    final sector = (profile['sector'] ?? '').toString();
    final avatar = (profile['avatar_path'] ?? profile['avatar_url'] ?? '').toString();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E7C76),
        title: const Text('Veterinario'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).pop()),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const SizedBox(height: 8),
            const Text('Información\nDel Veterinario', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(border: Border.all(color: Colors.black54), color: Colors.grey.shade300),
              child: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Nombres:', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(name),
                          const SizedBox(height: 8),
                          const Text('Apellidos:', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(last),
                          const SizedBox(height: 8),
                          const Text('Cedula de Identidad:', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(ced.toString()),
                          const SizedBox(height: 8),
                          const Text('Teléfono:', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(phone.toString()),
                          const SizedBox(height: 8),
                          const Text('Dirección:', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(address.toString()),
                          const SizedBox(height: 8),
                          const Text('Identificador profesional:', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(colegio.toString()),
                          const SizedBox(height: 8),
                          const Text('Sector:', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(sector.toString()),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: 110,
                    height: 110,
                    margin: const EdgeInsets.all(12),
                    decoration: BoxDecoration(border: Border.all(color: Colors.black54)),
                    child: avatar.isNotEmpty
                        ? Image.network(avatar, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.person))
                        : const Icon(Icons.person, size: 64),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),
            // Share + Edit row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.share, size: 32, color: Colors.black54),
                  onPressed: () async {
                    final text = _buildShareText(profile);
                    await Clipboard.setData(ClipboardData(text: text));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Datos copiados al portapapeles')));
                  },
                ),
                if (canEdit)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0E7C76),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    ),
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => Dialog(
                          backgroundColor: Colors.transparent,
                          child: Container(
                            width: double.infinity,
                            height: 260,
                            decoration: BoxDecoration(color: Colors.grey.shade200, border: Border.all(color: Colors.black54)),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const SizedBox(height: 12),
                                const Icon(Icons.warning_amber_rounded, size: 56, color: Colors.amber),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12.0),
                                  child: Text('¿Está seguro que desea editar este perfil?', textAlign: TextAlign.center, style: TextStyle(fontSize: 18)),
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12)),
                                      onPressed: () => Navigator.of(ctx).pop(false),
                                      child: const Text('Cancelar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12)),
                                      onPressed: () => Navigator.of(ctx).pop(true),
                                      child: const Text('Confirmar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                              ],
                            ),
                          ),
                        ),
                      );

                      if (confirmed == true) {
                        if (!context.mounted) return;
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => VetProfileFormPage(api: api, initial: profile)));
                      }
                    },
                    child: const Text('Editar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
              ],
            ),
          ],
        ),
      ),
      
    );
  }
}
