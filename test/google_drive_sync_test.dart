import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ej_reportes/models/client_model.dart';
import 'package:ej_reportes/models/cloud_sync_item_model.dart';
import 'package:ej_reportes/services/google_drive_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('CloudSyncItemModel serializa y deserializa correctamente', () {
    final item = CloudSyncItemModel(
      id: 'sync_123',
      clientName: 'Alimentos del Norte',
      documentType: 'Reporte',
      folio: '#EJ-REP-050',
      fileName: 'Reporte_EJ_REP_050.pdf',
      localFilePath: '/data/user/0/com.ej.ej_reportes/reportes/Reporte_EJ_REP_050.pdf',
      status: 'pending',
      createdAt: DateTime(2026, 11, 4, 18, 0),
    );

    expect(item.id, 'sync_123');
    expect(item.clientName, 'Alimentos del Norte');
    expect(item.status, 'pending');

    final map = item.toMap();
    final reconstructed = CloudSyncItemModel.fromMap(map);

    expect(reconstructed.id, 'sync_123');
    expect(reconstructed.folio, '#EJ-REP-050');
    expect(reconstructed.documentType, 'Reporte');
    expect(reconstructed.localFilePath, item.localFilePath);
  });

  test('ClientModel soporta driveFolderId y driveFolderShareUrl con copyWith', () {
    final client = ClientModel(
      id: 'c1',
      businessName: 'Nave Industrial Monterrey',
      contactName: 'Ing. Carlos Ramos',
      address: 'Parque Industrial Milenium',
      phone: '8112345678',
      email: 'carlos@milenium.com',
      facilityType: 'Industrial / Bodega',
      hasTraps: true,
    );

    expect(client.driveFolderId, isNull);
    expect(client.driveFolderShareUrl, isNull);

    final updated = client.copyWith(
      driveFolderId: 'folder_drive_999',
      driveFolderShareUrl: 'https://drive.google.com/drive/folders/folder_drive_999?usp=sharing',
    );

    expect(updated.driveFolderId, 'folder_drive_999');
    expect(updated.driveFolderShareUrl, contains('https://drive.google.com/'));

    final map = updated.toMap();
    final reconstructed = ClientModel.fromMap(map);
    expect(reconstructed.driveFolderId, 'folder_drive_999');
    expect(reconstructed.driveFolderShareUrl, updated.driveFolderShareUrl);
  });

  test('GoogleDriveSyncService inicializa, gestiona cola offline y no colapsa sin conexión', () async {
    final service = GoogleDriveSyncService();

    // Inicialización silenciosa
    final isLogged = await service.initSilently();
    expect(isLogged, false); // No hay cuenta activa en entorno de test

    // Agregar elemento a la cola offline
    await service.enqueueAndSync(
      clientName: 'PepsiCo Planta Apodaca',
      documentType: 'Reporte',
      folio: '#EJ-REP-101',
      localFilePath: '/tmp/test_report.pdf',
      fileName: 'Reporte_EJ_REP_101.pdf',
    );

    final queue = await service.getQueue();
    expect(queue.length, 1);
    expect(queue.first.clientName, 'PepsiCo Planta Apodaca');
    expect(queue.first.status, 'pending');
    expect(queue.first.documentType, 'Reporte');
  });

  test('pickClientDisplayName prioriza businessName no vacío y usa clientName como respaldo', () {
    final service = GoogleDriveSyncService();

    expect(
      service.pickClientDisplayName({'businessName': '  Empresa ABC  ', 'clientName': 'Juan Pérez'}),
      'Empresa ABC',
    );
    expect(
      service.pickClientDisplayName({'businessName': '', 'clientName': '  Juan Pérez  '}),
      'Juan Pérez',
    );
    expect(
      service.pickClientDisplayName({'businessName': '   ', 'clientName': ''}),
      'Cliente',
    );
    expect(
      service.pickClientDisplayName({'businessName': null, 'clientName': null}, fallback: ''),
      '',
    );
  });

  test('saveAndSyncMasterBackup encola el archivo localmente aunque no haya sesión en Drive', () async {
    final service = GoogleDriveSyncService();

    final ok = await service.saveAndSyncMasterBackup(
      clientName: 'Cliente Prueba',
      documentType: 'Reporte',
      folio: 'EJ-REP-2026',
      localFilePath: '/tmp/ej_rep_2026.pdf',
      fileName: 'Reporte_EJ-REP-2026.pdf',
    );

    expect(ok, false);
    final queue = await service.getQueue();
    expect(queue.length, 1);
    expect(queue.first.folio, 'EJ-REP-2026');
    expect(queue.first.clientName, 'Cliente Prueba');
    expect(queue.first.status, 'pending');
  });
}
