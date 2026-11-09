import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/contract_model.dart';
import '../../services/google_drive_sync_service.dart';
import 'contract_preview_screen.dart';

class ContractHistoryScreen extends StatefulWidget {
  const ContractHistoryScreen({super.key});

  @override
  State<ContractHistoryScreen> createState() => _ContractHistoryScreenState();
}

class _ContractHistoryScreenState extends State<ContractHistoryScreen> {
  static const String _contractsHistoryKey = 'ej_contracts_history_list';
  List<Map<String, dynamic>> _allContracts = [];
  List<Map<String, dynamic>> _filteredContracts = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _selectedStatusFilter = 'Todos'; // 'Todos', 'Vigentes', 'Por Vencer', 'Vencidos'

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _syncContractsInBackground();
  }

  Future<void> _syncContractsInBackground() async {
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

  Future<void> _syncFromDrive() async {
    final drive = GoogleDriveSyncService();
    if (!drive.isSignedIn) {
      await drive.initSilently();
    }
    if (!drive.isSignedIn) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Conecta Google Drive primero para sincronizar contratos.')),
        );
      }
      return;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
              SizedBox(width: 12),
              Text('Sincronizando contratos con Google Drive...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );
    }
    await drive.pullAndMergeCloudDatabase();
    await drive.discoverDriveDocuments();
    await _loadHistory();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Historial de contratos actualizado!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_contractsHistoryKey);

    if (jsonString != null && jsonString.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(jsonString);
        _allContracts = decoded.map((item) => Map<String, dynamic>.from(item)).toList();
      } catch (e) {
        _allContracts = [];
      }
    } else {
      _allContracts = [];
    }

    _applyFilter();
    setState(() => _isLoading = false);
  }

  void _applyFilter() {
    final query = _searchController.text.trim().toLowerCase();
    final now = DateTime.now();

    setState(() {
      _filteredContracts = _allContracts.where((item) {
        final business = (item['businessName'] ?? '').toString().toLowerCase();
        final client = (item['clientName'] ?? '').toString().toLowerCase();
        final folio = (item['folio'] ?? '').toString().toLowerCase();
        final rfc = (item['rfc'] ?? '').toString().toLowerCase();

        final matchesSearch = query.isEmpty ||
            business.contains(query) ||
            client.contains(query) ||
            folio.contains(query) ||
            rfc.contains(query);

        if (!matchesSearch) return false;

        DateTime? endDate;
        if (item['endDate'] != null) {
          try {
            endDate = DateTime.parse(item['endDate']);
          } catch (_) {}
        }

        if (_selectedStatusFilter == 'Todos') return true;
        if (endDate == null) return true;

        final daysLeft = endDate.difference(now).inDays;
        if (_selectedStatusFilter == 'Vigentes') {
          return daysLeft >= 0;
        } else if (_selectedStatusFilter == 'Por Vencer') {
          return daysLeft >= 0 && daysLeft <= 30;
        } else if (_selectedStatusFilter == 'Vencidos') {
          return daysLeft < 0;
        }

        return true;
      }).toList();
    });
  }

  Future<void> _shareContract(Map<String, dynamic> item) async {
    final folio = (item['folio'] ?? '').toString().trim();
    final client = ((item['businessName'] != null && item['businessName'].toString().trim().isNotEmpty)
            ? item['businessName']
            : (item['clientName'] ?? ''))
        .toString()
        .trim();

    final cleanFolio = folio.replaceAll(RegExp(r'[^\w-]'), '_');
    final cleanClient = client
        .replaceAll(RegExp(r'[^\wáéíóúÁÉÍÓÚñÑ\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '_');

    final fileName = cleanClient.isEmpty ? 'Contrato_$cleanFolio.pdf' : 'Contrato_${cleanFolio}_$cleanClient.pdf';

    final pdfPath = item['pdfPath'] as String?;
    File? file = (pdfPath != null && pdfPath.isNotEmpty && File(pdfPath).existsSync()) ? File(pdfPath) : null;

    if (file == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                SizedBox(width: 12),
                Text('Descargando contrato desde Google Drive...'),
              ],
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }
      file = await GoogleDriveSyncService().downloadDocumentPdf(
        clientName: client,
        documentType: 'Contrato',
        folio: folio,
      );
      if (file != null && file.existsSync()) {
        item['pdfPath'] = file.path;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_contractsHistoryKey, jsonEncode(_allContracts));
      }
    }

    if (file != null && file.existsSync()) {
      try {
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/$fileName');
        await file.copy(tempFile.path);

        await Share.shareXFiles(
          [XFile(tempFile.path, name: fileName)],
          text: 'Póliza de Servicio de Control de Plagas - Folio $folio',
          subject: 'Contrato: $client',
        );
        return;
      } catch (_) {}
    }

    // Si no está en disco ni en Drive, reconstruimos el modelo y abrimos vista previa
    try {
      final model = ContractModel.fromMap(item);
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ContractPreviewScreen(contract: model)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al preparar el archivo: $e')),
        );
      }
    }
  }

  void _openViewer(Map<String, dynamic> item) async {
    String? pdfPath = item['pdfPath'] as String?;
    File? file = (pdfPath != null && pdfPath.isNotEmpty) ? File(pdfPath) : null;

    if (file == null || !file.existsSync()) {
      final client = (item['businessName'] ?? item['clientName'] ?? '').toString().trim();
      final folio = (item['folio'] ?? '').toString().trim();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                SizedBox(width: 12),
                Text('Descargando contrato desde Google Drive...'),
              ],
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }

      file = await GoogleDriveSyncService().downloadDocumentPdf(
        clientName: client,
        documentType: 'Contrato',
        folio: folio,
      );

      if (file != null && file.existsSync()) {
        item['pdfPath'] = file.path;
        pdfPath = file.path;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_contractsHistoryKey, jsonEncode(_allContracts));
      }
    }

    if (pdfPath != null && File(pdfPath).existsSync()) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => _SavedContractViewer(
            title: 'Contrato: ${item['folio']}',
            filePath: pdfPath!,
            folio: (item['folio'] ?? '').toString(),
            clientName: (item['businessName'] ?? item['clientName'] ?? '').toString(),
          ),
        ),
      );
      return;
    }

    try {
      final model = ContractModel.fromMap(item);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ContractPreviewScreen(contract: model)),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo encontrar el archivo del contrato.')),
        );
      }
    }
  }

  Future<void> _deleteContract(Map<String, dynamic> item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar Contrato?'),
        content: Text('Se eliminará permanentemente la póliza con folio ${item['folio']} del dispositivo.'),
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
        final pdfPath = item['pdfPath'] as String?;
        if (pdfPath != null) {
          final file = File(pdfPath);
          if (await file.exists()) await file.delete();
        }

        _allContracts.removeWhere((c) => c['folio'] == item['folio']);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_contractsHistoryKey, jsonEncode(_allContracts));

        _applyFilter();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Contrato eliminado correctamente.')),
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

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Contratos', style: TextStyle(fontWeight: FontWeight.bold)),
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
          // Barra de búsqueda y filtros
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar por empresa, cliente, folio o RFC...',
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF0F2B48)),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _applyFilter();
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onChanged: (val) => _applyFilter(),
                ),
                const SizedBox(height: 8),

                // Filtros de estado
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['Todos', 'Vigentes', 'Por Vencer', 'Vencidos'].map((status) {
                      final isSelected = _selectedStatusFilter == status;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(status, style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? Colors.white : const Color(0xFF0F2B48),
                          )),
                          selected: isSelected,
                          selectedColor: const Color(0xFF0F2B48),
                          backgroundColor: Colors.grey.shade100,
                          showCheckmark: false,
                          onSelected: (val) {
                            if (val) {
                              setState(() => _selectedStatusFilter = status);
                              _applyFilter();
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Lista de Contratos
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F2B48)))
                : _filteredContracts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.assignment_late_outlined, size: 54, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              _searchController.text.isNotEmpty
                                  ? 'No se encontraron contratos con ese criterio'
                                  : 'Aún no tienes contratos ni pólizas generadas',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _filteredContracts.length,
                        itemBuilder: (context, idx) {
                          final item = _filteredContracts[idx];
                          final folio = item['folio'] ?? 'S/F';
                          final business = (item['businessName'] != null && item['businessName'].toString().isNotEmpty)
                              ? item['businessName']
                              : item['clientName'] ?? 'Cliente sin nombre';
                          final rfc = item['rfc'] ?? '';
                          final durationMonths = item['durationMonths'] ?? 12;

                          DateTime? startDate;
                          DateTime? endDate;
                          if (item['startDate'] != null) {
                            try {
                              startDate = DateTime.parse(item['startDate']);
                            } catch (_) {}
                          }
                          if (item['endDate'] != null) {
                            try {
                              endDate = DateTime.parse(item['endDate']);
                            } catch (_) {}
                          }

                          // Estado de la Póliza
                          String statusText = 'Vigente';
                          Color statusColor = Colors.green;
                          if (endDate != null) {
                            final diff = endDate.difference(now).inDays;
                            if (diff < 0) {
                              statusText = 'Vencida';
                              statusColor = Colors.red;
                            } else if (diff <= 30) {
                              statusText = 'Por Vencer ($diff d)';
                              statusColor = Colors.orange.shade800;
                            }
                          }

                          final monthlyCost = (item['monthlyCost'] is num) ? (item['monthlyCost'] as num).toDouble() : 0.0;
                          final totalCost = (item['totalContractCost'] is num) ? (item['totalContractCost'] as num).toDouble() : 0.0;
                          final repName = item['representativeName'] ?? '';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 1.5,
                            child: Padding(
                              padding: const EdgeInsets.all(14),
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
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          folio,
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: statusColor.withOpacity(0.4), width: 0.8),
                                        ),
                                        child: Text(
                                          statusText,
                                          style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  Text(
                                    business,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F2B48)),
                                  ),
                                  if (rfc.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text('RFC: $rfc', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                                  ],
                                  if (repName.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text('Firmante: $repName', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey.shade800)),
                                  ],
                                  const SizedBox(height: 8),

                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF4F6F9),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Vigencia ($durationMonths m):', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                                            Text(
                                              (startDate != null && endDate != null)
                                                  ? '${dateFormat.format(startDate)} al ${dateFormat.format(endDate)}'
                                                  : '$durationMonths meses',
                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text('Mensual: ${currencyFormat.format(monthlyCost)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F2B48))),
                                            Text('Total: ${currencyFormat.format(totalCost)}', style: TextStyle(fontSize: 10, color: Colors.grey.shade700)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 10),

                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                        tooltip: 'Eliminar',
                                        onPressed: () => _deleteContract(item),
                                      ),
                                      const SizedBox(width: 8),
                                      OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          side: const BorderSide(color: Color(0xFF0F2B48)),
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
                                        onPressed: () => _shareContract(item),
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

