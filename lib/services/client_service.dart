import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/client_model.dart';
import 'google_drive_sync_service.dart';

class ClientService {
  static const String _storageKey = 'ej_saved_clients';

  // Obtener lista completa de clientes guardados
  Future<List<ClientModel>> getSavedClients() async {
    final prefs = await SharedPreferences.getInstance();
    final String? rawData = prefs.getString(_storageKey);
    if (rawData == null || rawData.isEmpty) return [];

    try {
      final List<dynamic> decoded = jsonDecode(rawData);
      return decoded.map((item) => ClientModel.fromMap(item)).toList();
    } catch (_) {
      return [];
    }
  }

  // Guardar o actualizar un cliente
  Future<void> saveClient(ClientModel client, {bool syncToCloud = true}) async {
    final prefs = await SharedPreferences.getInstance();
    final List<ClientModel> clients = await getSavedClients();

    final existingIndex = clients.indexWhere(
          (c) => c.businessName.trim().toLowerCase() == client.businessName.trim().toLowerCase(),
    );

    if (existingIndex >= 0) {
      clients[existingIndex] = client;
    } else {
      clients.add(client);
    }

    final String encoded = jsonEncode(clients.map((c) => c.toMap()).toList());
    await prefs.setString(_storageKey, encoded);

    // En segundo plano: crear carpeta en Drive, subcarpetas de facturación, generar link de WhatsApp y actualizar snapshot maestro
    if (syncToCloud) {
      try {
        GoogleDriveSyncService().getOrCreateClientFolderShareLink(client.businessName);
        GoogleDriveSyncService().ensureInvoiceFoldersExist(client.businessName);
        GoogleDriveSyncService().backupDatabaseToCloud();
      } catch (_) {}
    }
  }
}