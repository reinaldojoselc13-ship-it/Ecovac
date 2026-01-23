class RegistroVacunacion {
  final String id;
  final String tipoVacuna;
  final String lote;
  final DateTime? proximaDosis;

  RegistroVacunacion({required this.id, required this.tipoVacuna, required this.lote, this.proximaDosis});
}
