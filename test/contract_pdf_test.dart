import 'package:flutter_test/flutter_test.dart';
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
  });
}
