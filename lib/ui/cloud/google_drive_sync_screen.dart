import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/cloud_sync_item_model.dart';
import '../../services/google_drive_sync_service.dart';

class GoogleDriveSyncScreen extends StatefulWidget {
  final VoidCallback? onDataRestored;
  const GoogleDriveSyncScreen({super.key, this.onDataRestored});

  @override
  State<GoogleDriveSyncScreen> createState() => _GoogleDriveSyncScreenState();
}

class _GoogleDriveSyncScreenState extends State<GoogleDriveSyncScreen> {
  final GoogleDriveSyncService _driveService = GoogleDriveSyncService();
  bool _isLoading = false;
  List<CloudSyncItemModel> _queue = [];
  String _syncStatusText = '';
  double _syncProgress = 0.0;
  bool _isSyncingAll = false;

  @override
  void initState() {
    super.initState();
    _checkStatusAndLoadQueue();
  }

  Future<void> _checkStatusAndLoadQueue() async {
    setState(() => _isLoading = true);
    await _driveService.initSilently();
    final queue = await _driveService.getQueue();
    if (mounted) {
      setState(() {
        _queue = queue;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleSignIn() async {
    setState(() => _isLoading = true);
    final account = await _driveService.signIn();
    setState(() => _isLoading = false);

    if (account != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡Conectado exitosamente con ${account.email}!'),
          backgroundColor: Colors.green.shade800,
        ),
      );
      _checkStatusAndLoadQueue();
    } else if (mounted) {
      final err = _driveService.lastError ?? 'No se pudo completar el inicio de sesión.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err),
          backgroundColor: Colors.red.shade800,
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  Future<void> _handleSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cerrar sesión de Google Drive?'),
        content: const Text('Se pausará la sincronización automática en la nube hasta que vuelvas a iniciar sesión. Los archivos guardados en tu celular permanecerán intactos.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _driveService.signOut();
      _checkStatusAndLoadQueue();
    }
  }

  Future<void> _syncAllHistory() async {
    if (!_driveService.isSignedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor inicia sesión con Google primero.')),
      );
      return;
    }

    setState(() {
      _isSyncingAll = true;
      _syncProgress = 0.05;
      _syncStatusText = 'Iniciando respaldo completo en Google Drive...';
    });

    final results = await _driveService.syncAllHistoryNow(
      onProgress: (status, progress) {
        if (mounted) {
          setState(() {
            _syncStatusText = status;
            _syncProgress = progress;
          });
        }
      },
    );

    final queue = await _driveService.getQueue();

    if (mounted) {
      setState(() {
        _isSyncingAll = false;
        _queue = queue;
      });

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('¡Respaldo Completo!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Todo tu historial se respaldó exitosamente en Google Drive:'),
              const SizedBox(height: 12),
              _statRow('📄 Reportes de servicio:', '${results["reports"] ?? 0}'),
              _statRow('💰 Cotizaciones:', '${results["quotes"] ?? 0}'),
              _statRow('📑 Contratos legales:', '${results["contracts"] ?? 0}'),
              _statRow('📐 Planos y Layouts:', '${results["layouts"] ?? 0}'),
              const Divider(height: 16),
              const Text(
                'Tus archivos están organizados por cliente en la carpeta "EJ Exterminadores" de tu Google Drive.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F2B48), foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(context),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
    }
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F2B48))),
        ],
      ),
    );
  }

  Future<void> _cleanDriveDuplicates() async {
    if (!_driveService.isSignedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor inicia sesión con Google primero.')),
      );
      return;
    }

    setState(() {
      _isSyncingAll = true;
      _syncProgress = 0.05;
      _syncStatusText = 'Analizando Google Drive para unificar duplicados...';
    });

    final results = await _driveService.cleanDriveDuplicates(
      onProgress: (status, progress) {
        if (mounted) {
          setState(() {
            _syncStatusText = status;
            _syncProgress = progress;
          });
        }
      },
    );

    if (mounted) {
      setState(() => _isSyncingAll = false);
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.cleaning_services, color: Color(0xFF0F2B48)),
              SizedBox(width: 8),
              Text('¡Limpieza Completa!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Se revisó tu Google Drive y se optimizó tu espacio:'),
              const SizedBox(height: 12),
              _statRow('📁 Carpetas unificadas:', '${results["foldersCleaned"] ?? 0}'),
              _statRow('📄 Archivos duplicados removidos:', '${results["filesCleaned"] ?? 0}'),
              const Divider(height: 16),
              const Text(
                'Tus carpetas de clientes y reportes han quedado limpios, únicos y organizados.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F2B48), foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(context),
              child: const Text('Excelente'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _createAllInvoiceFolders() async {
    if (!_driveService.isSignedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor inicia sesión con Google primero.')),
      );
      return;
    }

    setState(() {
      _isSyncingAll = true;
      _syncProgress = 0.05;
      _syncStatusText = 'Creando carpetas de facturas para todos los clientes...';
    });

    final count = await _driveService.ensureInvoiceFoldersForAllClients(
      onProgress: (status, progress) {
        if (mounted) {
          setState(() {
            _syncStatusText = status;
            _syncProgress = progress;
          });
        }
      },
    );

    if (mounted) {
      setState(() => _isSyncingAll = false);
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.folder_shared, color: Color(0xFF0F766E)),
              SizedBox(width: 8),
              Text('¡Carpetas Creadas!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Se preparó la estructura de facturación en Google Drive para $count cliente(s):'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.teal.shade200),
                ),
                child: const Text(
                  '📁 Clientes\n └── 📁 [Nombre del Cliente]\n        └── 📁 5_Facturas\n               ├── 📁 Pendientes_de_Pago\n               ├── 📁 Pagadas\n               └── 📁 Canceladas',
                  style: TextStyle(fontFamily: 'monospace', fontSize: 11.5, height: 1.4),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Ahora puedes arrastrar tus archivos PDF y XML a "Pendientes_de_Pago" desde tu computadora o teléfono.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F2B48), foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(context),
              child: const Text('Excelente'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _backupDatabase() async {
    setState(() => _isLoading = true);
    final ok = await _driveService.backupDatabaseToCloud();
    setState(() => _isLoading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? '¡Copia de seguridad maestra creada en Google Drive!' : 'Error al respaldar base de datos.'),
          backgroundColor: ok ? Colors.green.shade800 : Colors.red,
        ),
      );
    }
  }

  Future<void> _restoreDatabase() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Restaurar datos desde Google Drive?'),
        content: const Text('Esta acción descargará todos los clientes, reportes, cotizaciones, contratos y configuraciones guardadas en tu Google Drive hacia este dispositivo.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F2B48), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restaurar Ahora'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      final result = await _driveService.restoreDatabaseFromCloud();
      setState(() => _isLoading = false);

      if (mounted) {
        if (result.success) {
          widget.onDataRestored?.call();
          _checkStatusAndLoadQueue();
        }

        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  result.success ? Icons.check_circle : Icons.info_outline,
                  color: result.success ? Colors.green.shade700 : Colors.orange.shade800,
                  size: 26,
                ),
                const SizedBox(width: 8),
                Text(result.success ? 'Restauración Exitosa' : 'Aviso de Respaldo'),
              ],
            ),
            content: Text(result.message, style: const TextStyle(fontSize: 13, height: 1.4)),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F2B48),
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Entendido'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _driveService.currentUser;
    final isSignedIn = _driveService.isSignedIn;

    final syncedCount = _queue.where((q) => q.status == 'synced').length;
    final pendingCount = _queue.where((q) => q.status == 'pending' || q.status == 'error').length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nube Google Drive (5 TB)', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0F2B48),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar estado',
            onPressed: _checkStatusAndLoadQueue,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(14),
              children: [
                // TARJETA DE ESTADO DE CUENTA
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: isSignedIn ? Colors.green.shade50 : Colors.blue.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isSignedIn ? Icons.cloud_done : Icons.cloud_upload_outlined,
                                color: isSignedIn ? Colors.green.shade700 : Colors.blue.shade800,
                                size: 30,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isSignedIn ? (user?.displayName ?? 'Conectado a Google') : 'Google Drive Desconectado',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F2B48)),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isSignedIn ? (user?.email ?? '') : 'Conecta tu cuenta para respaldar tus documentos y generar enlaces para clientes.',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (isSignedIn) ...[
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle, size: 14, color: Colors.green.shade800),
                                    const SizedBox(width: 4),
                                    Text('Nube Activa (5 TB)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade900)),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              TextButton.icon(
                                style: TextButton.styleFrom(foregroundColor: Colors.red),
                                icon: const Icon(Icons.logout, size: 16),
                                label: const Text('Desconectar', style: TextStyle(fontSize: 12)),
                                onPressed: _handleSignOut,
                              ),
                            ],
                          ),
                        ] else ...[
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F2B48),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.login),
                              label: const Text('Conectar con Google Drive (1 toque)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              onPressed: _handleSignIn,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // BARRA DE PROGRESO DE SINCRONIZACIÓN MASIVA
                if (_isSyncingAll) ...[
                  Card(
                    color: const Color(0xFFEFF6FF),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(_syncStatusText, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF))),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          LinearProgressIndicator(value: _syncProgress, color: const Color(0xFF2563EB), backgroundColor: Colors.blue.shade100),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // ACCIONES RÁPIDAS DE SINCRONIZACIÓN
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const CircleAvatar(backgroundColor: Color(0xFFE0E7FF), child: Icon(Icons.sync, color: Color(0xFF3730A3))),
                        title: const Text('Sincronizar Todo mi Historial Ahora', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                        subtitle: const Text('Sube todos tus reportes, contratos, planos y clientes existentes a Google Drive.', style: TextStyle(fontSize: 11.5)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _isSyncingAll ? null : _syncAllHistory,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const CircleAvatar(backgroundColor: Color(0xFFF3E8FF), child: Icon(Icons.cleaning_services, color: Color(0xFF7E22CE))),
                        title: const Text('Limpiar y Unificar Duplicados en Drive', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                        subtitle: const Text('Fusiona carpetas repetidas de clientes y elimina reportes duplicados automáticamente.', style: TextStyle(fontSize: 11.5)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _isSyncingAll ? null : _cleanDriveDuplicates,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const CircleAvatar(backgroundColor: Color(0xFFDCFCE7), child: Icon(Icons.backup, color: Color(0xFF166534))),
                        title: const Text('Respaldar Base de Datos Maestra', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                        subtitle: const Text('Guarda una copia de seguridad en "EJ Exterminadores/Respaldo_Sistema_App".', style: TextStyle(fontSize: 11.5)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _backupDatabase,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const CircleAvatar(backgroundColor: Color(0xFFCCFBF1), child: Icon(Icons.receipt_long, color: Color(0xFF0F766E))),
                        title: const Text('Crear Carpetas de Facturas para Todos los Clientes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                        subtitle: const Text('Genera "5_Facturas" (Pendientes, Pagadas y Canceladas) en Drive para cada cliente.', style: TextStyle(fontSize: 11.5)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _isSyncingAll ? null : _createAllInvoiceFolders,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const CircleAvatar(backgroundColor: Color(0xFFFEF3C7), child: Icon(Icons.restore, color: Color(0xFF92400E))),
                        title: const Text('Restaurar Datos desde la Nube', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                        subtitle: const Text('Descarga todos tus clientes y reportes en un teléfono nuevo o secundario.', style: TextStyle(fontSize: 11.5)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _restoreDatabase,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // RESUMEN DE COLA Y ESTADÍSTICAS
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$syncedCount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.green.shade900)),
                            const SizedBox(height: 2),
                            Text('En la Nube', style: TextStyle(fontSize: 12, color: Colors.green.shade800)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: pendingCount > 0 ? Colors.orange.shade50 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: pendingCount > 0 ? Colors.orange.shade200 : Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$pendingCount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: pendingCount > 0 ? Colors.orange.shade900 : Colors.grey.shade700)),
                            const SizedBox(height: 2),
                            Text('En Cola (Sin señal)', style: TextStyle(fontSize: 12, color: pendingCount > 0 ? Colors.orange.shade800 : Colors.grey.shade700)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // ESTRUCTURA DE CARPETAS EXPLICADA
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blueGrey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.folder_shared, color: Color(0xFF0F2B48), size: 20),
                          SizedBox(width: 8),
                          Text('Estructura Oficial en tu Google Drive', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F2B48))),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '📁 EJ Exterminadores\n'
                        '   ├── 📁 Respaldo_Sistema_App  (Copia de seguridad)\n'
                        '   └── 📁 Clientes\n'
                        '          └── 📁 [Nombre del Cliente]\n'
                        '                 ├── 📁 1_Reportes_de_Servicio\n'
                        '                 ├── 📁 2_Cotizaciones\n'
                        '                 ├── 📁 3_Contratos\n'
                        '                 ├── 📁 4_Planos_y_Layouts\n'
                        '                 └── 📁 5_Facturas\n'
                        '                        ├── 📁 Pendientes_de_Pago\n'
                        '                        ├── 📁 Pagadas\n'
                        '                        └── 📁 Canceladas',
                        style: TextStyle(fontFamily: 'monospace', fontSize: 11.5, color: Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'ℹ️ El enlace que compartes con el cliente apunta directamente a su carpeta en modo "Solo Lectura".',
                        style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // ARCHIVOS RECIENTES EN COLA / SUBIDOS
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Archivos Sincronizados Recientemente', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F2B48))),
                    if (pendingCount > 0)
                      TextButton.icon(
                        icon: const Icon(Icons.cloud_upload, size: 16),
                        label: const Text('Subir pendientes', style: TextStyle(fontSize: 12)),
                        onPressed: () async {
                          await _driveService.processQueue();
                          _checkStatusAndLoadQueue();
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                if (_queue.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    alignment: Alignment.center,
                    child: Text('No hay archivos en la cola todavía. Cuando guardes reportes aparecerán aquí.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
                  )
                else
                  ..._queue.reversed.take(15).map((item) {
                    final isSynced = item.status == 'synced';
                    final dateStr = item.syncedAt != null ? DateFormat('dd/MM HH:mm').format(item.syncedAt!) : DateFormat('dd/MM HH:mm').format(item.createdAt);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isSynced ? Colors.green.shade50 : Colors.orange.shade50,
                          child: Icon(
                            isSynced ? Icons.check_circle : Icons.schedule,
                            color: isSynced ? Colors.green.shade700 : Colors.orange.shade800,
                            size: 20,
                          ),
                        ),
                        title: Text(item.fileName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text('${item.clientName} • $dateStr', style: const TextStyle(fontSize: 11)),
                        trailing: item.driveWebViewLink != null
                            ? IconButton(
                                icon: const Icon(Icons.open_in_new, size: 18, color: Color(0xFF0F2B48)),
                                tooltip: 'Ver en Google Drive',
                                onPressed: () {
                                  launchUrl(Uri.parse(item.driveWebViewLink!), mode: LaunchMode.externalApplication);
                                },
                              )
                            : null,
                      ),
                    );
                  }),
              ],
            ),
    );
  }
}
