import 'package:flutter/material.dart';

class QuickActionsCard extends StatelessWidget {
  final VoidCallback onNewVaccine;
  final VoidCallback onNewPatient;

  const QuickActionsCard({super.key, required this.onNewVaccine, required this.onNewPatient});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          ElevatedButton(onPressed: onNewVaccine, child: const Text('Nueva Vacuna')),
          ElevatedButton(onPressed: onNewPatient, child: const Text('Acción')),
        ],
      ),
    );
  }
}
