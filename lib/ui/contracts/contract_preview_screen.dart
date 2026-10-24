import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/contract_model.dart';
import '../../services/contract_pdf_service.dart';

class ContractPreviewScreen extends StatefulWidget {
  final ContractModel contract;

  const ContractPreviewScreen({super.key, required this.contract});

  @override
  State<ContractPreviewScreen> createState() => _ContractPreviewScreenState();
}

class _ContractPreviewScreenState extends State<ContractPreviewScreen> {
  static const String _contractsHistoryKey = 'ej_contracts_history_list';
  bool _isSaving = false;
  bool _isSaved = false;

  String _buildFileName() {
    final folio = widget.contract.folio.trim();
    final client = widget.contract.businessName.trim().isNotEmpty
        ? widget.contract.businessName.trim()
        : widget.contract.clientName.trim();

    final cleanFolio = folio.replaceAll(RegExp(r'[^\w-]'), '_');
    final cleanClient = client
        .replaceAll(RegExp(r'[^\wáéíóúÁÉÍÓÚñÑ\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '_');

    if (cleanClient.isEmpty) {
      return cleanFolio.isEmpty ? 'Contrato.pdf' : 'Contrato_$cleanFolio.pdf';
    }
    return 'Contrato_${cleanFolio}_$cleanClient.pdf';
  }

  Future<void> _shareContract() async {
    try {
      final pdfBytes = await ContractPdfService.generateContractPdf(widget.contract);
      final fileName = _buildFileName();

      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(pdfBytes);

      final clientTitle = widget.contract.businessName.isNotEmpty
          ? widget.contract.businessName
          : widget.contract.clientName;

      await Share.shareXFiles(
        [XFile(tempFile.path, name: fileName)],
        text: 'Contrato de Póliza de Control de Plagas - Folio ${widget.contract.folio}',
        subject: 'Póliza y Contrato: $clientTitle',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al compartir contrato: $e')),
        );
      }
    }
  }

  Future<void> _saveContractToHistory() async {
    if (_isSaved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este contrato ya se encuentra guardado en el historial.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final pdfBytes = await ContractPdfService.generateContractPdf(widget.contract);
      final fileName = _buildFileName();

      final appDir = await getApplicationDocumentsDirectory();
      final savedContractsDir = Directory('${appDir.path}/contratos_guardados');
      if (!await savedContractsDir.exists()) {
        await savedContractsDir.create(recursive: true);
      }

      final savedFile = File('${savedContractsDir.path}/$fileName');
      await savedFile.writeAsBytes(pdfBytes);

      final contractWithFile = widget.contract.copyWith(pdfPath: savedFile.path);

      final prefs = await SharedPreferences.getInstance();
      final existingHistory = prefs.getString(_contractsHistoryKey);
      List<dynamic> list = [];
      if (existingHistory != null) {
        try {
          list = jsonDecode(existingHistory);
        } catch (_) {
          list = [];
        }
      }

      // Evitar duplicados por folio
      list.removeWhere((item) => item['folio'] == widget.contract.folio);
      list.insert(0, contractWithFile.toMap());

      await prefs.setString(_contractsHistoryKey, jsonEncode(list));

      if (mounted) {
        setState(() {
          _isSaved = true;
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Contrato guardado correctamente en tu historial.'),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fileName = _buildFileName();
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Contrato: ${widget.contract.folio}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF0F2B48),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Compartir Contrato',
            onPressed: _shareContract,
          ),
        ],
      ),
      body: InteractiveViewer(
        minScale: 1.0,
        maxScale: 3.5,
        child: PdfPreview(
          build: (format) => ContractPdfService.generateContractPdf(widget.contract),
          allowPrinting: false,
          allowSharing: false,
          canChangeOrientation: false,
          canChangePageFormat: false,
          canDebug: false,
          maxPageWidth: screenWidth,
          pdfFileName: fileName,
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4, offset: const Offset(0, -2)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: const BorderSide(color: Color(0xFF0F2B48), width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.save_alt, color: Color(0xFF0F2B48)),
                label: Text(
                  _isSaved ? 'Guardado' : 'Guardar',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F2B48)),
                ),
                onPressed: _isSaving ? null : _saveContractToHistory,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F2B48),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.share),
                label: const Text(
                  'Enviar WhatsApp',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: _shareContract,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
