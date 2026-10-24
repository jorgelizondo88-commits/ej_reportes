import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/advisory_notice_model.dart';
import '../../services/resource_pdf_service.dart';

class AdvisoryDetailScreen extends StatelessWidget {
  final AdvisoryNoticeModel notice;

  const AdvisoryDetailScreen({super.key, required this.notice});

  Future<void> _sharePdf(BuildContext context) async {
    try {
      final pdfBytes = await ResourcePdfService.generateAdvisoryPdf(notice);
      final tempDir = await getTemporaryDirectory();
      final cleanName = notice.id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final file = File('${tempDir.path}/Comunicado_$cleanName.pdf');
      await file.writeAsBytes(pdfBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Comunicado Oficial EJ Exterminadores: ${notice.title}',
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
            title: const Text('Previsualizar Comunicado'),
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
              build: (format) => ResourcePdfService.generateAdvisoryPdf(notice),
              allowPrinting: false,
              allowSharing: false,
              canChangePageFormat: false,
              canChangeOrientation: false,
              canDebug: false,
              maxPageWidth: screenWidth,
              pdfFileName: 'Comunicado_${notice.id}.pdf',
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
        title: const Text('Comunicado Oficial', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
            // Cabecera del Comunicado
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
                    width: 54,
                    height: 54,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Text(notice.iconEmoji, style: const TextStyle(fontSize: 28)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notice.title,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Dirigido a: ${notice.targetAudience}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: Colors.amberAccent.shade700.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                notice.category,
                                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Dossier 2 Págs.',
                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Marco Normativo y Sanitario Oficial
            if (notice.regulatoryFramework.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF86EFAC), width: 1),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.verified, color: Color(0xFF166534), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Marco Normativo y Sanitario Aplicable',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF166534)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            notice.regulatoryFramework,
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF14532D), height: 1.25),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Diagnóstico y Problemática Detectada
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.red.shade200, width: 1),
              ),
              color: const Color(0xFFFFF5F5),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.report_problem_outlined, color: Colors.red.shade800, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Diagnóstico y Problemática Detectada',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.red.shade900),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      notice.problemStatement,
                      style: TextStyle(fontSize: 12.8, color: Colors.grey.shade900, height: 1.35),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Matriz Operativa de Buenas Prácticas (Incorrecto vs Correcto)
            if (notice.dosAndDonts.isNotEmpty) ...[
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.compare_arrows_rounded, color: Color(0xFF0F2B48), size: 22),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Matriz Operativa de Buenas Prácticas',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F2B48)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...notice.dosAndDonts.map((item) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300, width: 0.8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.cancel, color: Colors.red, size: 16),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      item.badPractice,
                                      style: TextStyle(fontSize: 12, color: Colors.red.shade900, height: 1.25),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 14, thickness: 0.6),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.check_circle, color: Color(0xFF166534), size: 16),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      item.goodPractice,
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF14532D), height: 1.25),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Reglas de Higiene Indispensables
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.checklist_rtl_outlined, color: Color(0xFF0F2B48), size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Reglas de Higiene y Exclusión para el Personal',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F2B48)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...notice.mandatoryRules.asMap().entries.map((entry) {
                      final idx = entry.key + 1;
                      final rule = entry.value;
                      final isProhibido = rule.startsWith('PROHIBIDO') || rule.startsWith('REGLA');

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 10,
                              backgroundColor: isProhibido ? Colors.red.shade700 : const Color(0xFF0F2B48),
                              child: Text(
                                '$idx',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                rule,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: isProhibido ? FontWeight.bold : FontWeight.normal,
                                  color: isProhibido ? Colors.red.shade900 : Colors.black87,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Cronograma y Fases Biológicas de Evolución
            if (notice.biologicalPhases.isNotEmpty) ...[
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.timeline, color: Color(0xFF1E6091), size: 22),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Cronograma y Fases Biológicas de Evolución',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF1E6091)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...notice.biologicalPhases.map((phase) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFCBD5E1), width: 0.7),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    phase.phaseName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF0F2B48)),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E6091),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      phase.timeFrame,
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Text(
                                phase.description,
                                style: const TextStyle(fontSize: 12, color: Color(0xFF334155), height: 1.3),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Medidas para las Instalaciones
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.domain_verification_outlined, color: Color(0xFF1E6091), size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Recomendaciones para Inmueble y Limpieza',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF1E6091)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...notice.facilityRecommendations.map((tip) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('•  ', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E6091))),
                            Expanded(
                              child: Text(tip, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade800, height: 1.3)),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Preguntas Frecuentes Técnicas de Campo (FAQ)
            if (notice.faqs.isNotEmpty) ...[
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.help_outline_rounded, color: Color(0xFF0F2B48), size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Preguntas Frecuentes Técnicas de Campo',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F2B48)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ...notice.faqs.map((faq) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '• ${faq.question}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F2B48)),
                              ),
                              const SizedBox(height: 3),
                              Padding(
                                padding: const EdgeInsets.only(left: 10),
                                child: Text(
                                  faq.answer,
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF334155), height: 1.3),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Principio de Responsabilidad Compartida
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.amber.shade300, width: 1),
              ),
              color: const Color(0xFFFEF3C7),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.handshake_outlined, color: Colors.brown.shade800, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Principio Técnico: Responsabilidad Compartida',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.brown.shade900),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      notice.technicalDisclaimer,
                      style: TextStyle(fontSize: 12.5, color: Colors.brown.shade900, height: 1.35),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Certificación Técnica
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300, width: 0.8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.security, color: Color(0xFF0F2B48), size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dictamen y Protocolo Certificado por:',
                          style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'Ing. Jorge Elizondo / Rep. Técnico',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F2B48)),
                        ),
                        Text(
                          'EJ Exterminadores • Tel: 813-175-9342',
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF1E6091)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Botón Compartir
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
                label: const Text('COMPARTIR COMUNICADO EN PDF', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => _sharePdf(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
