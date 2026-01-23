import 'package:flutter/material.dart';

class VaccinationFormPage extends StatelessWidget {
  const VaccinationFormPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vacunación Rápida')),
      body: const Center(child: Text('Formulario de registro de vacunación')),
    );
  }
}
