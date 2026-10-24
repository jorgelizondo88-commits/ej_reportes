import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ej_reportes/models/contract_model.dart';
import 'package:ej_reportes/services/contract_pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Generación de Contrato Legal en PDF funciona correctamente', () async {
    final contract = ContractModel(
      id: 'test_123',
      folio: 'EJ-POL-2026-0001',
      creationDate: DateTime.now(),
      clientName: 'Juan Pérez',
      businessName: 'Empresa de Prueba S.A. de C.V.',
      rfc: 'EPS200101XYZ',
      address: 'Av. Constitución 1234, Monterrey, N.L.',
      phone: '811-234-5678',
      email: 'contacto@empresa.com',
      representativeName: 'Juan Pérez Gómez',
      representativeRole: 'Representante Legal',
      representativePhone: '811-234-5678',
      serviceType: 'Póliza Comercial / Industrial',
      durationMonths: 12,
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 12, 31),
      visitFrequency: 'Mensual (1 visita/mes)',
      totalVisits: 12,
      targetPests: ['Cucarachas', 'Roedores', 'Alacranes'],
      coveredAreas: 'Comedores, oficinas, almacenes y perímetro',
      costPerVisit: 1500.0,
      monthlyCost: 1500.0,
      totalContractCost: 18000.0,
      paymentMethod: 'Transferencia Electrónica',
      paymentTerms: 'Pago los primeros 5 días hábiles del mes',
      specialClauses: 'Se incluyen 2 servicios extraordinarios en caso de contingencia.',
      jurisdiction: 'Monterrey, Nuevo León',
      signerFullName: 'Juan Pérez Gómez',
    );

    final pdfBytes = await ContractPdfService.generateContractPdf(contract);
    expect(pdfBytes.isNotEmpty, true, reason: 'El PDF del contrato no debe estar vacío');

    final pdfString = String.fromCharCodes(pdfBytes);
    final pageCount = RegExp(r'/Type\s*/Page[^s]').allMatches(pdfString).length;
    print('DEBUG_PAGE_COUNT sin INE: $pageCount');
    expect(pageCount, 2, reason: 'El contrato estándar debe caber exactamente en 2 páginas');
  });

  test('Contrato con INE y Firmas se mantiene en 2 páginas ejecutivas', () async {
    const pngBase64 = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';
    final bytes = base64Decode(pngBase64);
    final frontFile = File('/tmp/test_front_ine.png')..writeAsBytesSync(bytes);
    final backFile = File('/tmp/test_back_ine.png')..writeAsBytesSync(bytes);

    final contract = ContractModel(
      id: 'test_ine',
      folio: 'EJ-POL-2026-0002',
      creationDate: DateTime.now(),
      clientName: 'María Rodríguez',
      businessName: 'Comercializadora Regia S.A.',
      rfc: 'CRG190510ABC',
      address: 'Parque Industrial Milimex, Apodaca, N.L.',
      phone: '818-999-0011',
      email: 'mrodriguez@comercializadora.com',
      representativeName: 'María Rodríguez Salazar',
      representativeRole: 'Directora General',
      representativePhone: '818-999-0011',
      ineFrontPath: frontFile.path,
      ineBackPath: backFile.path,
      serviceType: 'Póliza Comercial / Industrial',
      durationMonths: 12,
      startDate: DateTime(2026, 2, 1),
      endDate: DateTime(2027, 1, 31),
      visitFrequency: 'Quincenal (2 visitas/mes)',
      totalVisits: 24,
      targetPests: ['Cucarachas', 'Moscas', 'Roedores'],
      coveredAreas: 'Área de embarque, comedor y oficinas',
      costPerVisit: 1200.0,
      monthlyCost: 2400.0,
      totalContractCost: 28800.0,
      paymentMethod: 'Transferencia Electrónica',
      paymentTerms: 'Crédito comercial a 30 días naturales',
      specialClauses: 'Nebulizaciones extraordinarias cubiertas ante contingencia.',
      jurisdiction: 'Monterrey, Nuevo León',
      signerFullName: 'María Rodríguez Salazar',
      clientSignatureBytes: bytes,
      contractorSignatureBytes: bytes,
    );

    final pdfBytes = await ContractPdfService.generateContractPdf(contract);
    final pdfString = String.fromCharCodes(pdfBytes);
    final pageCount = RegExp(r'/Type\s*/Page[^s]').allMatches(pdfString).length;
    print('DEBUG_PAGE_COUNT con INE y firmas: $pageCount');
    expect(pageCount, 2, reason: 'El contrato completo con INE y firmas debe caber en 2 páginas');
  });

  test('Folio consecutivo incrementa adecuadamente según historial', () async {
    SharedPreferences.setMockInitialValues({
      'ej_contracts_history_list': jsonEncode([
        {'folio': 'EJ-POL-2026-0001'},
        {'folio': 'EJ-POL-2026-0005'},
      ]),
      'ej_contracts_folio_counter': 5,
    });

    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('ej_contracts_history_list');
    int maxNumber = 0;
    if (jsonString != null && jsonString.isNotEmpty) {
      final List<dynamic> list = jsonDecode(jsonString);
      for (final item in list) {
        final folioStr = item['folio']?.toString() ?? '';
        final parts = folioStr.split('-');
        if (parts.length >= 4) {
          final num = int.tryParse(parts.last);
          if (num != null && num > maxNumber) {
            maxNumber = num;
          }
        }
      }
    }
    final counter = prefs.getInt('ej_contracts_folio_counter') ?? 0;
    final nextNumber = (maxNumber > counter ? maxNumber : counter) + 1;
    final year = DateTime.now().year;
    final nextFolio = 'EJ-POL-$year-${nextNumber.toString().padLeft(4, '0')}';

    expect(nextFolio, 'EJ-POL-$year-0006');
  });
}
