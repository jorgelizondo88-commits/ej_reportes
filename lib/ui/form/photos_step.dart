import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/report_model.dart';
import '../../services/image_service.dart';

class PhotosStep extends StatefulWidget {
  final List<PhotoEvidence> evidences;
  final Function(List<PhotoEvidence>) onEvidencesChanged;

  const PhotosStep({
    super.key,
    required this.evidences,
    required this.onEvidencesChanged,
  });

  @override
  State<PhotosStep> createState() => _PhotosStepState();
}

class _PhotosStepState extends State<PhotosStep> {
  final ImageService _imageService = ImageService();
  bool _isProcessing = false;

  Future<void> _takePhoto() async {
    setState(() => _isProcessing = true);
    final File? compressed = await _imageService.capturePhoto();
    setState(() => _isProcessing = false);

    if (compressed != null) {
      final updated = List<PhotoEvidence>.from(widget.evidences)
        ..add(PhotoEvidence(path: compressed.path, description: ''));
      widget.onEvidencesChanged(updated);
    }
  }

  Future<void> _pickGallery() async {
    setState(() => _isProcessing = true);
    final List<File> compressedFiles = await _imageService.pickMultiImages();
    setState(() => _isProcessing = false);

    if (compressedFiles.isNotEmpty) {
      final updated = List<PhotoEvidence>.from(widget.evidences);
      for (var f in compressedFiles) {
        updated.add(PhotoEvidence(path: f.path, description: ''));
      }
      widget.onEvidencesChanged(updated);
    }
  }

  void _removePhoto(int index) {
    final updated = List<PhotoEvidence>.from(widget.evidences)..removeAt(index);
    widget.onEvidencesChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Evidencias del Servicio (${widget.evidences.length})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF0F2B48),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.camera_alt),
                  tooltip: 'Tomar Foto',
                  onPressed: _isProcessing ? null : _takePhoto,
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  icon: const Icon(Icons.photo_library),
                  tooltip: 'Galería',
                  onPressed: _isProcessing ? null : _pickGallery,
                ),
              ],
            ),
          ],
        ),
        if (_isProcessing) ...[
          const SizedBox(height: 10),
          const LinearProgressIndicator(),
        ],
        const SizedBox(height: 12),
        if (widget.evidences.isEmpty)
          Expanded(
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_a_photo_outlined, size: 40, color: Colors.grey),
                    SizedBox(height: 8),
                    Text(
                      'Sin fotos agregadas. Puedes tomar fotos con la cámara o elegirlas de la galería.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              itemCount: widget.evidences.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final photo = widget.evidences[index];
                return _PhotoCardItem(
                  key: ValueKey(photo.path),
                  photo: photo,
                  onDescriptionChanged: (text) {
                    widget.evidences[index] = PhotoEvidence(path: photo.path, description: text);
                    widget.onEvidencesChanged(widget.evidences);
                  },
                  onDelete: () => _removePhoto(index),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _PhotoCardItem extends StatefulWidget {
  final PhotoEvidence photo;
  final ValueChanged<String> onDescriptionChanged;
  final VoidCallback onDelete;

  const _PhotoCardItem({
    super.key,
    required this.photo,
    required this.onDescriptionChanged,
    required this.onDelete,
  });

  @override
  State<_PhotoCardItem> createState() => _PhotoCardItemState();
}

class _PhotoCardItemState extends State<_PhotoCardItem> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.photo.description);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(widget.photo.path),
                width: 80,
                height: 80,
                cacheWidth: 200,
                cacheHeight: 200,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 80,
                  height: 80,
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  labelText: 'Descripción / Hallazgo',
                  hintText: 'Ej. Foco de actividad en tarja',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                onChanged: widget.onDescriptionChanged,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: widget.onDelete,
            ),
          ],
        ),
      ),
    );
  }
}