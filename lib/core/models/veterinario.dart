// Modelo neutro `Perfil` que reemplaza la entidad específica de veterinaria.
// Se mantiene la clase `Veterinario` como subclase por compatibilidad.
class Perfil {
  final String id;
  final String nombre;
  final String cedula;
  final String rol;
  final String zona;

  Perfil({required this.id, required this.nombre, required this.cedula, required this.rol, required this.zona});
}

@Deprecated('Usar `Perfil` en lugar de `Veterinario`. Esta clase existe sólo por compatibilidad y se puede eliminar en futuras versiones.')
class Veterinario extends Perfil {
  // Constructor de compatibilidad que delega directamente a la clase base `Perfil`.
  // Usamos "super parameters" para evitar repetir nombres y simplificar el código.
  Veterinario({required super.id, required super.nombre, required super.cedula, required super.rol, required super.zona});
}
