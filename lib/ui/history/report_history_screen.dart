import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/google_drive_sync_service.dart';

class ReportHistoryScreen extends StatefulWidget {
  const ReportHistoryScreen({super.key});

  @override
  State<ReportHistoryScreen> createState() => _ReportHistoryScreenState();
}

class _ReportHistoryScreenState extends State<ReportHistoryScreen> {
  static const String _historyKey = 'ej_reports_history_list';
  List<Map<String, dynamic>> _allReports = [];
  List<Map<String, dynamic>> _filteredReports = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String? _selectedClientFilter;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _syncReportsInBackground();
  }

  Future<void> _syncReportsInBackground() async {
    final drive = GoogleDriveSyncService();
    if (!drive.isSignedIn) {
      await drive.initSilently();
    }
    if (drive.isSignedIn) {
      final merged = await drive.pullAndMergeCloudDatabase();
      final discovered = await drive.discoverDriveDocuments();
      if ((merged || discovered > 0) && mounted) {
        _loadHistory();
      }
    }
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);

    if (raw != null && raw.isNotEmpty) {
      final List decoded = jsonDecode(raw);
      _allReports = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } else {
      _allReports = [];
    }

    _applyFilter();
    setState(() => _isLoading = false);
  }

  void _applyFilter() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredReports = _allReports.where((item) {
        final business = (item['businessName'] ?? '').toString().toLowerCase();
        final client = (item['clientName'] ?? '').toString().toLowerCase();
        final folio = (item['folio'] ?? '').toString().toLowerCase();

        final matchesSearch = query.isEmpty ||
            business.contains(query) ||
            client.contains(query) ||
            folio.contains(query);

        final matchesClient = _selectedClientFilter == null ||
            (item['businessName'] == _selectedClientFilter || item['clientName'] == _selectedClientFilter);

        return matchesSearch && matchesClient;
      }).toList();
    });
  }

  Future<void> _shareReport(Map<String, dynamic> report) async {
    final filePath = report['filePath'] as String?;
    File? file = (filePath != null && filePath.isNotEmpty) ? File(filePath) : null;

    final folio = (report['folio'] ?? '').toString().trim();
    final clientTitle = (report['businessName'] != null && report['businessName'].toString().trim().isNotEmpty)
        ? report['businessName'].toString().trim()
        : (report['clientName'] ?? '').toString().trim();

    // Si el archivo físico no existe en este dispositivo (ej. restaurado en otro teléfono), descargarlo de Drive
    if (file == null || !file.existsSync()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                SizedBox(width: 12),
                Text('Descargando reporte desde Google Drive...'),
              ],
            ),
            duration: Duration(seconds: 4),
          ),
        );
      }

      file = await GoogleDriveSyncService().downloadDocumentPdf(
        clientName: clientTitle,
        documentType: 'Reporte',
        folio: folio,
      );

      if (file == null || !file.existsSync()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo encontrar el archivo en Google Drive.')),
          );
        }
        return;
      }

      // Guardar la nueva ruta local permanente en la memoria del teléfono
      report['filePath'] = file.path;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_historyKey, jsonEncode(_allReports));
    }

    final cleanFolio = folio.replaceAll(RegExp(r'[^\w-]'), '_');
    final cleanClient = clientTitle
        .replaceAll(RegExp(r'[^\wáéíóúÁÉÍÓÚñÑ\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '_');

    final fileName = cleanClient.isEmpty
        ? (cleanFolio.isEmpty ? 'Reporte.pdf' : 'Reporte_$cleanFolio.pdf')
        : 'Reporte_${cleanFolio}_$cleanClient.pdf';

    try {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$fileName');
      await file.copy(tempFile.path);

      await Share.shareXFiles(
        [XFile(tempFile.path, name: fileName)],
        text: 'Reporte de Servicio de Control de Plagas - Folio $folio',
        subject: 'Reporte de Servicio: ${clientTitle.isNotEmpty ? clientTitle : folio}',
      );
    } catch (_) {
      // Si por alguna razón falla la copia temporal, compartimos el original
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Reporte de Servicio de Control de Plagas - Folio $folio',
        subject: 'Reporte de Servicio: ${clientTitle.isNotEmpty ? clientTitle : folio}',
      );
    }
  }

  Future<void> _openViewer(Map<String, dynamic> report) async {
    final filePath = report['filePath'] as String?;
    File? file = (filePath != null && filePath.isNotEmpty) ? File(filePath) : null;

    final folio = (report['folio'] ?? '').toString().trim();
    final clientTitle = (report['businessName'] != null && report['businessName'].toString().trim().isNotEmpty)
        ? report['businessName'].toString().trim()
        : (report['clientName'] ?? '').toString().trim();

    // Si el archivo físico no existe en este dispositivo (ej. restaurado en otro teléfono), descargarlo de Drive
    if (file == null || !file.existsSync()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                SizedBox(width: 12),
                Text('Descargando reporte desde Google Drive...'),
              ],
            ),
            duration: Duration(seconds: 4),
          ),
        );
      }

      file = await GoogleDriveSyncService().downloadDocumentPdf(
        clientName: clientTitle,
        documentType: 'Reporte',
        folio: folio,
      );

      if (file == null || !file.existsSync()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo encontrar el archivo en Google Drive.')),
          );
        }
        return;
      }

      // Guardar la nueva ruta local permanente en la memoria del teléfono para aperturas instantáneas
      report['filePath'] = file.path;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_historyKey, jsonEncode(_allReports));
    }

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _SavedPdfViewerScreen(
          title: 'Folio: $folio',
          filePath: file!.path,
          folio: folio,
          clientName: clientTitle,
        ),
      ),
    );
  }

  Future<void> _deleteReport(Map<String, dynamic> report) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar Reporte?'),
        content: Text('Se eliminará permanentemente el reporte con folio ${report['folio']} de tu dispositivo.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final filePath = report['filePath'] as String?;
        if (filePath != null) {
          final file = File(filePath);
          if (await file.exists()) await file.delete();
        }

        _allReports.removeWhere((item) => item['folio'] == report['folio']);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_historyKey, jsonEncode(_allReports));

        _applyFilter();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reporte eliminado correctamente.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar: $e')),
          );
        }
      }
    }
  }

  Future<void> _syncFromDrive() async {
    if (!mounted) return;
    final drive = GoogleDriveSyncService();
    if (!drive.isSignedIn) {
      await drive.initSilently();
    }
    if (!drive.isSignedIn) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Conecta Google Drive primero para sincronizar reportes.')),
        );
      }
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            SizedBox(width: 12),
            Text('Sincronizando reportes con Google Drive...'),
          ],
        ),
        duration: Duration(seconds: 2),
      ),
    );
    await drive.pullAndMergeCloudDatabase();
    await drive.discoverDriveDocuments();
    await _loadHistory();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Historial sincronizado con éxito!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');

    // Lista de clientes únicos para filtrar
    final Set<String> clientNames = {};
    for (var r in _allReports) {
      final name = (r['businessName'] != null && r['businessName'].toString().isNotEmpty)
          ? r['businessName'].toString()
          : (r['clientName'] ?? '').toString();
      if (name.isNotEmpty) clientNames.add(name);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Reportes', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0F2B48),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Sincronizar con Google Drive',
            onPressed: _syncFromDrive,
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de búsqueda
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar por cliente, empresa o folio...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _applyFilter();
                  },
                )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onChanged: (_) => _applyFilter(),
            ),
          ),

          // Selector de cliente frecuente si hay varios
          if (clientNames.isNotEmpty)
            Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              color: Colors.white,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ChoiceChip(
                    label: const Text('Todos'),
                    selected: _selectedClientFilter == null,
                    onSelected: (selected) {
                      setState(() => _selectedClientFilter = null);
                      _applyFilter();
                    },
                  ),
                  const SizedBox(width: 8),
                  ...clientNames.map((client) {
                    final isSelected = _selectedClientFilter == client;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(client),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() => _selectedClientFilter = selected ? client : null);
                          _applyFilter();
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
          const Divider(height: 1),

          // Lista de Reportes
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F2B48)))
                : _filteredReports.isEmpty
                ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.folder_open, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 10),
                  Text(
                    _allReports.isEmpty
                        ? 'No tienes reportes guardados todavía.\nGuarda uno desde la vista previa del PDF.'
                        : 'No se encontraron reportes con ese criterio.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black54, fontSize: 14),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _filteredReports.length,
              itemBuilder: (context, index) {
                final item = _filteredReports[index];
                final business = item['businessName'] ?? '';
                final contact = item['clientName'] ?? '';
                final folio = item['folio'] ?? 'Sin Folio';
                final dateStr = item['serviceDate'] ?? '';
                final parsedDate = DateTime.tryParse(dateStr);
                final tech = item['technicianName'] ?? '';

                final mainTitle = business.isNotEmpty ? business : contact;
                final subTitle = business.isNotEmpty && contact.isNotEmpty ? contact : '';

                return Card(
                  elevation: 1.5,
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F2B48),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                folio,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            if (parsedDate != null)
                              Text(
                                dateFormat.format(parsedDate),
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          mainTitle,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        if (subTitle.isNotEmpty)
                          Text(
                            'Contacto: $subTitle',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          ),
                        if (tech.isNotEmpty)
                          Text(
                            'Técnico: $tech',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                              tooltip: 'Eliminar',
                              onPressed: () => _deleteReport(item),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              ),
                              icon: const Icon(Icons.picture_as_pdf, size: 16, color: Color(0xFF0F2B48)),
                              label: const Text('Ver PDF', style: TextStyle(color: Color(0xFF0F2B48))),
                              onPressed: () => _openViewer(item),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.green.shade700,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              ),
                              icon: const Icon(Icons.share, size: 16),
                              label: const Text('Enviar'),
                              onPressed: () => _shareReport(item),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Visor del PDF guardado con zoom y opción de compartir
class _SavedPdfViewerScreen extends StatelessWidget {
  final String title;
  final String filePath;
  final String folio;
  final String clientName;

  const _SavedPdfViewerScreen({
    required this.title,
    required this.filePath,
    this.folio = '',
    this.clientName = '',
  });

  String _buildFileName() {
    final cleanFolio = folio.trim().replaceAll(RegExp(r'[^\w-]'), '_');
    final cleanClient = clientName
        .trim()
        .replaceAll(RegExp(r'[^\wáéíóúÁÉÍÓÚñÑ\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '_');

    if (cleanClient.isEmpty) {
      return cleanFolio.isEmpty ? 'Reporte.pdf' : 'Reporte_$cleanFolio.pdf';
    }
    return 'Reporte_${cleanFolio}_$cleanClient.pdf';
  }

  Future<void> _share(BuildContext context) async {
    final file = File(filePath);
    if (!await file.exists()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El archivo PDF no se encuentra disponible.')),
        );
      }
      return;
    }

    final fileName = _buildFileName();
    try {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$fileName');
      await file.copy(tempFile.path);

      await Share.shareXFiles(
        [XFile(tempFile.path, name: fileName)],
        text: 'Reporte de Servicio de Control de Plagas - Folio $folio',
        subject: 'Reporte de Servicio: ${clientName.isNotEmpty ? clientName : folio}',
      );
    } catch (_) {
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Reporte de Servicio de Control de Plagas - Folio $folio',
        subject: 'Reporte de Servicio: ${clientName.isNotEmpty ? clientName : folio}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final file = File(filePath);
    final screenWidth = MediaQuery.of(context).size.width;
    final fileName = _buildFileName();

    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0F2B48),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Compartir PDF',
            onPressed: () => _share(context),
          ),
        ],
      ),
      body: InteractiveViewer(
        minScale: 1.0,
        maxScale: 3.5,
        panEnabled: true,
        scaleEnabled: true,
        child: PdfPreview(
          build: (format) => file.readAsBytesSync(),
          allowPrinting: false,
          allowSharing: false,
          canChangeOrientation: false,
          canChangePageFormat: false,
          canDebug: false,
          maxPageWidth: screenWidth,
          pdfFileName: fileName,
        ),
      ),
    );
  }
}