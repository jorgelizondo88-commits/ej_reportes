import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/client_model.dart';
import '../models/cloud_sync_item_model.dart';
import '../models/invoice_model.dart';
import '../models/trap_layout_model.dart';
import 'client_service.dart';
import 'trap_layout_pdf_service.dart';

class DatabaseRestoreResult {
  final bool success;
  final String message;
  final int clientsCount;
  final int reportsCount;
  final int quotesCount;
  final int contractsCount;

  const DatabaseRestoreResult({
    required this.success,
    required this.message,
    this.clientsCount = 0,
    this.reportsCount = 0,
    this.quotesCount = 0,
    this.contractsCount = 0,
  });
}

class _GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  _GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }

  @override
  void close() {
    _client.close();
    super.close();
  }
}

class GoogleDriveSyncService {
  static final GoogleDriveSyncService _instance = GoogleDriveSyncService._internal();
  factory GoogleDriveSyncService() => _instance;
  GoogleDriveSyncService._internal();

  static const String _queueStorageKey = 'ej_cloud_sync_queue';
  static const String _folderCacheKey = 'ej_drive_folder_cache';
  static const String _lastBackupDateKey = 'ej_last_cloud_backup_date';

  // Credenciales OAuth para Windows Desktop
  static const String _windowsClientId = '803570972313-aq3d1glj7nboprsdid92n038e1o4of7n.apps.googleusercontent.com';
  static const String _windowsClientSecret = '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';
  static const String _windowsAccessTokenKey = 'ej_windows_access_token';
  static const String _windowsRefreshTokenKey = 'ej_windows_refresh_token';
  static const String _windowsTokenExpiryKey = 'ej_windows_token_expiry';
  static const String _windowsUserEmailKey = 'ej_windows_user_email';
  static const String _windowsUserNameKey = 'ej_windows_user_name';

  String? _windowsAccessToken;
  String? _windowsRefreshToken;
  DateTime? _windowsTokenExpiry;
  String? _windowsUserEmail;
  String? _windowsUserName;

  GoogleSignIn? _googleSignInInstance;
  GoogleSignIn get _googleSignIn {
    return _googleSignInInstance ??= GoogleSignIn(
      clientId: (Platform.isIOS || Platform.isMacOS) ? '803570972313-hm9441otq7pmpu0qv42lp0rlrpq335bj.apps.googleusercontent.com' : null,
      scopes: [
        'email',
        'https://www.googleapis.com/auth/drive',
      ],
    );
  }

  GoogleSignInAccount? _currentUser;
  GoogleSignInAccount? get currentUser => _currentUser;
  bool get isSignedIn => Platform.isWindows
      ? (_windowsAccessToken != null && _windowsAccessToken!.isNotEmpty)
      : (_currentUser != null);
  String? get userEmail => Platform.isWindows ? _windowsUserEmail : _currentUser?.email;
  String? get userDisplayName => Platform.isWindows ? _windowsUserName : _currentUser?.displayName;
  String? lastError;

  final Map<String, String> _folderIdCache = {};
  final Map<String, Future<String>> _inFlightFolders = {};

  // Inicialización y recuperación de sesión previa silenciosa
  Future<bool> initSilently() async {
    try {
      await _loadFolderCache();
      if (Platform.isWindows) {
        return await _initWindowsSilently();
      }
      final account = await _googleSignIn.signInSilently();
      _currentUser = account;
      return account != null;
    } catch (e) {
      debugPrint('Error en silent sign in: $e');
      return false;
    }
  }

  Future<bool> _initWindowsSilently() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _windowsRefreshToken = prefs.getString(_windowsRefreshTokenKey);
      _windowsAccessToken = prefs.getString(_windowsAccessTokenKey);
      _windowsUserEmail = prefs.getString(_windowsUserEmailKey);
      _windowsUserName = prefs.getString(_windowsUserNameKey);
      final exp = prefs.getString(_windowsTokenExpiryKey);
      if (exp != null) _windowsTokenExpiry = DateTime.tryParse(exp);

      if (_windowsRefreshToken == null || _windowsRefreshToken!.isEmpty) {
        return false;
      }

      if (_windowsAccessToken == null || _windowsTokenExpiry == null || DateTime.now().isAfter(_windowsTokenExpiry!.subtract(const Duration(minutes: 5)))) {
        return await _refreshWindowsToken();
      }

