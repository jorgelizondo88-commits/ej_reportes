import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class ImageService {
  final ImagePicker _picker = ImagePicker();

  /// Abre la cámara para capturar una foto
  Future<File?> capturePhoto() async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 100, // Tomar a resolución nativa para no deformar
    );
    if (photo == null) return null;
    return await compressImage(File(photo.path));
  }

  /// Selecciona varias fotos de la galería
  Future<List<File>> pickMultiImages() async {
    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isEmpty) return [];

    List<File> compressedFiles = [];
    for (var img in images) {
      File? compressed = await compressImage(File(img.path));
      if (compressed != null) {
        compressedFiles.add(compressed);
      }
    }
    return compressedFiles;
  }

  /// Comprime la imagen a JPEG optimizado (resolución max 1280x1280, calidad 75%)
  Future<File?> compressImage(File file) async {
    final dir = await getTemporaryDirectory();
    final targetPath =
        '${dir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final XFile? result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 75,
      minWidth: 1280,
      minHeight: 1280,
      format: CompressFormat.jpeg,
    );

    if (result == null) return null;
    return File(result.path);
  }
}