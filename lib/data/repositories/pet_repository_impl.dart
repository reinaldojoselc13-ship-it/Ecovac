import 'package:ecovac/data/datasources/remote/pet_remote_data_source.dart';
import 'package:ecovac/domain/repositories/pet_repository.dart';

/// Implementación adaptativa del repositorio de "pet".
/// La clase delega a un datasource neutralizado que persiste mediante `ApiService`.
class PetRepositoryImpl implements PetRepository {
  PetRepositoryImpl({required PetRemoteDataSource remoteDataSource}) : _remote = remoteDataSource;

  final PetRemoteDataSource _remote;

  @override
  Future<void> registerPet({required String name}) async {
    // Persistencia delegada; aquí podríamos añadir reintentos o validaciones.
    await _remote.registerPetRemote(name: name);
  }
}

