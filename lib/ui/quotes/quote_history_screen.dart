import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/google_drive_sync_service.dart';

class QuoteHistoryScreen extends StatefulWidget {
  const QuoteHistoryScreen({super.key});

  @override
  State<QuoteHistoryScreen> createState() => _QuoteHistoryScreenState();
}

class _QuoteHistoryScreenState extends State<QuoteHistoryScreen> {
  static const String _quotesHistoryKey = 'ej_quotes_history_list';
  List<Map<String, dynamic>> _allQuotes = [];
  List<Map<String, dynamic>> _filteredQuotes = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String? _selectedClientFilter;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    // Auto-sincronizar en segundo plano al entrar
    if (GoogleDriveSyncService().isSignedIn) {
      GoogleDriveSyncService().pullAndMergeCloudDatabase().then((merged) async {
        final discovered = await GoogleDriveSyncService().discoverDriveDocuments();
        if ((merged || discovered > 0) && mounted) {
          _loadHistory();
        }
      });
    }
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_quotesHistoryKey);

    if (raw != null && raw.isNotEmpty) {
      final List decoded = jsonDecode(raw);
      _allQuotes = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } else {
      _allQuotes = [];
    }

    _applyFilter();
    setState(() => _isLoading = false);
  }

  void _applyFilter() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredQuotes = _allQuotes.where((item) {
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

  Future<void> _shareQuote(Map<String, dynamic> quote) async {
    final filePath = quote['filePath'] as String?;
    File? file = (filePath != null && filePath.isNotEmpty) ? File(filePath) : null;

    final folio = (quote['folio'] ?? '').toString().trim();
    final clientTitle = (quote['businessName'] != null && quote['businessName'].toString().trim().isNotEmpty)
        ? quote['businessName'].toString().trim()
        : (quote['clientName'] ?? '').toString().trim();

    // Si el archivo físico no existe en este dispositivo (ej. restaurado en otro teléfono), descargarlo de Drive
    if (file == null || !file.existsSync()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                SizedBox(width: 12),
                Text('Descargando cotización desde Google Drive...'),
              ],
            ),
            duration: Duration(seconds: 4),
          ),
        );
      }

      file = await GoogleDriveSyncService().downloadDocumentPdf(
        clientName: clientTitle,
        documentType: 'Cotización',
        folio: folio,
      );

      if (file == null || !file.existsSync()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo encontrar la cotización en Google Drive.')),
          );
        }
        return;
      }

      // Guardar la nueva ruta local permanente en la memoria del dispositivo
      quote['filePath'] = file.path;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_quotesHistoryKey, jsonEncode(_allQuotes));
    }

    final cleanFolio = folio.replaceAll(RegExp(r'[^\w-]'), '_');
    final cleanClient = clientTitle
        .replaceAll(RegExp(r'[^\wáéíóúÁÉÍÓÚñÑ\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '_');

    final fileName = cleanClient.isEmpty
        ? (cleanFolio.isEmpty ? 'Cotizacion.pdf' : 'Cotizacion_$cleanFolio.pdf')
        : 'Cotizacion_${cleanFolio}_$cleanClient.pdf';

    try {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$fileName');
      await file!.copy(tempFile.path);

      await Share.shareXFiles(
        [XFile(tempFile.path, name: fileName)],
        text: 'Cotización de Servicios de Control de Plagas - Folio $folio',
        subject: 'Cotización: ${clientTitle.isNotEmpty ? clientTitle : folio}',
      );
    } catch (_) {
      await Share.shareXFiles(
        [XFile(file!.path)],
        text: 'Cotización de Servicios de Control de Plagas - Folio $folio',
        subject: 'Cotización: ${clientTitle.isNotEmpty ? clientTitle : folio}',
      );
    }
  }

  Future<void> _openViewer(Map<String, dynamic> quote) async {
    final filePath = quote['filePath'] as String?;
    File? file = (filePath != null && filePath.isNotEmpty) ? File(filePath) : null;

    final folio = (quote['folio'] ?? '').toString().trim();
    final clientTitle = (quote['businessName'] != null && quote['businessName'].toString().trim().isNotEmpty)
        ? quote['businessName'].toString().trim()
        : (quote['clientName'] ?? '').toString().trim();

    // Si el archivo físico no existe en este dispositivo (ej. restaurado en otro teléfono), descargarlo de Drive
    if (file == null || !file.existsSync()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                SizedBox(width: 12),
                Text('Descargando cotización desde Google Drive...'),
              ],
            ),
            duration: Duration(seconds: 4),
          ),
        );
      }

      file = await GoogleDriveSyncService().downloadDocumentPdf(
        clientName: clientTitle,
        documentType: 'Cotización',
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

      // Guardar la nueva ruta local permanente para aperturas instantáneas futuras
      quote['filePath'] = file.path;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_quotesHistoryKey, jsonEncode(_allQuotes));
    }

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _SavedQuoteViewerScreen(
          title: 'Cotización: $folio',
          filePath: file!.path,
          folio: folio,
          clientName: clientTitle,
        ),
      ),
    );
  }

  Future<void> _deleteQuote(Map<String, dynamic> quote) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar Cotización?'),
        content: Text('Se eliminará permanentemente la cotización con folio ${quote['folio']} de tu dispositivo.'),
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
        final filePath = quote['filePath'] as String?;
        if (filePath != null) {
          final file = File(filePath);
          if (await file.exists()) await file.delete();
        }

        _allQuotes.removeWhere((item) => item['folio'] == quote['folio']);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_quotesHistoryKey, jsonEncode(_allQuotes));

        _applyFilter();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cotización eliminada correctamente.')),
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            SizedBox(width: 12),
            Text('Sincronizando cotizaciones con Google Drive...'),
          ],
        ),
        duration: Duration(seconds: 2),
      ),
    );
    await GoogleDriveSyncService().pullAndMergeCloudDatabase();
    await GoogleDriveSyncService().discoverDriveDocuments();
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
    final currency = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

    final Set<String> clientNames = {};
    for (var q in _allQuotes) {
      final name = (q['businessName'] != null && q['businessName'].toString().isNotEmpty)
          ? q['businessName'].toString()
          : (q['clientName'] ?? '').toString();
      if (name.isNotEmpty) clientNames.add(name);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Cotizaciones', style: TextStyle(fontWeight: FontWeight.bold)),
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
                hintText: 'Buscar cotización por cliente o folio...',
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

          // Filtro por cliente
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

          // Lista
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F2B48)))
                : RefreshIndicator(
                    onRefresh: _syncFromDrive,
                    child: _filteredQuotes.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.request_quote_outlined, size: 64, color: Colors.grey.shade400),
                                    const SizedBox(height: 12),
                                    Text(
                                      _searchController.text.isNotEmpty
                                          ? 'No se encontraron cotizaciones para esa búsqueda.'
                                          : 'Aún no tienes cotizaciones guardadas.',
                                      style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Desliza hacia abajo o pulsa el icono de sincronizar arriba',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              itemCount: _filteredQuotes.length,
              itemBuilder: (context, index) {
                final q = _filteredQuotes[index];
                final clientTitle = (q['businessName'] != null && q['businessName'].toString().isNotEmpty)
                    ? q['businessName']
                    : q['clientName'] ?? 'Sin Nombre';

                final contact = q['clientName'] ?? '';
                final folio = q['folio'] ?? 'S/F';
                final total = (q['totalAmount'] as num?)?.toDouble() ?? 0.0;
                final dateStr = q['quoteDate'] != null
                    ? dateFormat.format(DateTime.tryParse(q['quoteDate']) ?? DateTime.now())
                    : '';

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _openViewer(q),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F2B48).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  folio,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F2B48),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              Text(
                                currency.format(total),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E6091),
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            clientTitle,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          if (contact.isNotEmpty && contact != clientTitle) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Contacto: $contact',
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.calendar_today, size: 13, color: Colors.grey.shade600),
                                  const SizedBox(width: 4),
                                  Text(
                                    dateStr,
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.share, size: 20, color: Color(0xFF1E6091)),
                                    tooltip: 'Compartir',
                                    onPressed: () => _shareQuote(q),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                                    tooltip: 'Eliminar',
                                    onPressed: () => _deleteQuote(q),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        ],
      ),
    );
  }
}

class _SavedQuoteViewerScreen extends StatelessWidget {
  final String title;
  final String filePath;
  final String folio;
  final String clientName;

  const _SavedQuoteViewerScreen({
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
      return cleanFolio.isEmpty ? 'Cotizacion.pdf' : 'Cotizacion_$cleanFolio.pdf';
    }
    return 'Cotizacion_${cleanFolio}_$cleanClient.pdf';
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
        text: 'Cotización de Servicios de Control de Plagas - Folio $folio',
        subject: 'Cotización: ${clientName.isNotEmpty ? clientName : folio}',
      );
    } catch (_) {
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Cotización de Servicios de Control de Plagas - Folio $folio',
        subject: 'Cotización: ${clientName.isNotEmpty ? clientName : folio}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final file = File(filePath);
    final fileName = _buildFileName();

    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0F2B48),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Compartir Cotización',
            onPressed: () => _share(context),
          ),
        ],
      ),
      body: PdfPreview(
        build: (format) => file.readAsBytesSync(),
        allowPrinting: false,
        allowSharing: false,
        canChangePageFormat: false,
        canChangeOrientation: false,
        pdfFileName: fileName,
      ),
    );
  }
}
