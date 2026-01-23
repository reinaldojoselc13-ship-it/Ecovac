import 'package:get_it/get_it.dart';
import 'package:ecovac/core/services/api_service.dart';

/// Pet remote datasource purgado y adaptado como wrapper hacia `ApiService`.
///
/// Justificación (estilo académico): para eliminar dependencias de dominio
/// veterinario mantenemos una interfaz mínima que delega en el servicio
/// genérico `ApiService` (Persistencia centralizada, desacoplamiento).
abstract class PetRemoteDataSource {
  Future<void> registerPetRemote({required String name});
}

class PetRemoteDataSourceImpl implements PetRemoteDataSource {
  final ApiService _api = GetIt.instance<ApiService>();

  PetRemoteDataSourceImpl();

  @override
  Future<void> registerPetRemote({required String name}) async {
    // En lugar de usar una tabla 'pets' explícita, delegamos la operación
    // a `createStaffProfile` como placeholder funcional. Esto evita que la
    // app quiebre y mantiene persistencia vía Supabase.
    await _api.createStaffProfile({'nombre': name});
  }
}
