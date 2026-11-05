import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ej_reportes/models/advisory_notice_model.dart';
import 'package:ej_reportes/services/resource_pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Exporta los 3 PDFs solicitados por el usuario para entrega inmediata a clientes', () async {
    final allNotices = AdvisoryNoticeModel.getAllNotices();
    final outDir = Directory('/Users/jorgelizondo/ej_reportes/documentos_clientes');
    if (!outDir.existsSync()) {
      outDir.createSync(recursive: true);
    }

    final targetIds = {
      'cucaracha_fiprax_gel': '1_Tratamiento_Fiprax_Gel_Cucaracha_Alemana_EJ.pdf',
      'oficinas_corporativo_general': '2_Protocolo_Fumigacion_Oficinas_Corporativos_EJ.pdf',
      'residencial_casa_habitacion': '3_Guia_Fumigacion_Casa_Habitacion_Residencial_EJ.pdf',
    };

    for (final entry in targetIds.entries) {
      final notice = allNotices.firstWhere(
        (n) => n.id == entry.key,
        orElse: () => throw Exception('Aviso no encontrado: ${entry.key}'),
      );

      final pdfBytes = await ResourcePdfService.generateAdvisoryPdf(notice);
      final outFile = File('${outDir.path}/${entry.value}');
      await outFile.writeAsBytes(pdfBytes);
      expect(outFile.existsSync(), true);
      // ignore: avoid_print
      print('PDF generado exitosamente: ${outFile.path} (${pdfBytes.length} bytes)');
    }
  });
}
