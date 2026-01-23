import 'package:flutter/material.dart';

class OwnerFormPage extends StatelessWidget {
  const OwnerFormPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Formulario Propietario')),
      body: const Center(child: Text('Crear/Editar Propietario')),
    );
  }
}
