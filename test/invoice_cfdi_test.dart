import 'package:flutter_test/flutter_test.dart';
import 'package:ej_reportes/models/cfdi_invoice_data.dart';
import 'package:ej_reportes/models/client_model.dart';
import 'package:ej_reportes/services/cfdi_stamping_service.dart';
import 'package:ej_reportes/services/invoice_pdf_service.dart';
import 'package:ej_reportes/utils/spanish_number_to_words.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('SpanishNumberToWords convierte montos a formato legal SAT correctamente', () {
    expect(
      SpanishNumberToWords.convert(2088.0),
      'DOS MIL OCHENTA Y OCHO PESOS 00/100 M.N.',
    );
    expect(
      SpanishNumberToWords.convert(1500.50),
      'MIL QUINIENTOS PESOS 50/100 M.N.',
    );
    expect(
      SpanishNumberToWords.convert(1.0),
      'UN PESO 00/100 M.N.',
    );
    expect(
      SpanishNumberToWords.convert(0.0),
      'CERO PESOS 00/100 M.N.',
    );
  });

  test('ClientModel serializa y deserializa datos fiscales CFDI 4.0', () {
    final client = ClientModel(
      id: 'c1',
      businessName: 'Confianza Médica',
      contactName: 'Dra. Patricia',
      address: 'Av. Vasconcelos 100, San Pedro',
      phone: '818-123-4567',
      email: 'pagos@confianza.com',
      facilityType: 'Hospitalario / Clínica',
      hasTraps: true,
      taxRfc: 'CEM140703EM8',
      taxBusinessName: 'CORPORATIVO EQUIPO MEDICO 360',
      taxAddress: 'Calle Adolfo López Mateos 8911, Col. Burócratas del Estado',
      taxZipCode: '64380',
      taxRegime: '601 - General de Ley Personas Morales',
      taxCfdiUse: 'G03 - Gastos en general',
    );

    expect(client.hasFiscalData, true);
    expect(client.fiscalOrBusinessName, 'CORPORATIVO EQUIPO MEDICO 360');

    final map = client.toMap();
    final restored = ClientModel.fromMap(map);

    expect(restored.taxRfc, 'CEM140703EM8');
    expect(restored.taxBusinessName, 'CORPORATIVO EQUIPO MEDICO 360');
    expect(restored.taxZipCode, '64380');
    expect(restored.taxRegime, '601 - General de Ley Personas Morales');
    expect(restored.hasFiscalData, true);
  });

  test('InvoicePdfService genera PDF idéntico de 1 página con QR y sellos', () async {
    final timbre = CfdiTimbreDigital(
      uuid: '4ED642D6-7601-4C3C-B7BD-7E00B99E0F74',
      noCertificadoEmisor: '00001000000518855488',
      noCertificadoSAT: '00001000000707568881',
      fechaCertificacion: DateTime(2026, 11, 18, 12, 59, 9),
      cadenaOriginal: '||1.1|4ED642D6-7601-4C3C-B7BD-7E00B99E0F74|2026-11-18T12:59:09|FFM100507289||',
      selloEmisor: 'selloEmisorPrueba==',
      selloSAT: 'selloSATPrueba==',
      rfcProvCertif: 'FFM100507289',
      qrString: 'https://verificacfdi.facturaelectronica.sat.gob.mx/default.aspx?id=4ED642D6-7601-4C3C-B7BD-7E00B99E0F74',
    );

    final invoice = CfdiInvoiceData(
      series: 'AFAD',
      folio: '382',
      emissionDate: DateTime(2026, 11, 18, 12, 59, 8),
      receiverBusinessName: 'CORPORATIVO EQUIPO MEDICO 360',
      receiverCommercialName: 'CONFIANZA MEDICA',
      receiverRfc: 'CEM140703EM8',
      receiverAddress: 'CALLE ADOLFOLOPEZMATEOS 8911, Col. Burócratas del Estado, C.P. 64380, Monterrey, Nuevo León, México',
      receiverZip: '64380',
      receiverRegime: '601 - General de Ley Personas Morales',
      receiverCfdiUse: 'G03 - Gastos en general',
      items: [
        CfdiInvoiceItem(
          quantity: 12,
          description: 'ESTACION DE CEBADO PARA ROEDORES',
          satProductCode: '10191700',
          satProductDesc: 'Dispositivos para control de plagas',
          satUnitCode: 'H87',
          satUnitDesc: 'Pieza',
          unitPrice: 150.0,
        ),
      ],
      timbre: timbre,
    );

    expect(invoice.subtotal, 1800.0);
    expect(invoice.ivaAmount, 288.0);
    expect(invoice.total, 2088.0);
    expect(invoice.totalInWords, 'DOS MIL OCHENTA Y OCHO PESOS 00/100 M.N.');

    final pdfBytes = await InvoicePdfService.generateInvoicePdf(invoice);
    expect(pdfBytes.isNotEmpty, true);

    final pdfStr = String.fromCharCodes(pdfBytes);
    final pageCount = RegExp(r'/Type\s*/Page[^s]').allMatches(pdfStr).length;
    expect(pageCount, 1, reason: 'La factura estándar debe ser exactamente de 1 página');

    final xml = CfdiStampingService.buildCfdiXml(invoice, timbre);
    expect(xml.contains('<cfdi:Comprobante'), true);
    expect(xml.contains('Version="4.0"'), true);
    expect(xml.contains('Serie="AFAD"'), true);
    expect(xml.contains('Folio="382"'), true);
    expect(xml.contains('Rfc="EIJJ880119CM7"'), true);
    expect(xml.contains('Rfc="CEM140703EM8"'), true);
    expect(xml.contains('UUID="4ED642D6-7601-4C3C-B7BD-7E00B99E0F74"'), true);
  });

  test('InvoicePdfService soporta múltiples conceptos que sobrepasan 1 página sin fallar', () async {
    final timbre = CfdiTimbreDigital(
      uuid: 'A1B2C3D4-E5F6-7890-ABCD-EF1234567890',
      noCertificadoEmisor: '00001000000518855488',
      noCertificadoSAT: '00001000000707568881',
      fechaCertificacion: DateTime(2026, 11, 18, 14, 0, 0),
      cadenaOriginal: '||1.1|A1B2C3D4-E5F6-7890-ABCD-EF1234567890|2026-11-18T14:00:00||',
      selloEmisor: 'selloMultiPagePrueba==',
      selloSAT: 'selloSatMultiPagePrueba==',
      rfcProvCertif: 'FFM100507289',
      qrString: 'https://verificacfdi.facturaelectronica.sat.gob.mx/default.aspx?id=A1B2C3D4-E5F6-7890-ABCD-EF1234567890',
    );

    // Creamos 10 conceptos con descripción larga para forzar paginación múltiple
    final manyItems = List.generate(10, (index) {
      return CfdiInvoiceItem(
        quantity: (index + 1).toDouble(),
        description: 'SERVICIO DE CONTROL INTEGRAL DE PLAGAS Y MONITOREO DE ROEDORES - SECTOR ${index + 1}',
        satProductCode: '72102100',
        satProductDesc: 'Servicios de control o exterminación de plagas',
        satUnitCode: 'E48',
        satUnitDesc: 'Unidad de servicio',
        unitPrice: 500.0 * (index + 1),
      );
    });

    final multiInvoice = CfdiInvoiceData(
      series: 'AFAD',
      folio: '383',
      emissionDate: DateTime(2026, 11, 18, 14, 0, 0),
      receiverBusinessName: 'CORPORATIVO EQUIPO MEDICO 360',
      receiverCommercialName: 'CONFIANZA MEDICA',
      receiverRfc: 'CEM140703EM8',
      receiverAddress: 'CALLE ADOLFOLOPEZMATEOS 8911, Col. Burócratas del Estado, C.P. 64380, Monterrey, N.L.',
      receiverZip: '64380',
      receiverRegime: '601 - General de Ley Personas Morales',
      receiverCfdiUse: 'G03 - Gastos en general',
      items: manyItems,
      timbre: timbre,
    );

    final pdfBytes = await InvoicePdfService.generateInvoicePdf(multiInvoice);
    expect(pdfBytes.isNotEmpty, true);

    final pdfStr = String.fromCharCodes(pdfBytes);
    final pageCount = RegExp(r'/Type\s*/Page[^s]').allMatches(pdfStr).length;
    expect(pageCount >= 2, true, reason: 'Debe generar 2 o más páginas de forma fluida y sin truncar');
  });
}
