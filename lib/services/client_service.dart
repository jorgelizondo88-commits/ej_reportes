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
  Future<bool> saveClient(
    ClientModel client, {
    bool syncToCloud = true,
    bool syncMasterBackup = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final List<ClientModel> clients = await getSavedClients();

    final normalizedTarget = (client.businessName.trim().isNotEmpty ? client.businessName : client.contactName)
        .trim()
        .toLowerCase();

    final existingIndex = clients.indexWhere((c) {
      final current = (c.businessName.trim().isNotEmpty ? c.businessName : c.contactName).trim().toLowerCase();
      return current.isNotEmpty && current == normalizedTarget;
    });

    final clientToSave = syncToCloud
        ? client.copyWith(
            updatedAt: DateTime.now(),
            driveFolderId: client.driveFolderId ?? (existingIndex >= 0 ? clients[existingIndex].driveFolderId : null),
            driveFolderShareUrl: client.driveFolderShareUrl ?? (existingIndex >= 0 ? clients[existingIndex].driveFolderShareUrl : null),
          )
        : client;

    if (existingIndex >= 0) {
      clients[existingIndex] = clientToSave;
    } else {
      clients.add(clientToSave);
    }

    final String encoded = jsonEncode(clients.map((c) => c.toMap()).toList());
    await prefs.setString(_storageKey, encoded);

    // Crear carpeta en Drive, subcarpetas de facturación, generar link de WhatsApp y actualizar copia maestra automáticamente
    if (syncToCloud) {
      try {
        final folderName = clientToSave.businessName.trim().isNotEmpty
            ? clientToSave.businessName.trim()
            : clientToSave.contactName.trim();
        await GoogleDriveSyncService().getOrCreateClientFolderShareLink(folderName);
        await GoogleDriveSyncService().ensureInvoiceFoldersExist(folderName);
        await GoogleDriveSyncService().ensureCertificateFolderExist(folderName);
        if (syncMasterBackup) {
          return await GoogleDriveSyncService().saveAndSyncMasterBackup();
        }
        return true;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  /// Registra el cliente localmente solo si aún no existe en el directorio (sin sobreescribir inventario/trampas existentes).
  Future<void> ensureClientExistsLocal(ClientModel client) async {
    final key = (client.businessName.trim().isNotEmpty ? client.businessName : client.contactName)
        .trim()
        .toLowerCase();
    if (key.isEmpty) return;

    final clients = await getSavedClients();
    final exists = clients.any((c) {
      final current = (c.businessName.trim().isNotEmpty ? c.businessName : c.contactName).trim().toLowerCase();
      return current == key;
    });
    if (!exists) {
      clients.add(client.copyWith(updatedAt: client.updatedAt ?? DateTime.now()));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(clients.map((c) => c.toMap()).toList()));
    }
  }
}