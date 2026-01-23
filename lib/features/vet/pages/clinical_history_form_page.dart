import 'package:flutter/material.dart';

class ClinicalHistoryFormPage extends StatelessWidget {
  const ClinicalHistoryFormPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historial Clínico')),
      body: const Center(child: Text('Formulario de historial clínico')),
    );
  }
}
