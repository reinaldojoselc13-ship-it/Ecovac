import 'package:flutter/material.dart';

class DeviceDeauthButton extends StatelessWidget {
  final VoidCallback onDeauth;

  const DeviceDeauthButton({super.key, required this.onDeauth});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onDeauth,
      icon: const Icon(Icons.lock_open),
      label: const Text('Desautorizar dispositivo'),
    );
  }
}
