import 'package:flutter_test/flutter_test.dart';
import 'package:ej_reportes/models/invoice_model.dart';

void main() {
  group('InvoiceModel Tests', () {
    test('Creación, serialización y helpers de InvoiceModel', () {
      final now = DateTime.now();
      final invoice = InvoiceModel(
        id: 'drive_file_123',
        pdfName: 'Factura_F102.pdf',
        folio: 'F102',
        clientName: 'Taquería La Mexicana',
        clientPhone: '8112345678',
        clientEmail: 'contacto@lamexicana.com',
        createdTime: now,
        status: 'pending',
        parentFolderId: 'folder_pending_456',
        xmlFileId: 'xml_file_789',
        xmlFileName: 'Factura_F102.xml',
        fileSize: 153600, // ~150 KB
      );

      expect(invoice.hasXml, isTrue);
      expect(invoice.formattedFileSize, '150.0 KB');
      expect(invoice.status, 'pending');

      final map = invoice.toMap();
      expect(map['id'], 'drive_file_123');
      expect(map['pdfName'], 'Factura_F102.pdf');
      expect(map['xmlFileName'], 'Factura_F102.xml');

      final deserialized = InvoiceModel.fromMap(map);
      expect(deserialized.id, invoice.id);
      expect(deserialized.folio, invoice.folio);
      expect(deserialized.clientName, invoice.clientName);
      expect(deserialized.hasXml, isTrue);

      final paidCopy = invoice.copyWith(status: 'paid');
      expect(paidCopy.status, 'paid');
      expect(paidCopy.folio, 'F102');
    });

    test('InvoiceModel sin XML y tamaño cero', () {
      final invoice = InvoiceModel(
        id: 'drive_file_001',
        pdfName: 'Factura_S_N.pdf',
        folio: 'S_N',
        clientName: 'Cliente Sin XML',
        createdTime: DateTime.now(),
        status: 'pending',
        parentFolderId: 'folder_001',
        fileSize: 0,
      );

      expect(invoice.hasXml, isFalse);
      expect(invoice.formattedFileSize, '');
    });
  });
}
