import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signature/signature.dart';

class SignatureStep extends StatefulWidget {
  final String technicianName;
  final String receivedByName;
  final Uint8List? currentTechSignature;
  final Uint8List? currentClientSignature;
  final Function(String techName, String receiverName) onNamesChanged;
  final Function(Uint8List? techSign, Uint8List? clientSign) onSignaturesUpdated;

  const SignatureStep({
    super.key,
    required this.technicianName,
    required this.receivedByName,
    this.currentTechSignature,
    this.currentClientSignature,
    required this.onNamesChanged,
    required this.onSignaturesUpdated,
  });

  @override
  State<SignatureStep> createState() => _SignatureStepState();
}

class _SignatureStepState extends State<SignatureStep> {
  Uint8List? _techSignatureBytes;
  Uint8List? _clientSignatureBytes;
  late TextEditingController _techNameController;
  late TextEditingController _receiverNameController;

  static const String _prefTechNameKey = 'ej_saved_tech_name';
  static const String _prefTechSignKey = 'ej_saved_tech_sign';

  @override
  void initState() {
    super.initState();
    _techNameController = TextEditingController(text: widget.technicianName);
    _receiverNameController = TextEditingController(text: widget.receivedByName);
    _techSignatureBytes = widget.currentTechSignature;
    _clientSignatureBytes = widget.currentClientSignature;

    _loadDefaultTechnician();
  }

  Future<void> _loadDefaultTechnician() async {
    final prefs = await SharedPreferences.getInstance();

    if (_techNameController.text.trim().isEmpty) {
      final savedName = prefs.getString(_prefTechNameKey);
      if (savedName != null && savedName.isNotEmpty) {
        setState(() {
          _techNameController.text = savedName;
        });
        widget.onNamesChanged(savedName, _receiverNameController.text);
      }
    }

    if (_techSignatureBytes == null) {
      final savedSignBase64 = prefs.getString(_prefTechSignKey);
      if (savedSignBase64 != null && savedSignBase64.isNotEmpty) {
        final bytes = base64Decode(savedSignBase64);
        setState(() {
          _techSignatureBytes = bytes;
        });
        widget.onSignaturesUpdated(_techSignatureBytes, _clientSignatureBytes);
      }
    }
  }

  Future<void> _saveAsDefaultTechnician() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefTechNameKey, _techNameController.text.trim());
    if (_techSignatureBytes != null) {
      await prefs.setString(_prefTechSignKey, base64Encode(_techSignatureBytes!));
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Firma y nombre del técnico guardados como predeterminados!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  void dispose() {
    _techNameController.dispose();
    _receiverNameController.dispose();
    super.dispose();
  }

  Future<void> _openFullScreenSignature({
    required String title,
    required Function(Uint8List?) onSigned,
  }) async {
    final controller = SignatureController(
      penStrokeWidth: 4,
      penColor: Colors.black,
      exportBackgroundColor: Colors.transparent, // Exporta trazo sin fondo blanco
    );

    final Uint8List? result = await Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) {
          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              title: Text(title),
              backgroundColor: const Color(0xFF0F2B48),
              foregroundColor: Colors.white,
              actions: [
                TextButton(
                  onPressed: () => controller.clear(),
                  child: const Text('Limpiar', style: TextStyle(color: Colors.white)),
                ),
                FilledButton.tonal(
                  onPressed: () async {
                    if (controller.isNotEmpty) {
                      final bytes = await controller.toPngBytes();
                      if (context.mounted) Navigator.pop(context, bytes);
                    } else {
                      if (context.mounted) Navigator.pop(context, null);
                    }
                  },
                  child: const Text('Guardar'),
                ),
                const SizedBox(width: 8),
              ],
            ),
            body: SafeArea(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    color: Colors.amber.shade50,
                    width: double.infinity,
                    child: const Text(
                      'Firme dentro de toda el área blanca. La pantalla está bloqueada para que no se mueva.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.brown),
                    ),
                  ),
                  Expanded(
                    child: Signature(
                      controller: controller,
                      backgroundColor: Colors.white, // Pantalla blanca para dibujar con comodidad
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (result != null) {
      onSigned(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tarjeta Firma Técnico (Totalmente responsiva con Wrap)
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      const Text(
                        'Firma del Técnico (Predeterminada)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                        icon: const Icon(Icons.lock_outline, size: 16),
                        label: const Text('Fijar'),
                        onPressed: _saveAsDefaultTechnician,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _techNameController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del Técnico Especialista',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) {
                      widget.onNamesChanged(val, _receiverNameController.text);
                    },
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () {
                      _openFullScreenSignature(
                        title: 'Firma del Técnico Especialista',
                        onSigned: (bytes) {
                          setState(() => _techSignatureBytes = bytes);
                          widget.onSignaturesUpdated(_techSignatureBytes, _clientSignatureBytes);
                          _saveAsDefaultTechnician();
                        },
                      );
                    },
                    child: Container(
                      height: 140,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _techSignatureBytes != null
                          ? Stack(
                        children: [
                          Center(child: Image.memory(_techSignatureBytes!)),
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.edit, size: 16, color: Colors.white),
                            ),
                          ),
                        ],
                      )
                          : const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.touch_app, size: 36, color: Color(0xFF0F2B48)),
                            SizedBox(height: 6),
                            Text(
                              'Toca aquí para firmar en pantalla completa',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Tarjeta Firma Encargado
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Firma del Encargado / Quien Recibe',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _receiverNameController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre y Cargo de Quien Recibe',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) =>
                        widget.onNamesChanged(_techNameController.text, val),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () {
                      _openFullScreenSignature(
                        title: 'Firma de Conformidad del Cliente',
                        onSigned: (bytes) {
                          setState(() => _clientSignatureBytes = bytes);
                          widget.onSignaturesUpdated(_techSignatureBytes, _clientSignatureBytes);
                        },
                      );
                    },
                    child: Container(
                      height: 140,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _clientSignatureBytes != null
                          ? Stack(
                        children: [
                          Center(child: Image.memory(_clientSignatureBytes!)),
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.edit, size: 16, color: Colors.white),
                            ),
                          ),
                        ],
                      )
                          : const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.touch_app, size: 36, color: Color(0xFF0F2B48)),
                            SizedBox(height: 6),
                            Text(
                              'Toca aquí para firmar en pantalla completa',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}