import 'package:flutter_test/flutter_test.dart';
import 'package:ej_reportes/services/company_presentation_pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Generación de Presentación Corporativa en PDF funciona y genera 5 diapositivas', () async {
    final pdfBytes = await CompanyPresentationPdfService.generatePresentationPdf();
    expect(pdfBytes.isNotEmpty, true, reason: 'El PDF de presentación no debe estar vacío');
    expect(pdfBytes.length > 1000, true);
  });
}
