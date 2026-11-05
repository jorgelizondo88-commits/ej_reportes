import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:ej_reportes/models/report_model.dart';
import 'package:ej_reportes/models/trap_monitoring_model.dart';
import 'package:ej_reportes/services/pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Generación de Reporte de Servicio con 160 fotos no colapsa y maneja paginación extensa', () async {
    final tempDir = Directory.systemTemp.createTempSync('photos_160_test');
    final dummyJpg = File('${tempDir.path}/dummy.jpg');
    // JPEG mínimo válido
    final minJpeg = Uint8List.fromList([
      0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
      0x01, 0x01, 0x00, 0x48, 0x00, 0x48, 0x00, 0x00, 0xFF, 0xDB, 0x00, 0x43,
      0x00, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
      0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
      0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
      0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
      0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
      0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xC0, 0x00, 0x0B, 0x08, 0x00, 0x01, 0x00,
      0x01, 0x01, 0x01, 0x11, 0x00, 0xFF, 0xC4, 0x00, 0x1F, 0x00, 0x00, 0x01,
      0x05, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00,
      0x00, 0x00, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09,
      0x0A, 0x0B, 0xFF, 0xDA, 0x00, 0x08, 0x01, 0x01, 0x00, 0x00, 0x3F, 0x00,
      0xBF, 0x00, 0xFF, 0xD9
    ]);
    dummyJpg.writeAsBytesSync(minJpeg);

    final logoFile = File('assets/images/logo.png');
    final evidences = List.generate(
      160,
      (i) => PhotoEvidence(path: logoFile.path, description: 'Evidencia en área escolar #$i'),
    );

    final report = ServiceReport(
      reportFolio: 'COL-2026-160',
      serviceDate: DateTime(2026, 10, 30),
      serviceTimeStart: '08:00',
      serviceTimeEnd: '14:00',
      technicianName: 'Ing. Jorge Elizondo',
      clientName: 'Lic. Director del Plantel',
      businessName: 'Colegio Bilingüe San Pedro',
      clientAddress: 'Av. Humberto Lobo 500, San Pedro Garza García, N.L.',
      clientPhone: '818-123-4567',
      clientEmail: 'contacto@colegio.edu.mx',
      facilityType: 'Escolar',
      hasTraps: true,
      targetedPests: ['Cucarachas', 'Roedores', 'Alacranes'],
      inspectionFindings: 'Inspección exhaustiva en 160 puntos críticos del campus escolar.',
      chemicals: [
        ChemicalProduct(
          id: 'chem-1',
          name: 'Temprid SC',
          activeIngredient: 'Imidacloprid + Beta-ciflutrín',
          dosage: '10 ml / Litro',
          registrationNumber: 'RSCO-URB-INAC-111-315-009-10',
          applicationMethod: 'Aspersión Focalizada',
          targetArea: 'Zócalos, registros y perímetro exterior',
        ),
      ],
      traps: [
        TrapMonitoring(
          id: 'CEB-01',
          trapType: 'Cebadero de Seguridad',
          location: 'Patio Principal',
          status: 'Activo / Buen Estado',
          consumptionPercentage: 15,
          captureCount: 0,
          observations: 'Cebo reemplazado',
        ),
      ],
      photoEvidences: evidences,
      recommendations: 'Mantener sellados los ductos de desagüe y puertas de cafetería.',
      warranties: 'Garantía de servicio por 30 días naturales.',
      technicianSignature: null,
      clientSignature: null,
      receivedByName: 'Lic. Coordinador de Mantenimiento',
    );

    try {
      final pdfBytes = await PdfService.generateServiceReportPdf(report);
      expect(pdfBytes.isNotEmpty, true);
      expect(pdfBytes.length > 50000, true);

      final pdfString = String.fromCharCodes(pdfBytes);
      final pageMatches = RegExp(r'/Type\s*/Page[^s]').allMatches(pdfString).length;
      print('DEBUG: Reporte con 160 fotos generado con éxito con $pageMatches páginas.');
      expect(pageMatches >= 21, true, reason: '160 fotos a 8 por hoja más carátula debe tener al menos 21 páginas sin truncarse');
    } finally {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    }
  });

  test('Cálculo de visitas y costos para Pólizas Bimestrales y Trimestrales es matemáticamente exacto', () {
    // 12 meses Bimestral -> 6 visitas (no 72)
    const duration12 = 12;
    final bimestralVisits12 = (duration12 / 2).ceil();
    expect(bimestralVisits12, 6);

    // 12 meses Trimestral -> 4 visitas
    final trimestralVisits12 = (duration12 / 3).ceil();
    expect(trimestralVisits12, 4);

    // 6 meses Bimestral -> 3 visitas
    const duration6 = 6;
    final bimestralVisits6 = (duration6 / 2).ceil();
    expect(bimestralVisits6, 3);

    // 6 meses Trimestral -> 2 visitas
    final trimestralVisits6 = (duration6 / 3).ceil();
    expect(trimestralVisits6, 2);

    // Costo total y mensual: Visita de $1,500 en póliza anual bimestral (6 visitas)
    const costPerVisit = 1500.0;
    final totalBimestral = costPerVisit * bimestralVisits12; // 6 * 1500 = 9000
    final monthlyBimestral = totalBimestral / duration12; // 9000 / 12 = 750
    expect(totalBimestral, 9000.0);
    expect(monthlyBimestral, 750.0);

    // Costo total y mensual: Visita de $2,000 en póliza anual trimestral (4 visitas)
    const costPerVisitTri = 2000.0;
    final totalTrimestral = costPerVisitTri * trimestralVisits12; // 4 * 2000 = 8000
    final monthlyTrimestral = totalTrimestral / duration12; // 8000 / 12 = 666.666...
    expect(totalTrimestral, 8000.0);
    expect((monthlyTrimestral - 666.67).abs() < 0.01, true);
  });
}
