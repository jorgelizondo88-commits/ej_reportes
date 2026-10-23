import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/report_model.dart';
import '../../services/pdf_service.dart';

class PdfPreviewScreen extends StatefulWidget {
  final ServiceReport report;

  const PdfPreviewScreen({super.key, required this.report});

  @override
  State<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen> {
  static const String _historyKey = 'ej_reports_history_list';
  bool _isSaved = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _checkIfAlreadySaved();
  }

  // Verifica si este folio ya había sido guardado previamente
  Future<void> _checkIfAlreadySaved() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);
    if (raw != null && raw.isNotEmpty) {
      final List list = jsonDecode(raw);
      final exists = list.any((item) => item['folio'] == widget.report.reportFolio);
      if (mounted) setState(() => _isSaved = exists);
    }
  }

  // Guardado definitivo en almacenamiento local e historial
  Future<void> _saveToHistory() async {
    setState(() => _isSaving = true);
    try {
      final pdfBytes = await PdfService.generateServiceReportPdf(widget.report);

      // Carpeta permanente en los documentos de la app
      final appDir = await getApplicationDocumentsDirectory();
      final reportsDir = Directory('${appDir.path}/reportes_guardados');
      if (!await reportsDir.exists()) {
        await reportsDir.create(recursive: true);
      }

      final cleanFolio = widget.report.reportFolio.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final filePath = '${reportsDir.path}/$cleanFolio.pdf';
      final file = File(filePath);
      await file.writeAsBytes(pdfBytes, flush: true);

      // Guardar metadatos en SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_historyKey);
      List<dynamic> historyList = raw != null && raw.isNotEmpty ? jsonDecode(raw) : [];

      final reportEntry = {
        'folio': widget.report.reportFolio,
        'businessName': widget.report.businessName,
        'clientName': widget.report.clientName,
        'clientPhone': widget.report.clientPhone,
        'clientAddress': widget.report.clientAddress,
        'serviceDate': widget.report.serviceDate.toIso8601String(),
        'technicianName': widget.report.technicianName,
        'targetedPests': widget.report.targetedPests,
        'filePath': file.path,
        'savedAt': DateTime.now().toIso8601String(),
      };

      final existingIndex = historyList.indexWhere((item) => item['folio'] == widget.report.reportFolio);
      if (existingIndex >= 0) {
        historyList[existingIndex] = reportEntry; // Sobreescribe si es el mismo folio
      } else {
        historyList.insert(0, reportEntry); // Agrega al inicio
      }

      await prefs.setString(_historyKey, jsonEncode(historyList));

      if (mounted) {
        setState(() {
          _isSaved = true;
          _isSaving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡Reporte #${widget.report.reportFolio} guardado en el historial!'),
            backgroundColor: Colors.green.shade800,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar reporte: $e')),
        );
      }
    }
  }

  String _buildFileName() {
    final clientOrBusiness = widget.report.businessName.isNotEmpty
        ? widget.report.businessName
        : widget.report.clientName;
    final cleanClient = clientOrBusiness
        .trim()
        .replaceAll(RegExp(r'[^\wáéíóúÁÉÍÓÚñÑ\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '_');
    final cleanFolio = widget.report.reportFolio.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

    return cleanClient.isNotEmpty
        ? 'Reporte_${cleanFolio}_$cleanClient.pdf'
        : 'Reporte_$cleanFolio.pdf';
  }

  Future<void> _sharePdf() async {
    try {
      final pdfBytes = await PdfService.generateServiceReportPdf(widget.report);
      final tempDir = await getTemporaryDirectory();
      final fileName = _buildFileName();
      final filePath = '${tempDir.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(pdfBytes);

      final clientOrBusiness = widget.report.businessName.isNotEmpty
          ? widget.report.businessName
          : widget.report.clientName;

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Reporte de Servicio de Control de Plagas - Folio ${widget.report.reportFolio}',
        subject: 'Reporte de Servicio: $clientOrBusiness',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar archivo: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final fileName = _buildFileName();

    return Scaffold(
      appBar: AppBar(
        title: Text('Reporte #${widget.report.reportFolio}'),
        backgroundColor: const Color(0xFF0F2B48),
        foregroundColor: Colors.white,
        actions: [
          // Botón de Guardar en Historial
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: _isSaved ? Colors.greenAccent : Colors.white,
            ),
            icon: _isSaving
                ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            )
                : Icon(_isSaved ? Icons.check_circle : Icons.save_alt, size: 20),
            label: Text(_isSaved ? 'Guardado' : 'Guardar'),
            onPressed: _isSaving ? null : _saveToHistory,
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Compartir PDF',
            onPressed: _sharePdf,
          ),
        ],
      ),
      // InteractiveViewer permite pellizcar libremente con dos dedos y moverse por todas las hojas
      body: InteractiveViewer(
        minScale: 1.0,
        maxScale: 3.5,
        panEnabled: true,
        scaleEnabled: true,
        child: PdfPreview(
          build: (format) => PdfService.generateServiceReportPdf(widget.report),
          allowPrinting: false,
          allowSharing: false,
          canChangeOrientation: false,
          canChangePageFormat: false,
          canDebug: false,
          maxPageWidth: screenWidth, // Ajusta la página al ancho del dispositivo
          pdfFileName: fileName,
          loadingWidget: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFF0F2B48)),
                SizedBox(height: 12),
                Text(
                  'Generando documento y procesando fotos...',
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, -3)),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    side: const BorderSide(color: Color(0xFF0F2B48)),
                    foregroundColor: const Color(0xFF0F2B48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.share, size: 20),
                  label: const Text('Compartir PDF', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: _sharePdf,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    backgroundColor: _isSaved ? Colors.green.shade800 : const Color(0xFF0F2B48),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: Icon(_isSaved ? Icons.check_circle : Icons.save_alt, size: 20),
                  label: Text(
                    _isSaved ? 'Guardado ✓' : 'Guardar en Historial',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: _isSaving ? null : _saveToHistory,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}