      return true;
    } catch (e) {
      debugPrint('Error en _initWindowsSilently: $e');
      return false;
    }
  }

  Future<bool> _refreshWindowsToken() async {
    if (_windowsRefreshToken == null || _windowsRefreshToken!.isEmpty) return false;
    try {
      final response = await http.post(
        Uri.parse('https://oauth2.googleapis.com/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': _windowsClientId,
          'client_secret': _windowsClientSecret,
          'refresh_token': _windowsRefreshToken!,
          'grant_type': 'refresh_token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _windowsAccessToken = data['access_token'];
        final exp = data['expires_in'] as int? ?? 3600;
        _windowsTokenExpiry = DateTime.now().add(Duration(seconds: exp));

        final prefs = await SharedPreferences.getInstance();
        if (_windowsAccessToken != null) await prefs.setString(_windowsAccessTokenKey, _windowsAccessToken!);
        if (_windowsTokenExpiry != null) await prefs.setString(_windowsTokenExpiryKey, _windowsTokenExpiry!.toIso8601String());
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error refrescando token en Windows: $e');
      return false;
    }
  }

  // Iniciar sesión con Google (Interactivo)
  Future<GoogleSignInAccount?> signIn() async {
    lastError = null;
    if (Platform.isWindows) {
      final ok = await _signInWindows();
      if (ok) {
        processQueue();
        final prefs = await SharedPreferences.getInstance();
        final rawClients = prefs.getString('ej_saved_clients_list');
        final rawReports = prefs.getString('ej_reports_history_list');
        final bool hasLocalData = (rawClients != null && rawClients.isNotEmpty && rawClients != '[]') ||
            (rawReports != null && rawReports.isNotEmpty && rawReports != '[]');
        if (!hasLocalData) {
          debugPrint('Dispositivo sin datos locales. Auto-restaurando desde Google Drive...');
          await restoreDatabaseFromCloud();
        } else {
          backupDatabaseToCloud();
        }
      }
      return null;
    }

    try {
      final account = await _googleSignIn.signIn();
      _currentUser = account;
      if (account != null) {
        processQueue();
        final prefs = await SharedPreferences.getInstance();
        final rawClients = prefs.getString('ej_saved_clients_list');
        final rawReports = prefs.getString('ej_reports_history_list');
        final bool hasLocalData = (rawClients != null && rawClients.isNotEmpty && rawClients != '[]') ||
            (rawReports != null && rawReports.isNotEmpty && rawReports != '[]');
        if (!hasLocalData) {
          debugPrint('Dispositivo sin datos locales. Auto-restaurando desde Google Drive...');
          await restoreDatabaseFromCloud();
        } else {
          backupDatabaseToCloud();
        }
      } else {
        lastError = 'La ventana de selección se cerró sin seleccionar una cuenta.';
      }
      return account;
    } catch (e, stack) {
      lastError = 'Error: $e';
      debugPrint('Error al iniciar sesión con Google: $e\n$stack');
      return null;
    }
  }

  Future<bool> _signInWindows() async {
    HttpServer? server;
    try {
      try {
        server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8585);
      } catch (_) {
        server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      }
      final port = server.port;
      final redirectUri = 'http://127.0.0.1:$port';

      final authUri = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
        'client_id': _windowsClientId,
        'redirect_uri': redirectUri,
        'response_type': 'code',
        'scope': 'email profile https://www.googleapis.com/auth/drive',
        'access_type': 'offline',
        'prompt': 'consent',
      });

      await launchUrl(authUri, mode: LaunchMode.externalApplication);

      String? authCode;
      await for (final request in server.timeout(const Duration(minutes: 3))) {
        if (request.uri.path == '/' || request.uri.queryParameters.containsKey('code')) {
          authCode = request.uri.queryParameters['code'];
          request.response.headers.contentType = ContentType.html;
          request.response.write('''
            <!DOCTYPE html>
            <html>
            <head><meta charset="utf-8"><title>EJ Exterminadores - Conectado</title></head>
            <body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; text-align: center; padding: 60px 20px; background-color: #f8fafc;">
              <div style="max-width: 480px; margin: 0 auto; background: white; padding: 40px; border-radius: 12px; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.1); border: 1px solid #e2e8f0;">
                <h2 style="color: #0F2B48; margin-top: 0;">¡Google Drive Conectado con Éxito!</h2>
                <p style="color: #475569; font-size: 15px; line-height: 1.5;">Tu cuenta ha sido vinculada a <strong>EJ Exterminadores</strong>. Ya puedes cerrar esta ventana y regresar a la aplicación de escritorio.</p>
              </div>
            </body>
            </html>
          ''');
          await request.response.close();
          break;
        } else {
          request.response.statusCode = 404;
          await request.response.close();
        }
      }
      await server.close();

      if (authCode == null || authCode.isEmpty) {
        lastError = 'No se recibió el código de autorización.';
        return false;
      }

      final tokenResponse = await http.post(
        Uri.parse('https://oauth2.googleapis.com/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': _windowsClientId,
          'client_secret': _windowsClientSecret,
          'code': authCode,
          'redirect_uri': redirectUri,
          'grant_type': 'authorization_code',
        },
      );

      if (tokenResponse.statusCode != 200) {
        lastError = 'Error canjeando token: ${tokenResponse.body}';
        debugPrint('Error token: ${tokenResponse.body}');
        return false;
      }

      final tokenData = jsonDecode(tokenResponse.body);
      _windowsAccessToken = tokenData['access_token'];
      _windowsRefreshToken = tokenData['refresh_token'] ?? _windowsRefreshToken;
      final exp = tokenData['expires_in'] as int? ?? 3600;
      _windowsTokenExpiry = DateTime.now().add(Duration(seconds: exp));

      try {
        final userResponse = await http.get(
          Uri.parse('https://www.googleapis.com/oauth2/v3/userinfo'),
          headers: {'Authorization': 'Bearer $_windowsAccessToken'},
        );
        if (userResponse.statusCode == 200) {
          final userData = jsonDecode(userResponse.body);
          _windowsUserEmail = userData['email'];
          _windowsUserName = userData['name'];
        }
      } catch (_) {}

      final prefs = await SharedPreferences.getInstance();
      if (_windowsAccessToken != null) await prefs.setString(_windowsAccessTokenKey, _windowsAccessToken!);
      if (_windowsRefreshToken != null) await prefs.setString(_windowsRefreshTokenKey, _windowsRefreshToken!);
      if (_windowsTokenExpiry != null) await prefs.setString(_windowsTokenExpiryKey, _windowsTokenExpiry!.toIso8601String());
      if (_windowsUserEmail != null) await prefs.setString(_windowsUserEmailKey, _windowsUserEmail!);
      if (_windowsUserName != null) await prefs.setString(_windowsUserNameKey, _windowsUserName!);

      return true;
    } catch (e) {
      server?.close();
      lastError = 'Error al conectar con Google en Windows: $e';
      debugPrint('Error en _signInWindows: $e');
      return false;
    }
  }

  // Cerrar sesión
  Future<void> signOut() async {
    try {
      if (Platform.isWindows) {
        _windowsAccessToken = null;
        _windowsRefreshToken = null;
        _windowsTokenExpiry = null;
        _windowsUserEmail = null;
        _windowsUserName = null;
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_windowsAccessTokenKey);
        await prefs.remove(_windowsRefreshTokenKey);
        await prefs.remove(_windowsTokenExpiryKey);
        await prefs.remove(_windowsUserEmailKey);
        await prefs.remove(_windowsUserNameKey);
      } else {
        await _googleSignIn.signOut();
        _currentUser = null;
      }
      _folderIdCache.clear();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_folderCacheKey);
    } catch (e) {
      debugPrint('Error al cerrar sesión: $e');
    }
  }

  // Re-solicitar inicio de sesión interactivo con permisos completos de Drive
  Future<GoogleSignInAccount?> requestFullDriveAccess() async {
    if (Platform.isWindows) {
      await signOut();
      await signIn();
      return null;
    }
    lastError = null;
    try {
      await _googleSignIn.signOut();
      final account = await _googleSignIn.signIn();
      _currentUser = account;
      if (account != null) {
        processQueue();
        final prefs = await SharedPreferences.getInstance();
        final rawClients = prefs.getString('ej_saved_clients_list');
        final rawReports = prefs.getString('ej_reports_history_list');
        final bool hasLocalData = (rawClients != null && rawClients.isNotEmpty && rawClients != '[]') ||
            (rawReports != null && rawReports.isNotEmpty && rawReports != '[]');
        if (!hasLocalData) {
          await restoreDatabaseFromCloud();
        } else {
          backupDatabaseToCloud();
        }
      }
      return account;
    } catch (e) {
      debugPrint('Error solicitando permisos completos de Drive: $e');
      return null;
    }
  }

  // Obtener cliente autenticado de Google Drive
  Future<drive.DriveApi?> _getDriveApi() async {
    if (Platform.isWindows) {
      if (_windowsAccessToken == null || _windowsTokenExpiry == null || DateTime.now().isAfter(_windowsTokenExpiry!.subtract(const Duration(minutes: 5)))) {
        await _initWindowsSilently();
      }
      if (_windowsAccessToken == null || _windowsAccessToken!.isEmpty) {
        return null;
      }
      final authClient = _GoogleAuthClient({'Authorization': 'Bearer $_windowsAccessToken'});
      return drive.DriveApi(authClient);
    }

    if (_currentUser == null) {
      await initSilently();
      if (_currentUser == null) return null;
    }

    try {
      final authHeaders = await _currentUser!.authHeaders;
      final authClient = _GoogleAuthClient(authHeaders);
      return drive.DriveApi(authClient);
    } catch (e) {
      debugPrint('Error al obtener DriveApi: $e');
      return null;
    }
  }

  // --- GESTIÓN DE CARPETAS EN GOOGLE DRIVE ---

  Future<void> _loadFolderCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_folderCacheKey);
      if (raw != null && raw.isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(raw);
        _folderIdCache.clear();
        decoded.forEach((key, val) => _folderIdCache[key] = val.toString());
      }
    } catch (_) {}
  }

  Future<void> _saveFolderCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_folderCacheKey, jsonEncode(_folderIdCache));
    } catch (_) {}
  }

  Future<String> _getOrCreateFolder(drive.DriveApi api, String folderName, {String? parentId}) async {
    final cacheKey = '${parentId ?? "root"}_$folderName';

    // Si ya hay una solicitud en curso para esta misma carpeta, reusar el Future para evitar concurrencia
    if (_inFlightFolders.containsKey(cacheKey)) {
      return await _inFlightFolders[cacheKey]!;
    }

    final future = _doGetOrCreateFolder(api, folderName, parentId: parentId);
    _inFlightFolders[cacheKey] = future;
    try {
      return await future;
    } finally {
      _inFlightFolders.remove(cacheKey);
    }
  }

  Future<String> _doGetOrCreateFolder(drive.DriveApi api, String folderName, {String? parentId}) async {
    final cacheKey = '${parentId ?? "root"}_$folderName';
    if (_folderIdCache.containsKey(cacheKey)) {
      final cachedId = _folderIdCache[cacheKey]!;
      try {
        await api.files.get(cachedId, $fields: 'id, trashed');
        return cachedId;
      } catch (_) {
        _folderIdCache.remove(cacheKey);
      }
    }

    // Buscar si ya existe en Drive (escapando comillas simples)
    final safeName = folderName.replaceAll("'", r"\'");
    String q = "mimeType = 'application/vnd.google-apps.folder' and name = '$safeName' and trashed = false";
    if (parentId != null) {
      q += " and '$parentId' in parents";
    }

    try {
      final searchResult = await api.files.list(q: q, $fields: 'files(id, name)');
      if (searchResult.files != null && searchResult.files!.isNotEmpty) {
        final existingId = searchResult.files!.first.id!;
        _folderIdCache[cacheKey] = existingId;
        _saveFolderCache();
        return existingId;
      }
    } catch (e) {
      debugPrint('Error buscando carpeta $folderName: $e');
    }

    // Crear la carpeta si no existe
    final folderMetadata = drive.File()
      ..name = folderName
      ..mimeType = 'application/vnd.google-apps.folder';

    if (parentId != null) {
      folderMetadata.parents = [parentId];
    }

    final created = await api.files.create(folderMetadata, $fields: 'id, name');
    final newId = created.id!;
    _folderIdCache[cacheKey] = newId;
    _saveFolderCache();
    return newId;
  }

  // Obtener carpeta raíz "EJ Exterminadores"
  Future<String?> _getRootFolderId(drive.DriveApi api) async {
    try {
      return await _getOrCreateFolder(api, 'EJ Exterminadores');
    } catch (e) {
      debugPrint('Error creando carpeta raíz: $e');
      return null;
    }
  }

  // Obtener carpeta "Clientes" dentro de "EJ Exterminadores"
  Future<String?> _getClientsRootFolderId(drive.DriveApi api) async {
    final rootId = await _getRootFolderId(api);
    if (rootId == null) return null;
    return await _getOrCreateFolder(api, 'Clientes', parentId: rootId);
  }

  // Obtener o crear la carpeta específica del cliente (Normalizada)
  Future<String?> _getClientFolderId(drive.DriveApi api, String clientName) async {
    final clientsRootId = await _getClientsRootFolderId(api);
    if (clientsRootId == null) return null;

    String resolvedName = clientName.trim();
    if (resolvedName.isEmpty) resolvedName = 'Cliente General';

    // Normalizar contra el catálogo guardado de clientes
    try {
      final clients = await ClientService().getSavedClients();
      final match = clients.firstWhere(
        (c) => c.businessName.trim().toLowerCase() == resolvedName.toLowerCase(),
        orElse: () => clients.firstWhere(
          (c) => c.contactName.trim().toLowerCase() == resolvedName.toLowerCase(),
          orElse: () => ClientModel(id: '', businessName: '', contactName: '', address: '', phone: '', email: '', facilityType: '', hasTraps: false),
        ),
      );
      if (match.businessName.trim().isNotEmpty) {
        resolvedName = match.businessName.trim();
      }
    } catch (_) {}

    return await _getOrCreateFolder(api, resolvedName, parentId: clientsRootId);
  }

  // Obtener subcarpeta por categoría (Reportes, Cotizaciones, Contratos, Planos, Facturas)
  Future<String?> _getCategoryFolderId(drive.DriveApi api, String clientName, String documentType) async {
    final clientFolderId = await _getClientFolderId(api, clientName);
    if (clientFolderId == null) return null;

    String subfolderName = '1_Reportes_de_Servicio';
    if (documentType.contains('Cotiz')) subfolderName = '2_Cotizaciones';
    if (documentType.contains('Contrat')) subfolderName = '3_Contratos';
    if (documentType.contains('Cronograma') || documentType.contains('Agenda')) subfolderName = '4_Cronogramas_de_Servicio';
    if (documentType.contains('Plano') || documentType.contains('Layout')) subfolderName = '4_Planos_y_Layouts';
    if (documentType.contains('Factur')) subfolderName = '5_Facturas';

    return await _getOrCreateFolder(api, subfolderName, parentId: clientFolderId);
  }

  // Obtener carpeta raíz "5_Facturas" dentro de un cliente
  Future<String?> _getClientInvoicesRootFolderId(drive.DriveApi api, String clientName) async {
    final clientFolderId = await _getClientFolderId(api, clientName);
    if (clientFolderId == null) return null;
    return await _getOrCreateFolder(api, '5_Facturas', parentId: clientFolderId);
  }

  // Obtener subcarpeta de estado de facturas (Pendientes_de_Pago, Pagadas, Canceladas)
  Future<String?> getClientInvoiceStatusFolderId(drive.DriveApi api, String clientName, String status) async {
    final invRootId = await _getClientInvoicesRootFolderId(api, clientName);
    if (invRootId == null) return null;

    String subName = 'Pendientes_de_Pago';
    final s = status.toLowerCase();
    if (s.contains('pagad') || s == 'paid') subName = 'Pagadas';
    if (s.contains('cancel') || s == 'canceled') subName = 'Canceladas';

    return await _getOrCreateFolder(api, subName, parentId: invRootId);
  }

  // Asegura que las 3 subcarpetas de Facturas existan para un cliente en Google Drive
  Future<void> ensureInvoiceFoldersExist(String clientName) async {
    final api = await _getDriveApi();
    if (api == null) return;
    try {
      final invRootId = await _getClientInvoicesRootFolderId(api, clientName);
      if (invRootId != null) {
        await _getOrCreateFolder(api, 'Pendientes_de_Pago', parentId: invRootId);
        await _getOrCreateFolder(api, 'Pagadas', parentId: invRootId);
        await _getOrCreateFolder(api, 'Canceladas', parentId: invRootId);
      }
    } catch (e) {
      debugPrint('Error creando subcarpetas de facturas: $e');
    }
  }

  /// Crea la estructura de facturación (5_Facturas con Pendientes_de_Pago, Pagadas y Canceladas)
  /// para TODOS los clientes existentes (tanto en la base de datos local como en Google Drive).
  Future<int> ensureInvoiceFoldersForAllClients({Function(String status, double progress)? onProgress}) async {
    final api = await _getDriveApi();
    if (api == null) return 0;

    int totalProcessed = 0;
    try {
      final clientsRootId = await _getClientsRootFolderId(api);
      if (clientsRootId == null) return 0;

      // 1. Obtener nombres de clientes desde catálogo local
      final localClients = await ClientService().getSavedClients();
      final Set<String> clientNames = {};
      for (final c in localClients) {
        if (c.businessName.trim().isNotEmpty) {
          clientNames.add(c.businessName.trim());
        }
      }

      // 2. Obtener clientes que ya existan físicamente en Google Drive
      try {
        final driveFolders = await api.files.list(
          q: "'$clientsRootId' in parents and mimeType = 'application/vnd.google-apps.folder' and trashed = false",
          $fields: 'files(id, name)',
          pageSize: 500,
        );
        for (final f in (driveFolders.files ?? [])) {
          if (f.name != null && f.name!.trim().isNotEmpty) {
            clientNames.add(f.name!.trim());
          }
        }
      } catch (_) {}

      final list = clientNames.toList();
      if (list.isEmpty) return 0;

      for (int i = 0; i < list.length; i++) {
        final name = list[i];
        onProgress?.call('Preparando carpetas de facturas para "$name"...', (i + 1) / list.length);
        final invRootId = await _getClientInvoicesRootFolderId(api, name);
        if (invRootId != null) {
          await _getOrCreateFolder(api, 'Pendientes_de_Pago', parentId: invRootId);
          await _getOrCreateFolder(api, 'Pagadas', parentId: invRootId);
          await _getOrCreateFolder(api, 'Canceladas', parentId: invRootId);
          totalProcessed++;
        }
      }
      onProgress?.call('¡Estructura de facturas lista para $totalProcessed clientes!', 1.0);
    } catch (e) {
      debugPrint('Error en ensureInvoiceFoldersForAllClients: $e');
    }
    return totalProcessed;
  }

  // --- ENLACE PÚBLICO DE SOLO LECTURA PARA EL CLIENTE ---

  // Genera un enlace permanente de "Solo Lectura" de la carpeta del cliente en Drive
  Future<String?> getOrCreateClientFolderShareLink(String clientName) async {
    final api = await _getDriveApi();
    if (api == null) return null;

    try {
      final clientFolderId = await _getClientFolderId(api, clientName);
      if (clientFolderId == null) return null;

      // Asignar permiso de lectura pública al enlace
      final permission = drive.Permission()
        ..type = 'anyone'
        ..role = 'reader';

      try {
        await api.permissions.create(permission, clientFolderId);
      } catch (_) {
        // Puede que ya tenga el permiso asignado
      }

      // Obtener el enlace webViewLink
      final folderMeta = await api.files.get(
        clientFolderId,
        $fields: 'id, name, webViewLink',
      ) as drive.File;

      final shareUrl = folderMeta.webViewLink;

      if (shareUrl != null && shareUrl.isNotEmpty) {
        // Actualizar el cliente en el ClientService
        final clientService = ClientService();
        final clients = await clientService.getSavedClients();
        final idx = clients.indexWhere((c) => c.businessName.trim().toLowerCase() == clientName.trim().toLowerCase());
        if (idx >= 0) {
          final updated = clients[idx].copyWith(
            driveFolderId: clientFolderId,
            driveFolderShareUrl: shareUrl,
          );
          await clientService.saveClient(updated, syncToCloud: false);
        }
      }

      return shareUrl;
    } catch (e) {
      debugPrint('Error creando enlace para cliente $clientName: $e');
      return null;
    }
  }

  // --- SUBIDA DE ARCHIVOS A GOOGLE DRIVE (CON ANTI-DUPLICADOS) ---

  // Subir un archivo de documento (PDF)
  Future<String?> uploadDocumentFile({
    required String clientName,
    required String documentType,
    required String folio,
    required File localFile,
    required String targetFileName,
  }) async {
    final api = await _getDriveApi();
    if (api == null) return null;

    try {
      final targetFolderId = await _getCategoryFolderId(api, clientName, documentType);
      if (targetFolderId == null) return null;

      // Verificar si ya existe un archivo con ese nombre en esa carpeta (Anti-duplicados)
      final safeName = targetFileName.replaceAll("'", r"\'");
      final existingFiles = await api.files.list(
        q: "'$targetFolderId' in parents and name = '$safeName' and trashed = false",
        $fields: 'files(id, name, createdTime)',
      );

      final media = drive.Media(localFile.openRead(), localFile.lengthSync());

      drive.File uploaded;
      if (existingFiles.files != null && existingFiles.files!.isNotEmpty) {
        // ACTUALIZAR ARCHIVO EXISTENTE (NO DUPLICAR)
        final primaryId = existingFiles.files!.first.id!;
        uploaded = await api.files.update(
          drive.File(),
          primaryId,
          uploadMedia: media,
          $fields: 'id, name, webViewLink',
        );

        // Si ya existían copias repetidas previas, eliminar los duplicados sobrantes
        for (int i = 1; i < existingFiles.files!.length; i++) {
          try {
            await api.files.delete(existingFiles.files![i].id!);
          } catch (_) {}
        }
      } else {
        // CREAR ARCHIVO NUEVO
        final fileMetadata = drive.File()
          ..name = targetFileName
          ..parents = [targetFolderId];

        uploaded = await api.files.create(
          fileMetadata,
          uploadMedia: media,
          $fields: 'id, name, webViewLink',
        );
      }

      // Si el cliente no tiene enlace público guardado, generarlo en segundo plano
      getOrCreateClientFolderShareLink(clientName);

      return uploaded.webViewLink;
    } catch (e) {
      debugPrint('Error subiendo documento a Drive: $e');
      return null;
    }
  }

  // --- COLA OFFLINE (OFFLINE-FIRST) ---

  // Registrar un archivo en la cola y procesar si hay internet
  Future<void> enqueueAndSync({
    required String clientName,
    required String documentType,
    required String folio,
    required String localFilePath,
    required String fileName,
  }) async {
    final item = CloudSyncItemModel(
      id: 'sync_${DateTime.now().millisecondsSinceEpoch}',
      clientName: clientName,
      documentType: documentType,
      folio: folio,
      fileName: fileName,
      localFilePath: localFilePath,
      status: 'pending',
      createdAt: DateTime.now(),
    );

    await _enqueueItem(item);

    // Intentar sincronizar de inmediato en segundo plano
    processQueue();
  }

  Future<List<CloudSyncItemModel>> getQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_queueStorageKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final List<dynamic> list = jsonDecode(raw);
      return list.map((item) => CloudSyncItemModel.fromMap(item)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveQueue(List<CloudSyncItemModel> queue) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(queue.map((q) => q.toMap()).toList());
    await prefs.setString(_queueStorageKey, encoded);
  }

  Future<void> _enqueueItem(CloudSyncItemModel item) async {
    final queue = await getQueue();
    // Evitar duplicados por mismo archivo y folio
    final existingIdx = queue.indexWhere((q) => q.folio == item.folio && q.documentType == item.documentType);
    if (existingIdx >= 0) {
      queue[existingIdx] = item;
    } else {
      queue.add(item);
    }
    await _saveQueue(queue);
  }

  // Procesar cola en segundo plano
  Future<void> processQueue() async {
    final api = await _getDriveApi();
    if (api == null) return;

    final queue = await getQueue();
    final pendingItems = queue.where((q) => q.status == 'pending' || q.status == 'error').toList();

    for (final item in pendingItems) {
      final file = File(item.localFilePath);
      if (!file.existsSync()) {
        item.status = 'error';
        item.errorMessage = 'El archivo local ya no existe.';
        continue;
      }

      item.status = 'uploading';
      await _saveQueue(queue);

      try {
        final link = await uploadDocumentFile(
          clientName: item.clientName,
          documentType: item.documentType,
          folio: item.folio,
          localFile: file,
          targetFileName: item.fileName,
        );

        if (link != null) {
          item.status = 'synced';
          item.syncedAt = DateTime.now();
          item.driveWebViewLink = link;
          item.errorMessage = null;
        } else {
          item.status = 'error';
          item.errorMessage = 'No se pudo subir a Drive.';
        }
      } catch (e) {
        item.status = 'error';
        item.errorMessage = e.toString();
      }

      await _saveQueue(queue);
    }

    // Si se subió algún archivo, actualizar automáticamente el respaldo maestro en Drive
    if (pendingItems.any((i) => i.status == 'synced')) {
      await backupDatabaseToCloud(force: true);
    }
  }

  // --- RESPALDO MAESTRO DE BASE DE DATOS A GOOGLE DRIVE ---

  Future<bool> backupDatabaseToCloud({bool force = false}) async {
    final api = await _getDriveApi();
    if (api == null) return false;

    try {
      final prefs = await SharedPreferences.getInstance();
      final rawClients = prefs.getString('ej_saved_clients_list');
      final rawReports = prefs.getString('ej_reports_history_list');
      final rawQuotes = prefs.getString('ej_quotes_history_list');
      final rawContracts = prefs.getString('ej_contracts_history_list');

      int count(String? raw) {
        if (raw == null || raw.isEmpty || raw == '[]') return 0;
        try {
          final d = jsonDecode(raw);
          if (d is List) return d.length;
        } catch (_) {}
        return 0;
      }

      final int localCount = count(rawClients) + count(rawReports) + count(rawQuotes) + count(rawContracts);

      // Si el dispositivo local está vacío y no se está forzando, NO sobreescribir la nube para proteger el respaldo
      if (localCount == 0 && !force) {
        debugPrint('backupDatabaseToCloud omitido: este dispositivo está vacío y no debe sobreescribir la nube.');
        return false;
      }

      final rootId = await _getRootFolderId(api);
      if (rootId == null) return false;

      final backupFolderId = await _getOrCreateFolder(api, 'Respaldo_Sistema_App', parentId: rootId);

      final allKeys = prefs.getKeys();
      final Map<String, dynamic> snapshot = {};

      for (final key in allKeys) {
        // Excluir claves de caché temporal
        if (key == _folderCacheKey) continue;
        final val = prefs.get(key);
        snapshot[key] = val;
      }

      final jsonContent = jsonEncode({
        'version': 1,
        'appName': 'EJ Reportes',
        'backupDate': DateTime.now().toIso8601String(),
        'accountEmail': userEmail ?? '',
        'data': snapshot,
      });

      final tempDir = await getTemporaryDirectory();
      final backupFile = File('${tempDir.path}/ej_reportes_base_datos.json');
      await backupFile.writeAsString(jsonContent);

      // Buscar si ya existe el archivo de respaldo para sobreescribir/actualizar
      final q = "name = 'ej_reportes_base_datos.json' and '$backupFolderId' in parents and trashed = false";
      final search = await api.files.list(q: q, $fields: 'files(id)');

      final media = drive.Media(backupFile.openRead(), backupFile.lengthSync());

      if (search.files != null && search.files!.isNotEmpty) {
        final existingFileId = search.files!.first.id!;
        await api.files.update(drive.File(), existingFileId, uploadMedia: media);
      } else {
        final newFileMeta = drive.File()
          ..name = 'ej_reportes_base_datos.json'
          ..parents = [backupFolderId];
        await api.files.create(newFileMeta, uploadMedia: media);
      }

      await prefs.setString(_lastBackupDateKey, DateTime.now().toIso8601String());
      return true;
    } catch (e) {
      debugPrint('Error respaldando base de datos a Drive: $e');
      return false;
    }
  }

  // Restaurar base de datos desde Google Drive en otro dispositivo
  Future<DatabaseRestoreResult> restoreDatabaseFromCloud() async {
    final api = await _getDriveApi();
    if (api == null) {
      return const DatabaseRestoreResult(
        success: false,
        message: 'No hay conexión activa con Google Drive. Inicia sesión primero.',
      );
    }

    try {
      final rootId = await _getRootFolderId(api);
      if (rootId == null) {
        return const DatabaseRestoreResult(
          success: false,
          message: 'No se pudo acceder a la carpeta de EJ Exterminadores en Drive.',
        );
      }

      final backupFolderId = await _getOrCreateFolder(api, 'Respaldo_Sistema_App', parentId: rootId);

      // Buscar el archivo de respaldo en la carpeta oficial o en cualquier parte del Drive
      String q = "name = 'ej_reportes_base_datos.json' and '$backupFolderId' in parents and trashed = false";
      var search = await api.files.list(q: q, $fields: 'files(id, name, modifiedTime)');

      if (search.files == null || search.files!.isEmpty) {
        search = await api.files.list(
          q: "name = 'ej_reportes_base_datos.json' and trashed = false",
          $fields: 'files(id, name, modifiedTime)',
        );
      }

      if (search.files == null || search.files!.isEmpty) {
        return const DatabaseRestoreResult(
          success: false,
          message: 'No se encontró archivo de respaldo maestro en tu Google Drive.\n\nPor favor abre la app en tu teléfono celular (donde tienes tus clientes y reportes), entra a "Nube Google Drive" y pulsa "Respaldar Base de Datos Maestra" para subirlo a la nube.',
        );
      }

      final fileId = search.files!.first.id!;

      Future<Map<String, dynamic>?> downloadAndParse(drive.Media mediaStream) async {
        try {
          final List<int> bytes = [];
          await for (final chunk in mediaStream.stream) {
            bytes.addAll(chunk);
          }
          final content = utf8.decode(bytes);
          final Map<String, dynamic> parsed = jsonDecode(content);
          return parsed['data'] != null ? Map<String, dynamic>.from(parsed['data']) : null;
        } catch (_) {
          return null;
        }
      }

      final drive.Media mainDownloaded = await api.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      Map<String, dynamic>? data = await downloadAndParse(mainDownloaded);

      int countItems(dynamic raw) {
        if (raw == null) return 0;
        if (raw is List) return raw.length;
        if (raw is String && raw.isNotEmpty && raw != '[]') {
          try {
            final decoded = jsonDecode(raw);
            if (decoded is List) return decoded.length;
          } catch (_) {}
        }
        return 0;
      }

      int clients = countItems(data?['ej_saved_clients_list']);
      int reports = countItems(data?['ej_reports_history_list']);
      int quotes = countItems(data?['ej_quotes_history_list']);
      int contracts = countItems(data?['ej_contracts_history_list']);

      // Si la versión actual está vacía (ej. si el Mac sin datos la sobreescribió al conectar),
      // buscar automáticamente en el historial de revisiones de Google Drive
      if (clients == 0 && reports == 0 && quotes == 0) {
        try {
          final revs = await api.revisions.list(fileId);
          if (revs.revisions != null && revs.revisions!.isNotEmpty) {
            for (final rev in revs.revisions!.reversed) {
              if (rev.id == null) continue;
              try {
                final drive.Media revMedia = await api.revisions.get(
                  fileId,
                  rev.id!,
                  downloadOptions: drive.DownloadOptions.fullMedia,
                ) as drive.Media;

                final revData = await downloadAndParse(revMedia);
                final c = countItems(revData?['ej_saved_clients_list']);
                final r = countItems(revData?['ej_reports_history_list']);
                final q = countItems(revData?['ej_quotes_history_list']);
                final k = countItems(revData?['ej_contracts_history_list']);

                if (c > 0 || r > 0 || q > 0) {
                  data = revData;
                  clients = c;
                  reports = r;
                  quotes = q;
                  contracts = k;
                  debugPrint('¡Recuperada versión previa con $c clientes y $r reportes!');
                  break;
                }
              } catch (_) {}
            }
          }
        } catch (e) {
          debugPrint('Error inspeccionando revisiones de Drive: $e');
        }
      }

      if (data == null || (clients == 0 && reports == 0 && quotes == 0 && contracts == 0)) {
        return const DatabaseRestoreResult(
          success: false,
          message: 'El archivo de respaldo en tu Drive aún no contiene clientes ni reportes.\n\nPor favor ve a tu teléfono (donde tienes tus datos), abre la app en "Nube Google Drive" y pulsa "Respaldar Base de Datos Maestra".',
        );
      }

      final prefs = await SharedPreferences.getInstance();
      for (final entry in data.entries) {
        final key = entry.key;
        final val = entry.value;

        if (val is String) {
          await prefs.setString(key, val);
        } else if (val is int) {
          await prefs.setInt(key, val);
        } else if (val is bool) {
          await prefs.setBool(key, val);
        } else if (val is double) {
          await prefs.setDouble(key, val);
        } else if (val is List) {
          await prefs.setStringList(key, val.map((e) => e.toString()).toList());
        }
      }

      return DatabaseRestoreResult(
        success: true,
        message: '¡Datos restaurados con éxito!\n\n• $clients Clientes\n• $reports Reportes de servicio\n• $quotes Cotizaciones\n• $contracts Pólizas y Contratos',
        clientsCount: clients,
        reportsCount: reports,
        quotesCount: quotes,
        contractsCount: contracts,
      );
    } catch (e) {
      debugPrint('Error restaurando base de datos desde Drive: $e');
      return DatabaseRestoreResult(
        success: false,
        message: 'Error al procesar la restauración: $e',
      );
    }
  }

  // --- MÉTODOS DE FUSIÓN Y SINCRONIZACIÓN BIDIRECCIONAL ---

  /// Descarga el respaldo maestro desde Google Drive y fusiona bidireccionalmente
  /// clientes, reportes, cotizaciones, contratos y cronogramas sin borrar datos locales.
  Future<bool> pullAndMergeCloudDatabase({Function(String status, double progress)? onProgress}) async {
    final api = await _getDriveApi();
    if (api == null) return false;

    try {
      final rootId = await _getRootFolderId(api);
      if (rootId == null) return false;

      final backupFolderId = await _getOrCreateFolder(api, 'Respaldo_Sistema_App', parentId: rootId);

      onProgress?.call('Buscando respaldo maestro en Google Drive...', 0.02);

      String q = "name = 'ej_reportes_base_datos.json' and '$backupFolderId' in parents and trashed = false";
      var search = await api.files.list(q: q, $fields: 'files(id, name, modifiedTime)');

      if (search.files == null || search.files!.isEmpty) {
        search = await api.files.list(
          q: "name = 'ej_reportes_base_datos.json' and trashed = false",
          $fields: 'files(id, name, modifiedTime)',
        );
      }

      if (search.files == null || search.files!.isEmpty) return false;

      final fileId = search.files!.first.id!;

      Future<Map<String, dynamic>?> downloadAndParse(drive.Media mediaStream) async {
        try {
          final List<int> bytes = [];
          await for (final chunk in mediaStream.stream) {
            bytes.addAll(chunk);
          }
          final content = utf8.decode(bytes);
          final Map<String, dynamic> parsed = jsonDecode(content);
          return parsed['data'] != null ? Map<String, dynamic>.from(parsed['data']) : null;
        } catch (_) {
          return null;
        }
      }

      final drive.Media mainDownloaded = await api.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      Map<String, dynamic>? cloudData = await downloadAndParse(mainDownloaded);

      int countItems(dynamic raw) {
        if (raw == null) return 0;
        if (raw is List) return raw.length;
        if (raw is String && raw.isNotEmpty && raw != '[]') {
          try {
            final decoded = jsonDecode(raw);
            if (decoded is List) return decoded.length;
          } catch (_) {}
        }
        return 0;
      }

      int cloudClients = countItems(cloudData?['ej_saved_clients_list']);
      int cloudReports = countItems(cloudData?['ej_reports_history_list']);
      int cloudQuotes = countItems(cloudData?['ej_quotes_history_list']);

      if (cloudClients == 0 && cloudReports == 0 && cloudQuotes == 0) {
        try {
          final revs = await api.revisions.list(fileId);
          if (revs.revisions != null && revs.revisions!.isNotEmpty) {
            for (final rev in revs.revisions!.reversed) {
              if (rev.id == null) continue;
              try {
                final drive.Media revMedia = await api.revisions.get(
                  fileId,
                  rev.id!,
                  downloadOptions: drive.DownloadOptions.fullMedia,
                ) as drive.Media;
                final revData = await downloadAndParse(revMedia);
                if (countItems(revData?['ej_saved_clients_list']) > 0 ||
                    countItems(revData?['ej_reports_history_list']) > 0 ||
                    countItems(revData?['ej_quotes_history_list']) > 0) {
                  cloudData = revData;
                  break;
                }
              } catch (_) {}
            }
          }
        } catch (_) {}
      }

      if (cloudData == null) return false;

      final prefs = await SharedPreferences.getInstance();

      // 1. Fusionar Cotizaciones
      _mergeJsonLists(
        prefs: prefs,
        key: 'ej_quotes_history_list',
        cloudRaw: cloudData['ej_quotes_history_list'],
        uniqueKey: 'folio',
      );

      // 2. Fusionar Reportes
      _mergeJsonLists(
        prefs: prefs,
        key: 'ej_reports_history_list',
        cloudRaw: cloudData['ej_reports_history_list'],
        uniqueKey: 'folio',
      );

      // 3. Fusionar Contratos
      _mergeJsonLists(
        prefs: prefs,
        key: 'ej_contracts_history_list',
        cloudRaw: cloudData['ej_contracts_history_list'],
        uniqueKey: 'folio',
      );

      // 4. Fusionar Clientes
      _mergeClientsList(
        prefs: prefs,
        cloudRaw: cloudData['ej_saved_clients_list'],
      );

      // 5. Fusionar Cronogramas
      _mergeJsonLists(
        prefs: prefs,
        key: 'ej_schedules_history_list',
        cloudRaw: cloudData['ej_schedules_history_list'],
        uniqueKey: 'folio',
      );

      // 6. Fusionar contadores de folios para que el siguiente número sea siempre el más alto
      for (final counterKey in [
        'ej_consecutive_quote_counter',
        'ej_consecutive_folio_counter',
        'ej_consecutive_schedule_counter',
        'ej_contracts_folio_counter',
        'ej_layout_folio_counter',
      ]) {
        final localVal = prefs.getInt(counterKey) ?? 0;
        final cloudVal = (cloudData[counterKey] is int) ? (cloudData[counterKey] as int) : 0;
        if (cloudVal > localVal) {
          await prefs.setInt(counterKey, cloudVal);
        }
      }

      return true;
    } catch (e) {
      debugPrint('Error en pullAndMergeCloudDatabase: $e');
      return false;
    }
  }

  void _mergeJsonLists({
    required SharedPreferences prefs,
    required String key,
    required dynamic cloudRaw,
    required String uniqueKey,
  }) {
    try {
      final localRaw = prefs.getString(key);
      List<dynamic> localList = localRaw != null && localRaw.isNotEmpty ? jsonDecode(localRaw) : [];
      List<dynamic> cloudList = [];
      if (cloudRaw is String && cloudRaw.isNotEmpty) {
        cloudList = jsonDecode(cloudRaw);
      } else if (cloudRaw is List) {
        cloudList = cloudRaw;
      }

      final Map<String, Map<String, dynamic>> map = {};

      for (final item in cloudList) {
        if (item is Map) {
          final u = (item[uniqueKey] ?? '').toString().trim();
          if (u.isNotEmpty) map[u] = Map<String, dynamic>.from(item);
        }
      }

      for (final item in localList) {
        if (item is Map) {
          final u = (item[uniqueKey] ?? '').toString().trim();
          if (u.isNotEmpty) {
            if (!map.containsKey(u)) {
              map[u] = Map<String, dynamic>.from(item);
            } else {
              final localPath = item['filePath'] as String?;
              if (localPath != null && localPath.isNotEmpty && File(localPath).existsSync()) {
                map[u]!['filePath'] = localPath;
              }
            }
          }
        }
      }

      final merged = map.values.toList()
        ..sort((a, b) => (b['savedAt'] ?? b['serviceDate'] ?? b['quoteDate'] ?? '')
            .toString()
            .compareTo((a['savedAt'] ?? a['serviceDate'] ?? a['quoteDate'] ?? '').toString()));

      prefs.setString(key, jsonEncode(merged));
    } catch (e) {
      debugPrint('Error fusionando lista $key: $e');
    }
  }

  void _mergeClientsList({
    required SharedPreferences prefs,
    required dynamic cloudRaw,
  }) {
    try {
      final localRaw = prefs.getString('ej_saved_clients_list');
      List<dynamic> localList = localRaw != null && localRaw.isNotEmpty ? jsonDecode(localRaw) : [];
      List<dynamic> cloudList = [];
      if (cloudRaw is String && cloudRaw.isNotEmpty) {
        cloudList = jsonDecode(cloudRaw);
      } else if (cloudRaw is List) {
        cloudList = cloudRaw;
      }

      final Map<String, Map<String, dynamic>> map = {};

      for (final c in cloudList) {
        if (c is Map) {
          final name = (c['businessName'] ?? c['contactName'] ?? '').toString().trim().toLowerCase();
          final phone = (c['phone'] ?? '').toString().trim();
          final key = '$name-$phone';
          if (key.isNotEmpty && key != '-') map[key] = Map<String, dynamic>.from(c);
        }
      }

      for (final c in localList) {
        if (c is Map) {
          final name = (c['businessName'] ?? c['contactName'] ?? '').toString().trim().toLowerCase();
          final phone = (c['phone'] ?? '').toString().trim();
          final key = '$name-$phone';
          if (key.isNotEmpty && key != '-') {
            if (!map.containsKey(key)) {
              map[key] = Map<String, dynamic>.from(c);
            }
          }
        }
      }

      final merged = map.values.toList();
      prefs.setString('ej_saved_clients_list', jsonEncode(merged));
    } catch (e) {
      debugPrint('Error fusionando clientes: $e');
    }
  }

  /// Escanea Google Drive en busca de archivos PDF de cotizaciones o reportes
  /// que existan en la nube pero no estén en el historial local, e impórtalos automáticamente.
  Future<int> discoverDriveDocuments({Function(String status, double progress)? onProgress}) async {
    final api = await _getDriveApi();
    if (api == null) return 0;

    int discoveredCount = 0;
    try {
      final clientsRootId = await _getClientsRootFolderId(api);
      if (clientsRootId == null) return 0;

      onProgress?.call('Buscando clientes en Google Drive...', 0.04);

      final folderListRes = await api.files.list(
        q: "'$clientsRootId' in parents and mimeType = 'application/vnd.google-apps.folder' and trashed = false",
        $fields: 'files(id, name)',
        pageSize: 500,
      );

      final clientFolders = folderListRes.files ?? [];
      if (clientFolders.isEmpty) return 0;

      final prefs = await SharedPreferences.getInstance();

      final rawQuotes = prefs.getString('ej_quotes_history_list');
      List<dynamic> quotesList = rawQuotes != null && rawQuotes.isNotEmpty ? jsonDecode(rawQuotes) : [];
      final Set<String> existingQuoteFolios = quotesList
          .map((e) => (e['folio'] ?? e['quoteFolio'] ?? '').toString().trim().toLowerCase())
          .toSet();

      final rawReports = prefs.getString('ej_reports_history_list');
      List<dynamic> reportsList = rawReports != null && rawReports.isNotEmpty ? jsonDecode(rawReports) : [];
      final Set<String> existingReportFolios = reportsList
          .map((e) => (e['folio'] ?? e['reportFolio'] ?? '').toString().trim().toLowerCase())
          .toSet();

      bool quotesModified = false;
      bool reportsModified = false;

      for (int i = 0; i < clientFolders.length; i++) {
        final clientFolder = clientFolders[i];
        final clientName = clientFolder.name ?? '';
        if (clientFolder.id == null || clientName.isEmpty) continue;

        onProgress?.call('Escaneando $clientName (${i + 1}/${clientFolders.length})...', 0.05 + (0.05 * ((i + 1) / clientFolders.length)));

        final subFoldersRes = await api.files.list(
          q: "'${clientFolder.id}' in parents and mimeType = 'application/vnd.google-apps.folder' and trashed = false",
          $fields: 'files(id, name)',
          pageSize: 20,
        );

        final subFolders = subFoldersRes.files ?? [];

        for (final sub in subFolders) {
          final subName = (sub.name ?? '').toLowerCase();
          final subId = sub.id;
          if (subId == null) continue;

          if (subName.contains('cotizacion')) {
            final pdfsRes = await api.files.list(
              q: "'$subId' in parents and mimeType = 'application/pdf' and trashed = false",
              $fields: 'files(id, name, createdTime, modifiedTime)',
              pageSize: 100,
            );
            for (final f in pdfsRes.files ?? []) {
              final fileName = f.name ?? '';
              String folio = '';
              final match = RegExp(r'(EJ[-_]COT[-_][\w-]+)', caseSensitive: false).firstMatch(fileName);
              if (match != null) {
                folio = match.group(1)!.replaceAll('_', '-');
              } else {
                folio = fileName.replaceAll('.pdf', '').replaceAll('Cotizacion_', '').replaceAll('Cotización_', '').trim();
              }

              if (folio.isNotEmpty && !existingQuoteFolios.contains(folio.toLowerCase())) {
                existingQuoteFolios.add(folio.toLowerCase());
                final dateStr = (f.createdTime ?? f.modifiedTime ?? DateTime.now()).toIso8601String();
                quotesList.insert(0, {
                  'folio': folio,
                  'businessName': clientName,
                  'clientName': clientName,
                  'clientPhone': '',
                  'clientAddress': '',
                  'clientEmail': '',
                  'quoteDate': dateStr,
                  'validDays': 15,
                  'validUntilDate': DateTime.now().add(const Duration(days: 15)).toIso8601String(),
                  'totalAmount': 0.0,
                  'subtotal': 0.0,
                  'applyIva': false,
                  'filePath': '',
                  'itemsCount': 1,
                  'savedAt': dateStr,
                });
                quotesModified = true;
                discoveredCount++;
              }
            }
          } else if (subName.contains('reporte')) {
            final pdfsRes = await api.files.list(
              q: "'$subId' in parents and mimeType = 'application/pdf' and trashed = false",
              $fields: 'files(id, name, createdTime, modifiedTime)',
              pageSize: 100,
            );
            for (final f in pdfsRes.files ?? []) {
              final fileName = f.name ?? '';
              String folio = '';
              final match = RegExp(r'(EJ[-_][\w-]+)', caseSensitive: false).firstMatch(fileName);
              if (match != null) {
                folio = match.group(1)!.replaceAll('_', '-');
              } else {
                folio = fileName.replaceAll('.pdf', '').replaceAll('Reporte_', '').trim();
              }

              if (folio.isNotEmpty && !existingReportFolios.contains(folio.toLowerCase())) {
                existingReportFolios.add(folio.toLowerCase());
                final dateStr = (f.createdTime ?? f.modifiedTime ?? DateTime.now()).toIso8601String();
                reportsList.insert(0, {
                  'folio': folio,
                  'businessName': clientName,
                  'clientName': clientName,
                  'clientPhone': '',
                  'clientAddress': '',
                  'serviceDate': dateStr,
                  'technicianName': 'Técnico EJ',
                  'targetedPests': [],
                  'filePath': '',
                  'savedAt': dateStr,
                });
                reportsModified = true;
                discoveredCount++;
              }
            }
          }
        }
      }

      if (quotesModified) {
        await prefs.setString('ej_quotes_history_list', jsonEncode(quotesList));
      }
      if (reportsModified) {
        await prefs.setString('ej_reports_history_list', jsonEncode(reportsList));
      }
    } catch (e) {
      debugPrint('Error en discoverDriveDocuments: $e');
    }

    return discoveredCount;
  }

  // --- SINCRONIZACIÓN COMPLETA DE TODO EL HISTORIAL EXISTENTE ---

  Future<Map<String, int>> syncAllHistoryNow({Function(String status, double progress)? onProgress}) async {
    final api = await _getDriveApi();
    if (api == null) return {'reports': 0, 'quotes': 0, 'contracts': 0, 'layouts': 0};

    final prefs = await SharedPreferences.getInstance();
    final tempDir = await getTemporaryDirectory();

    int reportsSynced = 0;
    int quotesSynced = 0;
    int contractsSynced = 0;
    int layoutsSynced = 0;

    // 0. Sincronización Bidireccional (PULL): Descargar y fusionar datos de Google Drive
    onProgress?.call('Descargando y fusionando datos de Google Drive...', 0.02);
    await pullAndMergeCloudDatabase(onProgress: onProgress);

    // 0.5. Descubrir documentos PDF existentes en Drive que falten en el historial local
    onProgress?.call('Escaneando archivos en Google Drive...', 0.06);
    await discoverDriveDocuments(onProgress: onProgress);

    // 1. Sincronizar Reportes de Servicio
    onProgress?.call('Sincronizando Reportes de Servicio...', 0.1);
    final rawReports = prefs.getString('ej_reports_history_list');
    if (rawReports != null && rawReports.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(rawReports);
        for (int i = 0; i < list.length; i++) {
          try {
            final rep = Map<String, dynamic>.from(list[i]);
            final folio = (rep['folio'] ?? 'S_N').toString();
            final cleanFolio = folio.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
            final clientName = (rep['businessName'] ?? rep['clientName'] ?? 'Cliente').toString();
            final filePath = rep['filePath'] as String?;
            final fileName = 'Reporte_$cleanFolio.pdf';

            File? localFile;
            if (filePath != null && File(filePath).existsSync()) {
              localFile = File(filePath);
            } else {
              final appDir = await getApplicationDocumentsDirectory();
              final fallback = File('${appDir.path}/reportes_guardados/$cleanFolio.pdf');
              if (fallback.existsSync()) {
                localFile = fallback;
              }
            }

            if (localFile != null) {
              await uploadDocumentFile(
                clientName: clientName,
                documentType: 'Reporte',
                folio: folio,
                localFile: localFile,
                targetFileName: fileName,
              );
              reportsSynced++;
            }
          } catch (_) {}
          onProgress?.call('Subiendo reportes (${i + 1}/${list.length})...', 0.1 + (0.3 * ((i + 1) / list.length)));
        }
      } catch (_) {}
    }

    // 2. Sincronizar Cotizaciones
    onProgress?.call('Sincronizando Cotizaciones...', 0.45);
    final rawQuotes = prefs.getString('ej_quotes_history_list');
    if (rawQuotes != null && rawQuotes.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(rawQuotes);
        for (int i = 0; i < list.length; i++) {
          try {
            final q = Map<String, dynamic>.from(list[i]);
            final folio = (q['folio'] ?? 'S_N').toString();
            final cleanFolio = folio.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
            final clientName = (q['businessName'] ?? q['clientName'] ?? 'Cliente').toString();
            final filePath = q['filePath'] as String?;
            final fileName = 'Cotizacion_$cleanFolio.pdf';

            File? localFile;
            if (filePath != null && File(filePath).existsSync()) {
              localFile = File(filePath);
            } else {
              final appDir = await getApplicationDocumentsDirectory();
              final fallback = File('${appDir.path}/cotizaciones_guardadas/$cleanFolio.pdf');
              if (fallback.existsSync()) {
                localFile = fallback;
              }
            }

            if (localFile != null) {
              await uploadDocumentFile(
                clientName: clientName,
                documentType: 'Cotización',
                folio: folio,
                localFile: localFile,
                targetFileName: fileName,
              );
              quotesSynced++;
            }
          } catch (_) {}
        }
      } catch (_) {}
    }

    // 3. Sincronizar Contratos
    onProgress?.call('Sincronizando Contratos Legales...', 0.65);
    final rawContracts = prefs.getString('ej_contracts_history_list');
    if (rawContracts != null && rawContracts.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(rawContracts);
        for (int i = 0; i < list.length; i++) {
          try {
            final c = Map<String, dynamic>.from(list[i]);
            final folio = (c['folio'] ?? 'S_N').toString();
            final cleanFolio = folio.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
            final clientName = (c['businessName'] ?? c['clientName'] ?? 'Cliente').toString();
            final pdfPath = c['pdfPath'] as String?;
            final fileName = 'Contrato_$cleanFolio.pdf';

            File? localFile;
            if (pdfPath != null && File(pdfPath).existsSync()) {
              localFile = File(pdfPath);
            } else {
              final appDir = await getApplicationDocumentsDirectory();
              final fallback = File('${appDir.path}/contratos_guardados/$cleanFolio.pdf');
              if (fallback.existsSync()) {
                localFile = fallback;
              }
            }

            if (localFile != null) {
              await uploadDocumentFile(
                clientName: clientName,
                documentType: 'Contrato',
                folio: folio,
                localFile: localFile,
                targetFileName: fileName,
              );
              contractsSynced++;
            }
          } catch (_) {}
        }
      } catch (_) {}
    }

    // 4. Sincronizar Planos y Layouts de Trampas
    onProgress?.call('Sincronizando Planos de Trampas...', 0.85);
    final rawLayoutsList = prefs.getStringList('ej_client_trap_layouts_list') ?? [];
    if (rawLayoutsList.isNotEmpty) {
      try {
        for (int i = 0; i < rawLayoutsList.length; i++) {
          try {
            final layout = TrapLayoutModel.fromJson(rawLayoutsList[i]);
            final pdfBytes = await TrapLayoutPdfService.generateLayoutPdf(layout);
            final cleanFolio = layout.folio.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
            final fileName = 'Plano_Layout_$cleanFolio.pdf';
            final localFile = File('${tempDir.path}/$fileName');
            await localFile.writeAsBytes(pdfBytes);

            await uploadDocumentFile(
              clientName: layout.clientBusinessName.isNotEmpty ? layout.clientBusinessName : 'Cliente',
              documentType: 'Plano',
              folio: layout.folio,
              localFile: localFile,
              targetFileName: fileName,
            );
            layoutsSynced++;
          } catch (_) {}
        }
      } catch (_) {}
    }

    // 5. Preparar carpetas de facturas para todos los clientes (5_Facturas/Pendientes_de_Pago, Pagadas, Canceladas)
    onProgress?.call('Preparando carpetas de facturas para clientes...', 0.90);
    await ensureInvoiceFoldersForAllClients();

    // 6. Respaldar base de datos unificada en Google Drive
    onProgress?.call('Guardando base de datos unificada en Google Drive...', 0.95);
    await backupDatabaseToCloud(force: true);

    // 7. Limpieza automática de duplicados para mantener el Drive impecable
    onProgress?.call('Verificando y unificando posibles duplicados...', 0.98);
    await cleanDriveDuplicates();

    onProgress?.call('¡Sincronización completa con éxito!', 1.0);

    return {
      'reports': reportsSynced,
      'quotes': quotesSynced,
      'contracts': contractsSynced,
      'layouts': layoutsSynced,
    };
  }

  /// Limpia y unifica carpetas de clientes duplicadas y archivos repetidos en Google Drive
  Future<Map<String, int>> cleanDriveDuplicates({void Function(String message, double progress)? onProgress}) async {
    final api = await _getDriveApi();
    if (api == null) return {'foldersCleaned': 0, 'filesCleaned': 0};

    int foldersCleaned = 0;
    int filesCleaned = 0;

    try {
      onProgress?.call('Analizando carpetas en Google Drive...', 0.1);
      final clientsRootId = await _getClientsRootFolderId(api);
      if (clientsRootId == null) return {'foldersCleaned': 0, 'filesCleaned': 0};

      // 1. Listar todas las carpetas dentro de Clientes
      final folderListRes = await api.files.list(
        q: "'$clientsRootId' in parents and mimeType = 'application/vnd.google-apps.folder' and trashed = false",
        $fields: 'files(id, name)',
        pageSize: 500,
      );

      final clientFolders = folderListRes.files ?? [];

      // Agrupar carpetas por nombre normalizado (minúsculas y sin espacios extras)
      final Map<String, List<drive.File>> groupedFolders = {};
      for (final f in clientFolders) {
        final normName = (f.name ?? '').trim().toLowerCase();
        if (normName.isEmpty) continue;
        groupedFolders.putIfAbsent(normName, () => []).add(f);
      }

      int processed = 0;
      final totalGroups = groupedFolders.length;

      for (final entry in groupedFolders.entries) {
        processed++;
        onProgress?.call('Unificando cliente "${entry.value.first.name}" ($processed/$totalGroups)...', 0.2 + (0.6 * (processed / (totalGroups > 0 ? totalGroups : 1))));
        final list = entry.value;
        final primaryFolder = list.first;

        // Si hay carpetas duplicadas con el mismo nombre
        if (list.length > 1) {
          for (int i = 1; i < list.length; i++) {
            final dupFolder = list[i];
            try {
              // Obtener hijos de la carpeta duplicada
              final childrenRes = await api.files.list(
                q: "'${dupFolder.id}' in parents and trashed = false",
                $fields: 'files(id, name, mimeType, parents)',
              );
              final children = childrenRes.files ?? [];
              for (final child in children) {
                if (child.mimeType == 'application/vnd.google-apps.folder') {
                  // Es una subcarpeta (ej. 1_Reportes_de_Servicio)
                  final targetSubId = await _getOrCreateFolder(api, child.name ?? 'Subcarpeta', parentId: primaryFolder.id);
                  // Mover los archivos de la subcarpeta repetida a la subcarpeta principal
                  final subChildrenRes = await api.files.list(
                    q: "'${child.id}' in parents and trashed = false",
                    $fields: 'files(id, name, parents)',
                  );
                  for (final sc in (subChildrenRes.files ?? [])) {
                    try {
                      await api.files.update(
                        drive.File(),
                        sc.id!,
                        addParents: targetSubId,
                        removeParents: child.id,
                      );
                    } catch (_) {}
                  }
                  // Borrar la subcarpeta repetida vacía
                  try {
                    await api.files.delete(child.id!);
                  } catch (_) {}
                } else {
                  // Mover archivo directo a la carpeta principal
                  try {
                    await api.files.update(
                      drive.File(),
                      child.id!,
                      addParents: primaryFolder.id,
                      removeParents: dupFolder.id,
                    );
                  } catch (_) {}
                }
              }
              // Borrar la carpeta duplicada del cliente
              await api.files.delete(dupFolder.id!);
              foldersCleaned++;
            } catch (e) {
              debugPrint('Error unificando carpeta duplicada ${dupFolder.name}: $e');
            }
          }
        }

        // 2. Limpiar archivos repetidos con el mismo nombre dentro de las subcarpetas del cliente
        final subfoldersRes = await api.files.list(
          q: "'${primaryFolder.id}' in parents and mimeType = 'application/vnd.google-apps.folder' and trashed = false",
          $fields: 'files(id, name)',
        );
        for (final sub in (subfoldersRes.files ?? [])) {
          final filesRes = await api.files.list(
            q: "'${sub.id}' in parents and mimeType != 'application/vnd.google-apps.folder' and trashed = false",
            $fields: 'files(id, name, createdTime)',
          );
          final files = filesRes.files ?? [];
          final Map<String, List<drive.File>> filesByName = {};
          for (final file in files) {
            final fileName = file.name ?? '';
            if (fileName.isEmpty) continue;
            filesByName.putIfAbsent(fileName, () => []).add(file);
          }

          for (final fileList in filesByName.values) {
            if (fileList.length > 1) {
              // Ordenar: el más reciente se conserva, los más antiguos duplicados se borran
              fileList.sort((a, b) => (b.createdTime ?? DateTime(2000)).compareTo(a.createdTime ?? DateTime(2000)));
              for (int k = 1; k < fileList.length; k++) {
                try {
                  await api.files.delete(fileList[k].id!);
                  filesCleaned++;
                } catch (_) {}
              }
            }
          }
        }
      }

      // Limpiar caché de IDs de carpetas para actualizar referencias
      _folderIdCache.clear();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_folderCacheKey);

      onProgress?.call('¡Limpieza completada con éxito!', 1.0);
    } catch (e) {
      debugPrint('Error limpiando duplicados en Drive: $e');
    }

    return {
      'foldersCleaned': foldersCleaned,
      'filesCleaned': filesCleaned,
    };
  }

  // =========================================================================
  // GESTIÓN DE FACTURACIÓN Y COBRANZA (CFDI PDF + XML)
  // =========================================================================

  /// Obtiene las facturas guardadas en caché local de forma instantánea (0 ms)
  Future<List<InvoiceModel>> getCachedInvoices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('ej_cached_invoices');
      if (raw == null || raw.isEmpty) return [];
      final List<dynamic> list = jsonDecode(raw);
      return list.map((item) => InvoiceModel.fromMap(Map<String, dynamic>.from(item))).toList();
    } catch (_) {
      return [];
    }
  }

  /// Obtiene la lista de facturas desde Google Drive (Pendientes, Pagadas y Canceladas)
  /// EXCLUSIVAMENTE para los clientes vigentes registrados en la app, ejecutado en paralelo ultrarrápido.
  Future<List<InvoiceModel>> fetchInvoices({String? clientFilter, String? statusFilter}) async {
    final api = await _getDriveApi();
    if (api == null) return [];

    final Map<String, InvoiceModel> invoicesMap = {};

    try {
      // 1. Obtener ÚNICA Y EXCLUSIVAMENTE los clientes vigentes de la app
      final savedClients = await ClientService().getSavedClients();
      if (savedClients.isEmpty) return [];

      final clientsRootId = await _getClientsRootFolderId(api);
      if (clientsRootId == null) return [];

      // Ejecutar consultas de clientes en paralelo ultrarrápido
      final clientTasks = savedClients.map((client) async {
        final clientName = client.businessName.trim();
        if (clientName.isEmpty) return;

        if (clientFilter != null && clientFilter.trim().isNotEmpty) {
          if (!clientName.toLowerCase().contains(clientFilter.trim().toLowerCase())) {
            return;
          }
        }

        // Obtener carpeta del cliente en Drive
        final clientFolderId = await _getClientFolderId(api, clientName);
        if (clientFolderId == null) return;

        // Buscar subcarpetas de Facturas dentro de este cliente (5_Facturas o Facturas)
        final invFoldersRes = await api.files.list(
          q: "'$clientFolderId' in parents and mimeType = 'application/vnd.google-apps.folder' and (name = '5_Facturas' or name = 'Facturas') and trashed = false",
          $fields: 'files(id, name)',
        );

        final invFolders = invFoldersRes.files ?? [];
        if (invFolders.isEmpty) return;

        for (final invRoot in invFolders) {
          final invRootId = invRoot.id!;

          // Listar las 3 subcarpetas de estado (Pendientes, Pagadas, Canceladas)
          final subFoldersRes = await api.files.list(
            q: "'$invRootId' in parents and mimeType = 'application/vnd.google-apps.folder' and trashed = false",
            $fields: 'files(id, name)',
          );

          final subFolders = subFoldersRes.files ?? [];

          final subTasks = subFolders.map((sf) async {
            final folderId = sf.id!;
            final folderName = (sf.name ?? '').toLowerCase().replaceAll('_', ' ').trim();

            String status = 'pending';
            if (folderName.contains('pagad')) {
              status = 'paid';
            } else if (folderName.contains('cancel')) {
              status = 'canceled';
            } else {
              status = 'pending';
            }

            if (statusFilter != null && statusFilter.isNotEmpty && status != statusFilter) {
              return;
            }

            // Listar archivos dentro de esta subcarpeta (PDFs y XMLs)
            final filesRes = await api.files.list(
              q: "'$folderId' in parents and trashed = false",
              $fields: 'files(id, name, mimeType, createdTime, modifiedTime, size, webViewLink)',
              pageSize: 500,
            );

            final allFiles = filesRes.files ?? [];
            final pdfFiles = allFiles.where((f) => (f.name ?? '').toLowerCase().endsWith('.pdf')).toList();
            final xmlFiles = allFiles.where((f) => (f.name ?? '').toLowerCase().endsWith('.xml')).toList();

            for (final pdf in pdfFiles) {
              final pdfName = pdf.name ?? 'Factura.pdf';
              final baseName = pdfName.substring(0, pdfName.length - 4);

              String folio = baseName;
              final parts = baseName.split(RegExp(r'[_-]'));
              if (parts.length > 1) {
                folio = parts.last;
              }

              drive.File? matchedXml;
              for (final xml in xmlFiles) {
                final xmlName = xml.name ?? '';
                final xmlBase = xmlName.toLowerCase().replaceAll('.xml', '');
                if (xmlBase == baseName.toLowerCase() || xmlFiles.length == 1) {
                  matchedXml = xml;
                  break;
                }
              }

              invoicesMap[pdf.id!] = InvoiceModel(
                id: pdf.id!,
                pdfName: pdfName,
                folio: folio,
                clientName: clientName,
                clientPhone: client.phone,
                clientEmail: client.email,
                createdTime: pdf.createdTime ?? DateTime.now(),
                modifiedTime: pdf.modifiedTime,
                pdfWebViewLink: pdf.webViewLink,
                xmlFileId: matchedXml?.id,
                xmlFileName: matchedXml?.name,
                status: status,
                parentFolderId: folderId,
                fileSize: pdf.size != null ? int.tryParse(pdf.size!) ?? 0 : 0,
              );
            }
          });

          await Future.wait(subTasks);

          // También revisar si hay archivos PDF puestos directamente en la carpeta 5_Facturas
          if (statusFilter == null || statusFilter == 'pending') {
            final directFilesRes = await api.files.list(
              q: "'$invRootId' in parents and mimeType != 'application/vnd.google-apps.folder' and trashed = false",
              $fields: 'files(id, name, mimeType, createdTime, modifiedTime, size, webViewLink)',
            );

            final directFiles = directFilesRes.files ?? [];
            final directPdfs = directFiles.where((f) => (f.name ?? '').toLowerCase().endsWith('.pdf')).toList();
            final directXmls = directFiles.where((f) => (f.name ?? '').toLowerCase().endsWith('.xml')).toList();

            for (final pdf in directPdfs) {
              if (invoicesMap.containsKey(pdf.id!)) continue;

              final pdfName = pdf.name ?? 'Factura.pdf';
              final baseName = pdfName.substring(0, pdfName.length - 4);
              String folio = baseName;
              final parts = baseName.split(RegExp(r'[_-]'));
              if (parts.length > 1) {
                folio = parts.last;
              }

              drive.File? matchedXml;
              for (final xml in directXmls) {
                final xmlName = xml.name ?? '';
                final xmlBase = xmlName.toLowerCase().replaceAll('.xml', '');
                if (xmlBase == baseName.toLowerCase() || directXmls.length == 1) {
                  matchedXml = xml;
                  break;
                }
              }

              invoicesMap[pdf.id!] = InvoiceModel(
                id: pdf.id!,
                pdfName: pdfName,
                folio: folio,
                clientName: clientName,
                clientPhone: client.phone,
                clientEmail: client.email,
                createdTime: pdf.createdTime ?? DateTime.now(),
                modifiedTime: pdf.modifiedTime,
                pdfWebViewLink: pdf.webViewLink,
                xmlFileId: matchedXml?.id,
                xmlFileName: matchedXml?.name,
                status: 'pending',
                parentFolderId: invRootId,
                fileSize: pdf.size != null ? int.tryParse(pdf.size!) ?? 0 : 0,
              );
            }
          }
        }
      });

      await Future.wait(clientTasks);
    } catch (e) {
      debugPrint('Error listando facturas de clientes vigentes en Drive: $e');
    }

    final result = invoicesMap.values.toList();
    result.sort((a, b) => b.createdTime.compareTo(a.createdTime));

    // Guardar en caché local para que la próxima apertura sea inmediata (0 ms)
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ej_cached_invoices', jsonEncode(result.map((i) => i.toMap()).toList()));
    } catch (_) {}

    return result;
  }

  /// Conteo rápido de facturas pendientes para badges en Hub o menús
  Future<int> getPendingInvoicesCount() async {
    final list = await fetchInvoices(statusFilter: 'pending');
    return list.length;
  }

  /// Mueve los archivos (PDF y XML) a la carpeta "Pagadas"
  Future<bool> markInvoiceAsPaid(InvoiceModel invoice) async {
    final api = await _getDriveApi();
    if (api == null) return false;

    try {
      final targetFolderId = await getClientInvoiceStatusFolderId(api, invoice.clientName, 'paid');
      if (targetFolderId == null) return false;

      // Mover PDF
      await api.files.update(
        drive.File(),
        invoice.id,
        addParents: targetFolderId,
        removeParents: invoice.parentFolderId,
      );

      // Mover XML si existe
      if (invoice.xmlFileId != null && invoice.xmlFileId!.isNotEmpty) {
        try {
          await api.files.update(
            drive.File(),
            invoice.xmlFileId!,
            addParents: targetFolderId,
            removeParents: invoice.parentFolderId,
          );
        } catch (_) {}
      }

      // Actualizar también la lista en caché si existe
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString('ej_cached_invoices');
        if (raw != null && raw.isNotEmpty) {
          final List<dynamic> list = jsonDecode(raw);
          final updatedList = list.map((item) {
            if (item['id'] == invoice.id) {
              item['status'] = 'paid';
              item['parentFolderId'] = targetFolderId;
            }
            return item;
          }).toList();
          await prefs.setString('ej_cached_invoices', jsonEncode(updatedList));
        }
      } catch (_) {}

      return true;
    } catch (e) {
      debugPrint('Error marcando factura como pagada: $e');
      return false;
    }
  }

  /// Mueve los archivos (PDF y XML) a la carpeta "Canceladas"
  Future<bool> markInvoiceAsCanceled(InvoiceModel invoice) async {
    final api = await _getDriveApi();
    if (api == null) return false;

    try {
      final targetFolderId = await getClientInvoiceStatusFolderId(api, invoice.clientName, 'canceled');
      if (targetFolderId == null) return false;

      await api.files.update(
        drive.File(),
        invoice.id,
        addParents: targetFolderId,
        removeParents: invoice.parentFolderId,
      );

      if (invoice.xmlFileId != null && invoice.xmlFileId!.isNotEmpty) {
        try {
          await api.files.update(
            drive.File(),
            invoice.xmlFileId!,
            addParents: targetFolderId,
            removeParents: invoice.parentFolderId,
          );
        } catch (_) {}
      }

      // Actualizar también la lista en caché si existe
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString('ej_cached_invoices');
        if (raw != null && raw.isNotEmpty) {
          final List<dynamic> list = jsonDecode(raw);
          final updatedList = list.map((item) {
            if (item['id'] == invoice.id) {
              item['status'] = 'canceled';
              item['parentFolderId'] = targetFolderId;
            }
            return item;
          }).toList();
          await prefs.setString('ej_cached_invoices', jsonEncode(updatedList));
        }
      } catch (_) {}

      return true;
    } catch (e) {
      debugPrint('Error marcando factura como cancelada: $e');
      return false;
    }
  }

  /// Regresa los archivos a la carpeta "Pendientes_de_Pago"
  Future<bool> markInvoiceAsPending(InvoiceModel invoice) async {
    final api = await _getDriveApi();
    if (api == null) return false;

    try {
      final targetFolderId = await getClientInvoiceStatusFolderId(api, invoice.clientName, 'pending');
      if (targetFolderId == null) return false;

      await api.files.update(
        drive.File(),
        invoice.id,
        addParents: targetFolderId,
        removeParents: invoice.parentFolderId,
      );

      if (invoice.xmlFileId != null && invoice.xmlFileId!.isNotEmpty) {
        try {
          await api.files.update(
            drive.File(),
            invoice.xmlFileId!,
            addParents: targetFolderId,
            removeParents: invoice.parentFolderId,
          );
        } catch (_) {}
      }

      // Actualizar también la lista en caché si existe
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString('ej_cached_invoices');
        if (raw != null && raw.isNotEmpty) {
          final List<dynamic> list = jsonDecode(raw);
          final updatedList = list.map((item) {
            if (item['id'] == invoice.id) {
              item['status'] = 'pending';
              item['parentFolderId'] = targetFolderId;
            }
            return item;
          }).toList();
          await prefs.setString('ej_cached_invoices', jsonEncode(updatedList));
        }
      } catch (_) {}

      return true;
    } catch (e) {
      debugPrint('Error regresando factura a pendientes: $e');
      return false;
    }
  }

  /// Descarga el PDF de la factura a un archivo local temporal para visualizar o compartir
  Future<File?> downloadInvoicePdf(InvoiceModel invoice) async {
    final api = await _getDriveApi();
    if (api == null) return null;

    try {
      final media = await api.files.get(
        invoice.id,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final tempDir = await getTemporaryDirectory();
      final cleanName = invoice.pdfName.replaceAll(RegExp(r'[^\w.-]'), '_');
      final localFile = File('${tempDir.path}/$cleanName');
      final sink = localFile.openWrite();
      await media.stream.pipe(sink);
      await sink.close();

      return localFile;
    } catch (e) {
      debugPrint('Error descargando PDF de factura: $e');
      return null;
    }
  }

  /// Descarga bajo demanda un documento PDF (Reporte, Cotización, Contrato, etc.) desde Google Drive
  /// si no existe físicamente en el dispositivo (ej. al restaurar datos en otro teléfono).
  /// Lo guarda permanentemente en la memoria local y lo retorna listo para abrir o compartir al instante.
  Future<File?> downloadDocumentPdf({
    required String clientName,
    required String documentType,
    required String folio,
    String? preferredFileName,
  }) async {
    final api = await _getDriveApi();
    if (api == null) return null;

    try {
      final cleanFolio = folio.trim().replaceAll(RegExp(r'[^\w-]'), '_');
      final targetFolderId = await _getCategoryFolderId(api, clientName, documentType);

      List<drive.File> candidates = [];

      // 1. Buscar en la subcarpeta de categoría (ej. 1_Reportes_de_Servicio)
      if (targetFolderId != null) {
        final res = await api.files.list(
          q: "'$targetFolderId' in parents and mimeType = 'application/pdf' and trashed = false",
          $fields: 'files(id, name, createdTime)',
          pageSize: 200,
        );
        candidates = res.files ?? [];
      }

      // 2. Si no se encontró en la subcarpeta, buscar en la carpeta raíz del cliente
      if (candidates.isEmpty) {
        final clientFolderId = await _getClientFolderId(api, clientName);
        if (clientFolderId != null) {
          final res = await api.files.list(
            q: "'$clientFolderId' in parents and mimeType = 'application/pdf' and trashed = false",
            $fields: 'files(id, name, createdTime)',
            pageSize: 200,
          );
          candidates = res.files ?? [];
        }
      }

      if (candidates.isEmpty) return null;

      // 3. Buscar el archivo que contenga el folio o coincida con el nombre preferido
      drive.File? matchedFile;
      for (final f in candidates) {
        final name = (f.name ?? '').toLowerCase();
        if (cleanFolio.isNotEmpty && name.contains(cleanFolio.toLowerCase())) {
          matchedFile = f;
          break;
        }
      }

      if (matchedFile == null && preferredFileName != null && preferredFileName.isNotEmpty) {
        final normPref = preferredFileName.toLowerCase();
        for (final f in candidates) {
          if ((f.name ?? '').toLowerCase().contains(normPref)) {
            matchedFile = f;
            break;
          }
        }
      }

      if (matchedFile == null && candidates.isNotEmpty) {
        matchedFile = candidates.first;
      }

      if (matchedFile == null || matchedFile.id == null) return null;

      // Descargar contenido completo del PDF
      final drive.Media media = await api.files.get(
        matchedFile.id!,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      // Guardar de forma permanente en almacenamiento interno de la app
      final docsDir = await getApplicationDocumentsDirectory();
      String subDirName = 'Reportes';
      if (documentType.contains('Cotiz')) subDirName = 'Cotizaciones';
      if (documentType.contains('Contrat')) subDirName = 'Contratos';
      if (documentType.contains('Cronograma')) subDirName = 'Cronogramas';

      final targetDir = Directory('${docsDir.path}/$subDirName');
      if (!targetDir.existsSync()) {
        targetDir.createSync(recursive: true);
      }

      final fileName = matchedFile.name ?? '${documentType}_$cleanFolio.pdf';
      final cleanFileName = fileName.replaceAll(RegExp(r'[^\w.-]'), '_');
      final localFile = File('${targetDir.path}/$cleanFileName');

      final sink = localFile.openWrite();
      await media.stream.pipe(sink);
      await sink.close();

      return localFile;
    } catch (e) {
      debugPrint('Error descargando documento PDF desde Google Drive: $e');
      return null;
    }
  }
}
