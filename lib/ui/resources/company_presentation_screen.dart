import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/company_presentation_pdf_service.dart';

class CompanyPresentationScreen extends StatelessWidget {
  const CompanyPresentationScreen({super.key});

  Future<void> _sharePdf(BuildContext context) async {
    try {
      final pdfBytes = await CompanyPresentationPdfService.generatePresentationPdf();
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/Presentacion_Corporativa_EJ_Exterminadores.pdf');
      await file.writeAsBytes(pdfBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Presentación Corporativa Oficial de EJ Exterminadores | Manejo Integrado de Plagas (MIP)',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al compartir presentación: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Presentación Corporativa', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: const Color(0xFF0F2B48),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Compartir PDF',
            onPressed: () => _sharePdf(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner Superior Informativo
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFF0F2B48),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amberAccent.shade700.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.stars, color: Colors.amberAccent, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dossier Ejecutivo Oficial (5 Diapositivas)',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                      ),
                      Text(
                        '9 Años de Trayectoria • Misión • Servicios • Metodología MIP',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Visor PDF
          Expanded(
            child: InteractiveViewer(
              minScale: 1.0,
              maxScale: 3.5,
              child: PdfPreview(
                build: (format) => CompanyPresentationPdfService.generatePresentationPdf(),
                allowPrinting: false,
                allowSharing: false,
                canChangePageFormat: false,
                canChangeOrientation: false,
                canDebug: false,
                maxPageWidth: screenWidth * 1.5,
                pdfFileName: 'Presentacion_Corporativa_EJ_Exterminadores.pdf',
              ),
            ),
          ),

          // Botón inferior para compartir rápido
          SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              color: Colors.white,
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF166534),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 2,
                  ),
                  icon: const Icon(Icons.send_rounded, size: 20),
                  label: const Text(
                    'ENVIAR PRESENTACIÓN A CLIENTE (WHATSAPP)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  onPressed: () => _sharePdf(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
