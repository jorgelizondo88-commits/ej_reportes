import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ej_reportes/models/trap_layout_model.dart';
import 'package:ej_reportes/services/trap_layout_service.dart';
import 'package:ej_reportes/services/trap_layout_pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('TrapLayoutModel y TrapPinModel serializan correctamente', () {
    final pin = TrapPinModel(
      id: 'p1',
      code: 'C-01',
      type: 'Cebadero Exterior',
      x: 0.25,
      y: 0.35,
      area: 'Andén 1',
      zone: 'Exterior',
    );

    final layout = TrapLayoutModel(
      id: 'lay_1',
      folio: '#EJ-LAY-001',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      clientBusinessName: 'Setramex Industrial',
      facilityName: 'Planta Principal',
      pins: [pin],
    );

    expect(layout.totalPins, 1);
    expect(layout.totalExteriorBaitStations, 1);
    expect(layout.totalMechanicalTraps, 0);

    final map = layout.toMap();
    final reconstructed = TrapLayoutModel.fromMap(map);

    expect(reconstructed.folio, '#EJ-LAY-001');
    expect(reconstructed.clientBusinessName, 'Setramex Industrial');
    expect(reconstructed.pins.length, 1);
    expect(reconstructed.pins.first.code, 'C-01');
    expect(reconstructed.pins.first.area, 'Andén 1');
  });

  test('TrapLayoutService guarda, lee y genera folios consecutivos', () async {
    final service = TrapLayoutService();

    final folio1 = await service.generateNextFolio();
    expect(folio1, '#EJ-LAY-001');

    final folio2 = await service.generateNextFolio();
    expect(folio2, '#EJ-LAY-002');

    final layout = TrapLayoutModel(
      id: 'test_123',
      folio: folio1,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      clientBusinessName: 'Acme Corp',
      pins: [
        TrapPinModel(
          id: 'pin_1',
          code: 'C-01',
          type: 'Cebadero Exterior',
          x: 0.2,
          y: 0.3,
          area: 'Muro Norte',
        ),
        TrapPinModel(
          id: 'pin_2',
          code: 'TM-01',
          type: 'Trampa Mecánica Interior',
          x: 0.6,
          y: 0.7,
          area: 'Comedor',
          zone: 'Interior',
        ),
      ],
    );

    final saved = await service.saveLayout(layout);
    expect(saved, true);

    final all = await service.getAllLayouts();
    expect(all.length, 1);
    expect(all.first.clientBusinessName, 'Acme Corp');
    expect(all.first.pins.length, 2);

    final deleted = await service.deleteLayout('test_123');
    expect(deleted, true);

    final emptyList = await service.getAllLayouts();
    expect(emptyList.isEmpty, true);
  });

  test('TrapLayoutPdfService genera PDF horizontal ejecutivo sin errores', () async {
    final layout = TrapLayoutModel(
      id: 'lay_pdf_test',
      folio: '#EJ-LAY-005',
      createdAt: DateTime(2026, 11, 3),
      updatedAt: DateTime(2026, 11, 3),
      clientBusinessName: 'Metalmecánica del Norte S.A. de C.V.',
      facilityName: 'Nave Industrial Apodaca',
      clientAddress: 'Av. De la Industria #400, Apodaca, N.L.',
      walls: [
        TrapWallPath(
          id: 'w1',
          points: [
            TrapWallPoint(x: 0.15, y: 0.15),
            TrapWallPoint(x: 0.85, y: 0.15),
            TrapWallPoint(x: 0.85, y: 0.85),
            TrapWallPoint(x: 0.15, y: 0.85),
          ],
          isClosed: true,
          label: 'Nave Principal',
        ),
        TrapWallPath(
          id: 'w2',
          points: [
            TrapWallPoint(x: 0.50, y: 0.15),
            TrapWallPoint(x: 0.50, y: 0.85),
          ],
          isClosed: false,
          label: 'Muro Central',
        ),
      ],
      pins: [
        TrapPinModel(id: '1', code: 'C-01', type: 'Cebadero Exterior', x: 0.15, y: 0.20, area: 'Acceso Principal'),
        TrapPinModel(id: '2', code: 'C-02', type: 'Cebadero Exterior', x: 0.85, y: 0.20, area: 'Patio Maniobras'),
        TrapPinModel(id: '3', code: 'TM-01', type: 'Trampa Mecánica Interior', x: 0.40, y: 0.60, area: 'Almacén Racks'),
        TrapPinModel(id: '4', code: 'TG-01', type: 'Trampa de Goma', x: 0.50, y: 0.75, area: 'Cuarto de Máquinas'),
        TrapPinModel(id: '5', code: 'LU-01', type: 'Lámpara Luz UV', x: 0.30, y: 0.40, area: 'Entrada Comedor'),
      ],
    );

    final pdfBytes = await TrapLayoutPdfService.generateLayoutPdf(layout);
    expect(pdfBytes.isNotEmpty, true);
    expect(pdfBytes.length, greaterThan(1000));
  });
}
