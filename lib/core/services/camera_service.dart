import 'dart:io';
import 'package:image_picker/image_picker.dart';

class CameraService {
  // Placeholder: integración con cámara/galería para adjuntar fotos
  final ImagePicker _picker = ImagePicker();

  /// Selecciona una imagen de la galería
  Future<File?> pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        return File(image.path);
      }
    } catch (e) {
      // Manejo de errores (ej. permisos denegados)
    }
    return null;
  }

  /// Toma una foto con la cámara
  Future<File?> takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
      if (photo != null) {
        return File(photo.path);
      }
    } catch (e) {
      // Manejo de errores
    }
    return null;
  }
}
