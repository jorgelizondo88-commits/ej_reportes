import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ej_reportes/models/certificate_model.dart';
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

  test('extractCanonicalFolioFromFileName extrae folios limpios aunque tengan acentos o nombre de cliente', () {
    final service = GoogleDriveSyncService();

    expect(
      service.extractCanonicalFolioFromFileName(
        'Cotizacion_EJ-COT-1126-0007_Colegio_Anglo_Español.pdf',
        isQuote: true,
      ),
      'EJ-COT-1126-0007',
    );
    expect(
      service.extractCanonicalFolioFromFileName(
        'Cotizacion_EJ-COT-1126-0006_Asesores_y_Consultores_en_Tecnología.pdf',
        isQuote: true,
      ),
      'EJ-COT-1126-0006',
    );
    expect(
      service.extractCanonicalFolioFromFileName(
        'Cotizacion_EJ-COT-1126-0005_Setramex.pdf',
        isQuote: true,
      ),
      'EJ-COT-1126-0005',
    );
    expect(
      service.extractCanonicalFolioFromFileName(
        'Reporte_EJ-1126-0029_Living_Spaces.pdf',
        isQuote: false,
      ),
      'EJ-1126-0029',
    );
    expect(
      service.extractCanonicalFolioFromFileName(
        'Reporte_EJ_1026_0020.pdf',
        isQuote: false,
      ),
      'EJ-1026-0020',
    );
  });

  test('sanitizeAndSortHistory elimina los 3 duplicados fantasma reales y ordena por fecha descendente', () {
    final service = GoogleDriveSyncService();

    final rawQuotes = <Map<String, dynamic>>[
      // Simulando desorden previo y los 3 shells rotos observados en Mac
      {
        'folio': 'EJ-COT-1026-0001',
        'businessName': 'Cliente Uno',
        'clientPhone': '8111111111',
        'quoteDate': '2026-10-21T20:05:03.710242',
        'savedAt': '2026-10-21T20:11:48.869364',
        'totalAmount': 5104.0,
        'filePath': '/data/user/0/com.ej.ej_reportes/app_flutter/cotizaciones_guardadas/EJ-COT-1026-0001.pdf',
      },
      {
        'folio': 'EJ-COT-1126-0005-Setramex',
        'businessName': 'Setramex',
        'clientPhone': '',
        'quoteDate': '2026-11-05T16:18:02.219Z',
        'savedAt': '2026-11-05T16:18:02.219Z',
        'totalAmount': 0.0,
        'filePath': '/tmp/Cotizacion_EJ-COT-1126-0005_Setramex.pdf',
      },
      {
        'folio': 'EJ-COT-1126-0007-Colegio-Anglo-Espa',
        'businessName': 'Colegio Anglo Español',
        'clientPhone': '',
        'quoteDate': '2026-11-07T16:09:49.065Z',
        'savedAt': '2026-11-07T16:09:49.065Z',
        'totalAmount': 0.0,
        'filePath': '',
      },
      {
        'folio': 'EJ-COT-1026-0004',
        'businessName': 'Cliente Cuatro',
        'clientPhone': '8122222222',
        'quoteDate': '2026-10-29T13:29:13.867671',
        'savedAt': '2026-10-29T13:38:54.985452',
        'totalAmount': 4292.0,
        'filePath': '',
      },
      {
        'folio': 'EJ-COT-1126-0006',
        'businessName': 'Asesores y Consultores en Tecnología',
        'clientPhone': '8133333333',
        'quoteDate': '2026-11-06T12:27:28.482807',
        'savedAt': '2026-11-06T12:30:24.322063',
        'totalAmount': 3712.0,
        'filePath': '',
      },
      {
        'folio': 'EJ-COT-1126-0006-Asesores-y-Consultores-en-Tecnolog',
        'businessName': 'Asesores y Consultores en Tecnología',
        'clientPhone': '',
        'quoteDate': '2026-11-06T18:30:26.420Z',
        'savedAt': '2026-11-06T18:30:26.420Z',
        'totalAmount': 0.0,
        'filePath': '',
      },
      {
        'folio': 'EJ-COT-1126-0007',
        'businessName': 'Colegio Anglo Español',
        'clientPhone': '8144444444',
        'quoteDate': '2026-11-07T10:03:05.082555',
        'savedAt': '2026-11-07T10:09:45.815379',
        'totalAmount': 1682.0,
        'filePath': '',
      },
      {
        'folio': 'EJ-COT-1126-0005',
        'businessName': 'Setramex',
        'clientPhone': '8155555555',
        'quoteDate': '2026-11-05T10:09:04.559413',
        'savedAt': '2026-11-05T10:17:57.587367',
        'totalAmount': 30624.0,
        'filePath': '',
      },
    ];

    final res = service.sanitizeAndSortHistory(rawQuotes, isQuote: true);

    expect(res.removedDuplicates, 3);
    expect(res.items.length, 5);
    expect(
      res.items.map((e) => e['folio']).toList(),
      [
        'EJ-COT-1126-0007',
        'EJ-COT-1126-0006',
        'EJ-COT-1126-0005',
        'EJ-COT-1026-0004',
        'EJ-COT-1026-0001',
      ],
    );
    expect(res.items[0]['totalAmount'], 1682.0);
    expect(res.items[1]['totalAmount'], 3712.0);
    expect(res.items[2]['totalAmount'], 30624.0);
  });

  test('sanitizeAndSortHistory conserva variantes legítimas con precio distinto y ordena mismo día por folio', () {
    final service = GoogleDriveSyncService();

    final res = service.sanitizeAndSortHistory([
      {
        'folio': 'EJ-COT-1126-0008-OP2',
        'businessName': 'Empresa X',
        'clientPhone': '8199999999',
        'quoteDate': '2026-11-08T09:00:00.000',
        'totalAmount': 5500.0,
      },
      {
        'folio': 'EJ-COT-1126-0008',
        'businessName': 'Empresa X',
        'clientPhone': '8199999999',
        'quoteDate': '2026-11-08T10:00:00.000',
        'totalAmount': 4500.0,
      },
      {
        'folio': 'EJ-COT-1126-0009',
        'businessName': 'Empresa Y',
        'clientPhone': '8188888888',
        'quoteDate': '2026-11-08T08:00:00.000',
        'totalAmount': 2500.0,
      },
    ], isQuote: true);

    expect(res.removedDuplicates, 0);
    expect(res.items.length, 3);
    // Mismo día (2026-11-08): #0009 debe quedar arriba aunque su hora sea anterior
    expect(res.items.first['folio'], 'EJ-COT-1126-0009');
  });

  test('reconcileLocalHistoryStorage repara filePath de Android apuntando a PDF válido en Documents local', () async {
    final tempRoot = await Directory.systemTemp.createTemp('ej_sync_test_');
    try {
      final quotesDir = Directory('${tempRoot.path}/Cotizaciones')..createSync(recursive: true);
      final validPdf = File('${quotesDir.path}/Cotizacion_EJ-COT-1026-0001.pdf');
      // Cabecera %PDF-1.5 + relleno > 100 bytes
      await validPdf.writeAsBytes([0x25, 0x50, 0x44, 0x46, ...List.filled(150, 0x41)]);

      final tinyCorruptPdf = File('${quotesDir.path}/Cotizacion_EJ-COT-1026-0004.pdf');
      await tinyCorruptPdf.writeAsBytes([0x25, 0x50, 0x44, 0x46, 0x00]); // < 100 bytes

      SharedPreferences.setMockInitialValues({
        'ej_quotes_history_list': jsonEncode([
          {
            'folio': 'EJ-COT-1026-0001',
            'businessName': 'Cliente Uno',
            'clientPhone': '8111111111',
            'quoteDate': '2026-10-21T20:05:03.710242',
            'totalAmount': 5104.0,
            'filePath': '/data/user/0/com.ej.ej_reportes/app_flutter/cotizaciones_guardadas/EJ-COT-1026-0001.pdf',
          },
          {
            'folio': 'EJ-COT-1026-0004',
            'businessName': 'Cliente Cuatro',
            'clientPhone': '8122222222',
            'quoteDate': '2026-10-29T13:29:13.867671',
            'totalAmount': 4292.0,
            'filePath': '',
          },
        ]),
      });

      final prefs = await SharedPreferences.getInstance();
      final service = GoogleDriveSyncService();
      final changed = await service.reconcileLocalHistoryStorage(
        prefs,
        documentsDirectoryOverride: tempRoot,
      );

      expect(changed, true);
      final updated = (jsonDecode(prefs.getString('ej_quotes_history_list')!) as List)
          .cast<Map<String, dynamic>>();
      expect(updated.length, 2);
      // 0004 (29/10) primero, 0001 (21/10) después
      expect(updated[0]['folio'], 'EJ-COT-1026-0004');
      expect(updated[0]['filePath'], ''); // No enlaza archivo corrupto < 100 bytes
      expect(updated[1]['folio'], 'EJ-COT-1026-0001');
      expect(updated[1]['filePath'], validPdf.path);
    } finally {
      if (tempRoot.existsSync()) tempRoot.deleteSync(recursive: true);
    }
  });

  test('CertificateModel reconoce carpetas de certificados y calcula addedTime correctamente', () {
    expect(CertificateModel.isCertificateFolderName('Certificados'), true);
    expect(CertificateModel.isCertificateFolderName('Certificados de Fumigación'), true);
    expect(CertificateModel.isCertificateFolderName('6_Certificados'), true);
    expect(CertificateModel.isCertificateFolderName('  certificado '), true);
    expect(CertificateModel.isCertificateFolderName('5_Facturas'), false);
    expect(CertificateModel.isCertificateFolderName(''), false);

    // Caso 1: Archivo PDF viejo en PC subido hoy a Drive -> createdTime es mayor que modifiedTime
    final uploadDate = DateTime.utc(2026, 11, 9, 18, 30);
    final oldLocalModified = DateTime.utc(2026, 8, 15, 10, 0);
    final uploadedAdded = CertificateModel.computeEffectiveAddedTime(
      createdTime: uploadDate,
      modifiedTime: oldLocalModified,
    );
    expect(uploadedAdded, uploadDate.toLocal());

    // Caso 2: Archivo en Drive movido o reemplazado posteriormente -> modifiedTime es mayor
    final replacedDate = DateTime.utc(2026, 11, 10, 14, 0);
    final replacedAdded = CertificateModel.computeEffectiveAddedTime(
      createdTime: uploadDate,
      modifiedTime: replacedDate,
    );
    expect(replacedAdded, replacedDate.toLocal());

    // Serialización y tamaño
    final cert = CertificateModel(
      id: 'cert_001',
      pdfName: 'Certificado_Noviembre_2026.pdf',
      clientName: 'Hotel Monterrey',
      clientPhone: '8112345678',
      createdTime: uploadDate,
      modifiedTime: oldLocalModified,
      parentFolderId: 'folder_cert_1',
      subfolderName: '2026',
      fileSize: 2048,
    );
    expect(cert.title, 'Certificado Noviembre 2026');
    expect(cert.formattedFileSize, '2.0 KB');

    final restored = CertificateModel.fromMap(cert.toMap());
    expect(restored.id, 'cert_001');
    expect(restored.clientName, 'Hotel Monterrey');
    expect(restored.subfolderName, '2026');
    expect(restored.addedTime, uploadDate.toLocal());
  });

  test('GoogleDriveSyncService ordena y recupera certificados cacheados por fecha de ingreso', () async {
    final cOld = CertificateModel(
      id: 'c_old',
      pdfName: 'Cert_Enero.pdf',
      clientName: 'Cliente A',
      createdTime: DateTime(2026, 1, 15, 9, 0),
      parentFolderId: 'p1',
    );
    final cMid = CertificateModel(
      id: 'c_mid',
      pdfName: 'Cert_Junio.pdf',
      clientName: 'Cliente B',
      createdTime: DateTime(2026, 6, 20, 11, 30),
      parentFolderId: 'p2',
    );
    final cNew = CertificateModel(
      id: 'c_new',
      pdfName: 'Cert_Noviembre.pdf',
      clientName: 'Cliente C',
      createdTime: DateTime(2026, 11, 9, 16, 45),
      parentFolderId: 'p3',
    );

    SharedPreferences.setMockInitialValues({
      'ej_cached_certificates': jsonEncode([
        cOld.toMap(),
        cNew.toMap(),
        cMid.toMap(),
      ]),
    });

    final service = GoogleDriveSyncService();
    final cachedNewest = await service.getCachedCertificates();
    expect(cachedNewest.map((c) => c.id).toList(), ['c_new', 'c_mid', 'c_old']);

    final oldestFirst = service.sortCertificates(cachedNewest, newestFirst: false);
    expect(oldestFirst.map((c) => c.id).toList(), ['c_old', 'c_mid', 'c_new']);
  });
}
