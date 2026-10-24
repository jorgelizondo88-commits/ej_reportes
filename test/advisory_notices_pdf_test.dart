import 'package:flutter_test/flutter_test.dart';
import 'package:ej_reportes/models/advisory_notice_model.dart';
import 'package:ej_reportes/services/resource_pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Todos los comunicados y protocolos generan su PDF sin desbordar página', () async {
    final notices = AdvisoryNoticeModel.getAllNotices();
    expect(notices.isNotEmpty, true);

    for (final notice in notices) {
      final pdfBytes = await ResourcePdfService.generateAdvisoryPdf(notice);
      expect(pdfBytes.isNotEmpty, true, reason: 'El PDF de ${notice.id} no debe estar vacío');
    }
  });
}
