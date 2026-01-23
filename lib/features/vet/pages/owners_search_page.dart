import 'package:flutter/material.dart';

class OwnersSearchPage extends StatelessWidget {
  const OwnersSearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buscar Propietarios')),
      body: const Center(child: Text('Buscador de propietarios (BD local)')),
    );
  }
}
