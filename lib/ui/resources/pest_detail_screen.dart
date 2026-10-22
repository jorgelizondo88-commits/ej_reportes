import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/pest_info_model.dart';
import '../../services/resource_pdf_service.dart';

class PestDetailScreen extends StatelessWidget {
  final PestInfoModel pest;

  const PestDetailScreen({super.key, required this.pest});

  Future<void> _sharePdf(BuildContext context) async {
    try {
      final pdfBytes = await ResourcePdfService.generatePestInfoPdf(pest);
      final tempDir = await getTemporaryDirectory();
      final cleanName = pest.id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final file = File('${tempDir.path}/Ficha_Tecnica_$cleanName.pdf');
      await file.writeAsBytes(pdfBytes);

      await SharePlus.instance.share(
        ShareRequest(
          files: [XFile(file.path)],
          text: 'Ficha Técnica EJ Exterminadores: ${pest.name}',
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al compartir: $e')),
        );
      }
    }
  }

  void _previewPdf(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text('PDF: ${pest.name}'),
            backgroundColor: const Color(0xFF0F2B48),
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.share),
                tooltip: 'Compartir',
                onPressed: () => _sharePdf(context),
              ),
            ],
          ),
          body: InteractiveViewer(
            minScale: 1.0,
            maxScale: 3.5,
            child: PdfPreview(
              build: (format) => ResourcePdfService.generatePestInfoPdf(pest),
              allowPrinting: true,
              allowSharing: true,
              canChangePageFormat: false,
              canChangeOrientation: false,
              canDebug: false,
              maxPageWidth: screenWidth,
              pdfFileName: 'Ficha_Tecnica_${pest.id}.pdf',
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(pest.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: const Color(0xFF0F2B48),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Ver PDF',
            onPressed: () => _previewPdf(context),
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Compartir',
            onPressed: () => _sharePdf(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera con Emoji y Datos Biológicos
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F2B48), Color(0xFF1E6091)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF0F2B48).withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 3)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    alignment: pwAlignmentCenter(context),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Text(pest.iconEmoji, style: const TextStyle(fontSize: 32)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pest.name,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          pest.scientificName,
                          style: const TextStyle(color: Colors.white70, fontStyle: FontStyle.italic, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          children: [
                            _chipBadge(pest.category, Colors.amberAccent.shade700),
                            _chipBadge(pest.riskLevel, Colors.redAccent.shade100),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Resumen
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Descripción y Comportamiento General',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F2B48))),
                    const SizedBox(height: 6),
                    Text(pest.summary, style: TextStyle(fontSize: 13, color: Colors.grey.shade800, height: 1.35)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Hábitats y Refugios
            _infoCard(
              title: 'Zonas de Anidación y Refugio',
              icon: Icons.home_work_outlined,
              iconColor: const Color(0xFF0F2B48),
              items: pest.habitats,
            ),
            const SizedBox(height: 12),

            // Riesgos a la Salud y Daños
            _infoCard(
              title: 'Riesgos a la Salud y Daños Materiales',
              icon: Icons.warning_amber_outlined,
              iconColor: Colors.red.shade700,
              items: pest.healthRisks,
              isAlert: true,
            ),
            const SizedBox(height: 12),

            // Señales de Infestación
            _infoCard(
              title: 'Señales de Presencia e Infestación',
              icon: Icons.visibility_outlined,
              iconColor: Colors.orange.shade800,
              items: pest.signs,
            ),
            const SizedBox(height: 12),

            // Medidas Preventivas para el Cliente
            _infoCard(
              title: 'Medidas Preventivas para el Cliente',
              icon: Icons.check_circle_outline,
              iconColor: Colors.teal.shade700,
              items: pest.preventionTips,
            ),
            const SizedBox(height: 12),

            // Tratamiento Profesional EJ
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.green.shade300, width: 1),
              ),
              color: const Color(0xFFF0FDF4),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.shield_outlined, color: Colors.green.shade800, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Tratamiento Profesional EJ Exterminadores',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.green.shade900),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      pest.professionalTreatment,
                      style: TextStyle(fontSize: 12.5, color: Colors.green.shade950, height: 1.35),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Botón Compartir PDF
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F2B48),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                icon: const Icon(Icons.share, size: 20),
                label: const Text('COMPARTIR FICHA TÉCNICA EN PDF', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => _sharePdf(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Alignment pwAlignmentCenter(BuildContext context) => Alignment.center;

  static Widget _chipBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 0.8),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );
  }

  static Widget _infoCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<String> items,
    bool isAlert = false,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isAlert ? BorderSide(color: Colors.red.shade200, width: 1) : BorderSide.none,
      ),
      color: isAlert ? const Color(0xFFFFF5F5) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                      color: isAlert ? Colors.red.shade900 : const Color(0xFF0F2B48),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...items.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('•  ', style: TextStyle(fontWeight: FontWeight.bold, color: iconColor)),
                    Expanded(
                      child: Text(
                        item,
                        style: TextStyle(fontSize: 12.5, color: Colors.grey.shade800, height: 1.3),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
