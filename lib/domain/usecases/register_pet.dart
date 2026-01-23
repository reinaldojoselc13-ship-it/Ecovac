import 'package:ecovac/domain/repositories/pet_repository.dart';

/// Caso de uso conservado como adaptador funcional.
///
/// Aunque el dominio de "mascotas" fue purgado, mantenemos un usecase que
/// provee un punto de entrada estable para la UI; internamente delega en
/// `PetRepository` que a su vez usa un datasource neutral.
class RegisterPet {
  RegisterPet(this._repo);
  final PetRepository _repo;

  Future<void> call(String name) => _repo.registerPet(name: name);
}