class _SavedContractViewer extends StatelessWidget {
  final String title;
  final String filePath;
  final String folio;
  final String clientName;

  const _SavedContractViewer({
    required this.title,
    required this.filePath,
    required this.folio,
    required this.clientName,
  });

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

    final cleanFolio = folio.replaceAll(RegExp(r'[^\w-]'), '_');
    final cleanClient = clientName
        .replaceAll(RegExp(r'[^\wáéíóúÁÉÍÓÚñÑ\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '_');

    final fileName = cleanClient.isEmpty ? 'Contrato_$cleanFolio.pdf' : 'Contrato_${cleanFolio}_$cleanClient.pdf';

    try {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$fileName');
      await file.copy(tempFile.path);

      await Share.shareXFiles(
        [XFile(tempFile.path, name: fileName)],
        text: 'Póliza de Servicio de Control de Plagas - Folio $folio',
        subject: 'Contrato: $clientName',
      );
    } catch (_) {
      await Share.shareXFiles([XFile(file.path)], text: 'Póliza $folio');
    }
  }

  @override
  Widget build(BuildContext context) {
    final file = File(filePath);
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0F2B48),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Compartir Contrato',
            onPressed: () => _share(context),
          ),
        ],
      ),
      body: PdfPreview(
        build: (format) => file.readAsBytesSync(),
        allowPrinting: false,
        allowSharing: false,
        canChangeOrientation: false,
        canChangePageFormat: false,
      ),
    );
  }
}
