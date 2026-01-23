import 'package:flutter/material.dart';

class PhotoPickerWidget extends StatelessWidget {
  final VoidCallback onPick;

  const PhotoPickerWidget({super.key, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return IconButton(onPressed: onPick, icon: const Icon(Icons.photo_camera));
  }
}
