import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/invoice_model.dart';
import '../../services/client_service.dart';
import '../../services/google_drive_sync_service.dart';
import '../clients/clients_directory_screen.dart';
import '../cloud/google_drive_sync_screen.dart';
import '../contracts/contract_history_screen.dart';
import '../home_screen.dart';
import '../layouts/trap_layouts_history_screen.dart';
import '../quotes/quote_form_screen.dart';
import '../resources/resources_hub_screen.dart';
import '../schedule/schedule_history_screen.dart';

/// Panel de Control de Escritorio Profesional (macOS, Windows y Web)
/// Diseñado con menú lateral corporativo, métricas en vivo y visor integrado en pantalla grande.
class DesktopDashboardScreen extends StatefulWidget {
  const DesktopDashboardScreen({super.key});

  @override
  State<DesktopDashboardScreen> createState() => _DesktopDashboardScreenState();
}

class _DesktopDashboardScreenState extends State<DesktopDashboardScreen> {
  int _selectedModuleIndex = 0; // 0: Reportes, 1: Cotizaciones, 2: Agenda, 3: Facturas, ...

  // Métricas
  int _clientCount = 0;
  int _reportCount = 0;
  int _quoteCount = 0;
  int _scheduleCount = 0;
  int _contractCount = 0;
  int _pendingInvoiceCount = 0;

  // Listas de datos para visor dividido
  List<Map<String, dynamic>> _reports = [];
  Map<String, dynamic>? _selectedReport;

  List<Map<String, dynamic>> _quotes = [];
  Map<String, dynamic>? _selectedQuote;

  List<InvoiceModel> _invoices = [];
  InvoiceModel? _selectedInvoice;
  File? _selectedInvoiceFile;
  bool _isLoadingInvoiceFile = false;

  final GoogleDriveSyncService _driveService = GoogleDriveSyncService();
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchFilter = '';
  String? _selectedReportClientFilter;
  String? _selectedQuoteClientFilter;
  String _selectedInvoiceStatusFilter = 'pending';
  bool _isLoadingPdf = false;
  bool _isCloudSyncing = false;
  String? _loadingDocId;
  final Set<String> _failedDownloads = {};

  Future<void> _onSelectReport(Map<String, dynamic> item) async {
    final folio = (item['folio'] ?? 'S_N').toString();
    final clientName = (item['businessName'] ?? item['clientName'] ?? '').toString();
    final currentPath = item['filePath'] as String?;
    final localExists = currentPath != null && currentPath.isNotEmpty && File(currentPath).existsSync();

    _failedDownloads.remove('Reporte-$folio');

    setState(() {
      _selectedReport = item;
      _isLoadingPdf = !localExists;
      _loadingDocId = 'Reporte-$folio';
    });

    if (!localExists) {
      try {
        final downloaded = await _driveService.downloadDocumentPdf(
          clientName: clientName,
          documentType: 'Reporte',
          folio: folio,
        );
        if (mounted && _selectedReport != null && _selectedReport!['folio'].toString() == folio) {
          if (downloaded != null && downloaded.existsSync()) {
            setState(() {
              _selectedReport!['filePath'] = downloaded.path;
              item['filePath'] = downloaded.path;
              _isLoadingPdf = false;
              _loadingDocId = null;
            });
            try {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('ej_reports_history_list', jsonEncode(_reports));
            } catch (_) {}
          } else {
            setState(() {
              _failedDownloads.add('Reporte-$folio');
              _isLoadingPdf = false;
              _loadingDocId = null;
            });
          }
        }
      } catch (e) {
        if (mounted && _selectedReport != null && _selectedReport!['folio'].toString() == folio) {
          setState(() {
            _failedDownloads.add('Reporte-$folio');
            _isLoadingPdf = false;
            _loadingDocId = null;
          });
        }
      }
    }
  }

  Future<void> _onSelectQuote(Map<String, dynamic> item) async {
    final folio = (item['folio'] ?? 'S_N').toString();
    final clientName = (item['businessName'] ?? item['clientName'] ?? '').toString();
    final currentPath = item['filePath'] as String?;
    final localExists = currentPath != null && currentPath.isNotEmpty && File(currentPath).existsSync();

    _failedDownloads.remove('Cotización-$folio');

    setState(() {
      _selectedQuote = item;
      _isLoadingPdf = !localExists;
      _loadingDocId = 'Cotización-$folio';
    });

    if (!localExists) {
      try {
        final downloaded = await _driveService.downloadDocumentPdf(
          clientName: clientName,
          documentType: 'Cotización',
          folio: folio,
        );
        if (mounted && _selectedQuote != null && _selectedQuote!['folio'].toString() == folio) {
          if (downloaded != null && downloaded.existsSync()) {
            setState(() {
              _selectedQuote!['filePath'] = downloaded.path;
              item['filePath'] = downloaded.path;
              _isLoadingPdf = false;
              _loadingDocId = null;
            });
            try {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('ej_quotes_history_list', jsonEncode(_quotes));
            } catch (_) {}
          } else {
            setState(() {
              _failedDownloads.add('Cotización-$folio');
              _isLoadingPdf = false;
              _loadingDocId = null;
            });
          }
        }
      } catch (e) {
        if (mounted && _selectedQuote != null && _selectedQuote!['folio'].toString() == folio) {
          setState(() {
            _failedDownloads.add('Cotización-$folio');
            _isLoadingPdf = false;
            _loadingDocId = null;
          });
        }
      }
    }
  }

  Future<void> _onSelectInvoice(InvoiceModel inv) async {
    setState(() {
      _selectedInvoice = inv;
      _selectedInvoiceFile = null;
      _isLoadingInvoiceFile = true;
    });
    try {
      final file = await _driveService.downloadInvoicePdf(inv);
      if (mounted && _selectedInvoice?.id == inv.id) {
        setState(() {
          _selectedInvoiceFile = file;
          _isLoadingInvoiceFile = false;
        });
      }
    } catch (_) {
      if (mounted && _selectedInvoice?.id == inv.id) {
        setState(() {
          _isLoadingInvoiceFile = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAllData({bool syncFromCloud = true}) async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Clientes
    final clients = await ClientService().getSavedClients();

    // 2. Reportes
    final rawReports = prefs.getString('ej_reports_history_list');
    final reportsList = (rawReports != null && rawReports.isNotEmpty)
        ? List<Map<String, dynamic>>.from(jsonDecode(rawReports))
        : <Map<String, dynamic>>[];

    // 3. Cotizaciones
    final rawQuotes = prefs.getString('ej_quotes_history_list');
    final quotesList = (rawQuotes != null && rawQuotes.isNotEmpty)
        ? List<Map<String, dynamic>>.from(jsonDecode(rawQuotes))
        : <Map<String, dynamic>>[];

    // 4. Agendas y Contratos
    final rawSchedules = prefs.getString('ej_schedules_history_list');
    final schedulesList = (rawSchedules != null && rawSchedules.isNotEmpty) ? jsonDecode(rawSchedules) : [];

    final rawContracts = prefs.getString('ej_contracts_history_list');
    final contractsList = (rawContracts != null && rawContracts.isNotEmpty) ? jsonDecode(rawContracts) : [];

    // 5. Facturas desde caché local primero para rapidez inmediata
    final cachedInvoices = await _driveService.getCachedInvoices();
    final pendingInvs = cachedInvoices.where((i) => i.status == 'pending').toList();

    if (mounted) {
      setState(() {
        _clientCount = clients.length;
        _reportCount = reportsList.length;
        _quoteCount = quotesList.length;
        _scheduleCount = (schedulesList as List).length;
        _contractCount = (contractsList as List).length;
        _reports = reportsList;
        _quotes = quotesList;
        _invoices = cachedInvoices;
        _pendingInvoiceCount = pendingInvs.length;

        if (_reports.isNotEmpty && _selectedReport == null) {
          _selectedReport = _reports.first;
          _onSelectReport(_reports.first);
        }
        if (_quotes.isNotEmpty && _selectedQuote == null) {
          _selectedQuote = _quotes.first;
        }
        if (_invoices.isNotEmpty && _selectedInvoice == null) {
          final pending = _invoices.where((i) => i.status == 'pending').toList();
          _selectedInvoice = pending.isNotEmpty ? pending.first : _invoices.first;
        }
      });
    }

    if (syncFromCloud && !_isCloudSyncing) {
      _isCloudSyncing = true;
      try {
        if (!_driveService.isSignedIn) {
          await _driveService.initSilently();
          if (mounted) setState(() {});
        }

        if (_driveService.isSignedIn) {
          // Refrescar facturas en segundo plano
          final freshInvoices = await _driveService.fetchInvoices();
          if (mounted) {
            setState(() {
              _invoices = freshInvoices;
              final freshPending = freshInvoices.where((i) => i.status == 'pending').toList();
              _pendingInvoiceCount = freshPending.length;
              if (_selectedInvoiceStatusFilter == 'pending') {
                if (_selectedInvoice != null && _selectedInvoice!.status != 'pending') {
                  if (freshPending.isNotEmpty) {
                    _onSelectInvoice(freshPending.first);
                  } else {
                    _selectedInvoice = null;
                    _selectedInvoiceFile = null;
                  }
                }
              }
            });
          }

          // Sincronización bidireccional segura (Copia Maestra + archivos en Drive), sin bucle recursivo
          final merged = await _driveService.pullAndMergeCloudDatabase();
          final discovered = await _driveService.discoverDriveDocuments();
          if ((merged || discovered > 0) && mounted) {
            await _loadAllData(syncFromCloud: false);
          }
        }
      } finally {
        _isCloudSyncing = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Row(
        children: [
          // 1. BARRA LATERAL IZQUIERDA (Sidebar Oficial)
          _buildSidebar(),

          // 2. ÁREA DE TRABAJO PRINCIPAL
          Expanded(
            child: Column(
              children: [
                // Barra superior de herramientas y acciones
                _buildTopHeader(),

                // Barra de métricas (KPIs rápidos)
                _buildMetricsRow(),

                // Contenido dinámico del módulo seleccionado
                Expanded(child: _buildModuleContent()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- BARRA LATERAL IZQUIERDA ---
  Widget _buildSidebar() {
    return Container(
      width: 260,
      color: const Color(0xFF0F2B48),
      child: Column(
        children: [
          // Logo y Encabezado
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
            color: const Color(0xFF0A1F35),
            child: Row(
              children: [
                Image.asset(
                  'assets/images/logo.png',
                  width: 38,
                  height: 38,
                  errorBuilder: (_, __, _) => Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.amber.shade400,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Text('EJ', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F2B48), fontSize: 18)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'EJ EXTERMINADORES',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Centro de Operaciones',
                        style: TextStyle(color: Colors.amberAccent, fontSize: 10, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Lista de Módulos (En el orden exacto solicitado)
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
              children: [
                _sidebarSectionHeader('OPERACIÓN DIARIA'),
                _sidebarItem(0, Icons.assignment_outlined, 'Reportes de Servicio', badge: '$_reportCount'),
                _sidebarItem(1, Icons.request_quote_outlined, 'Cotizaciones', badge: '$_quoteCount'),
                _sidebarItem(2, Icons.calendar_today_outlined, 'Agenda y Calendario', badge: '$_scheduleCount'),
                _sidebarItem(
                  3,
                  Icons.receipt_long_outlined,
                  'Facturación CFDI',
                  badge: _pendingInvoiceCount > 0 ? '$_pendingInvoiceCount cobros' : null,
                  badgeColor: const Color(0xFFE11D48),
                  iconColor: const Color(0xFF6EE7B7),
                ),
                _sidebarItem(4, Icons.picture_as_pdf_outlined, 'Cronogramas (PDF)'),
                _sidebarItem(5, Icons.draw_outlined, 'Pólizas y Contratos', badge: '$_contractCount'),
                _sidebarItem(6, Icons.architecture_outlined, 'Planos y Layouts'),
                _sidebarItem(7, Icons.people_alt_outlined, 'Directorio de Clientes', badge: '$_clientCount'),
                const SizedBox(height: 12),
                _sidebarSectionHeader('BIBLIOTECA & NUBE'),
                _sidebarItem(8, Icons.menu_book_outlined, 'Documentos Oficiales'),
                _sidebarItem(9, Icons.cloud_done_outlined, 'Nube Google Drive', iconColor: Colors.lightBlueAccent),
              ],
            ),
          ),

          // Perfil y Estado de Drive
          Container(
            padding: const EdgeInsets.all(14),
            color: const Color(0xFF08182B),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: Colors.white24,
                  child: const Text('JL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Jorge Elizondo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      Text(
                        _driveService.isSignedIn ? 'Google Drive Conectado' : 'Drive sin conectar',
                        style: TextStyle(
                          color: _driveService.isSignedIn ? Colors.greenAccent : Colors.amberAccent,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white70, size: 18),
                  tooltip: 'Actualizar Datos',
                  onPressed: _loadAllData,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Text(
        title,
        style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 1.1),
      ),
    );
  }

  Widget _sidebarItem(int index, IconData icon, String label, {String? badge, Color? badgeColor, Color? iconColor}) {
    final isSelected = _selectedModuleIndex == index;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF1E6091) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        leading: Icon(icon, color: iconColor ?? (isSelected ? Colors.amberAccent : Colors.white70), size: 18),
        title: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.85),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        trailing: badge != null
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor ?? (isSelected ? Colors.white24 : Colors.white12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              )
            : null,
        onTap: () {
          setState(() {
            _selectedModuleIndex = index;
            if (index == 3) {
              _selectedInvoiceStatusFilter = 'pending';
            }
          });
          if (index == 0 && _selectedReport != null) {
            final p = _selectedReport!['filePath'] as String?;
            if (p == null || !File(p).existsSync()) {
              _onSelectReport(_selectedReport!);
            }
          } else if (index == 1 && _selectedQuote != null) {
            final p = _selectedQuote!['filePath'] as String?;
            if (p == null || !File(p).existsSync()) {
              _onSelectQuote(_selectedQuote!);
            }
          } else if (index == 3) {
            final pendingInvs = _invoices.where((i) => i.status == 'pending').toList();
            if (pendingInvs.isNotEmpty) {
              if (_selectedInvoice == null || _selectedInvoice!.status != 'pending') {
                _onSelectInvoice(pendingInvs.first);
              } else if (_selectedInvoiceFile == null || !_selectedInvoiceFile!.existsSync()) {
                _onSelectInvoice(_selectedInvoice!);
              }
            } else {
              _selectedInvoice = null;
              _selectedInvoiceFile = null;
            }
          }
        },
      ),
    );
  }

  // --- BARRA SUPERIOR DE HERRAMIENTAS ---
  Widget _buildTopHeader() {
    final dateFormat = DateFormat('EEEE, d \'de\' MMMM \'de\' yyyy', 'es_MX');
    final formattedDate = dateFormat.format(DateTime.now());

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          // Buscador universal
          Expanded(
            child: Container(
              height: 38,
              constraints: const BoxConstraints(maxWidth: 480),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _searchFilter = v.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Buscar por cliente, folio, plaga o químico...',
                  hintStyle: const TextStyle(fontSize: 12, color: Colors.black38),
                  prefixIcon: const Icon(Icons.search, size: 18, color: Colors.black45),
                  suffixIcon: _searchFilter.isNotEmpty
                      ? IconButton(icon: const Icon(Icons.clear, size: 16), onPressed: () => setState(() { _searchCtrl.clear(); _searchFilter = ''; }))
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                ),
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Fecha actual
          Text(
            formattedDate,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 16),

          // Botones de acción rápida
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Nuevo Reporte', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
              _loadAllData();
            },
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F2B48),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.request_quote_outlined, size: 16),
            label: const Text('Nueva Cotización', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const QuoteFormScreen()));
              _loadAllData();
            },
          ),
        ],
      ),
    );
  }

  // --- TARJETAS DE MÉTRICAS (KPIS RÁPIDOS) ---
  Widget _buildMetricsRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          _kpiCard(Icons.people_alt, '$_clientCount', 'Clientes Guardados', 'Sincronizados en Drive', Colors.teal),
          const SizedBox(width: 14),
          _kpiCard(Icons.assignment_turned_in, '$_reportCount', 'Reportes de Servicio', 'Historial completo', const Color(0xFF1E6091)),
          const SizedBox(width: 14),
          _kpiCard(Icons.receipt_long, '$_pendingInvoiceCount', 'Facturas por Cobrar', 'En carpeta Pendientes', const Color(0xFFE11D48), isAlert: _pendingInvoiceCount > 0),
          const SizedBox(width: 14),
          _kpiCard(Icons.calendar_month, '$_scheduleCount', 'Visitas y Agendas', 'Google Calendar activo', Colors.orange),
        ],
      ),
    );
  }

  Widget _kpiCard(IconData icon, String value, String title, String subtitle, Color color, {bool isAlert = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isAlert ? const Color(0xFFFFF1F2) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isAlert ? const Color(0xFFFECDD3) : const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                  Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isAlert ? const Color(0xFFBE123C) : const Color(0xFF0F172A))),
                  Text(subtitle, style: TextStyle(fontSize: 9.5, color: isAlert ? const Color(0xFFE11D48) : const Color(0xFF94A3B8))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- CONTENIDO DINÁMICO POR MÓDULO ---
  Widget _buildModuleContent() {
    switch (_selectedModuleIndex) {
      case 0:
        return _buildSplitReportsView();
      case 1:
        return _buildSplitQuotesView();
      case 2:
        return const ScheduleHistoryScreen(initialTab: 0);
      case 3:
        return _buildSplitInvoicesView();
      case 4:
        return const ScheduleHistoryScreen(initialTab: 2);
      case 5:
        return const ContractHistoryScreen();
      case 6:
        return const TrapLayoutsHistoryScreen();
      case 7:
        return const ClientsDirectoryScreen();
      case 8:
        return const ResourcesHubScreen();
      case 9:
        return GoogleDriveSyncScreen(onDataRestored: _loadAllData);
      default:
        return _buildSplitReportsView();
    }
  }

  // --- VISTA DIVIDIDA: REPORTES DE SERVICIO ---
  Widget _buildSplitReportsView() {
    final clientNames = <String>{};
    for (final r in _reports) {
      final name = (r['businessName'] != null && r['businessName'].toString().trim().isNotEmpty)
          ? r['businessName'].toString().trim()
          : (r['clientName'] ?? '').toString().trim();
      if (name.isNotEmpty) clientNames.add(name);
    }
    final sortedClients = clientNames.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final filtered = _reports.where((r) {
      final client = (r['businessName'] ?? r['clientName'] ?? '').toString();
      final folio = (r['folio'] ?? '').toString().toLowerCase();

      if (_selectedReportClientFilter != null && _selectedReportClientFilter!.isNotEmpty) {
        if (client.trim().toLowerCase() != _selectedReportClientFilter!.trim().toLowerCase()) {
          return false;
        }
      }

      if (_searchFilter.isEmpty) return true;
      return client.toLowerCase().contains(_searchFilter) || folio.contains(_searchFilter);
    }).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Lado Izquierdo: Lista de Reportes
          Container(
            width: 400,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Encabezado
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Historial de Reportes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F2B48))),
                      Text('${filtered.length} encontrados', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    ],
                  ),
                ),

                // Filtro por Cliente
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.people_alt_outlined, size: 16, color: Color(0xFF0F2B48)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            value: _selectedReportClientFilter,
                            isDense: true,
                            isExpanded: true,
                            hint: const Text('Filtrar por cliente...', style: TextStyle(fontSize: 12, color: Color(0xFF475569))),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('Todos los clientes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F2B48))),
                              ),
                              ...sortedClients.map((c) => DropdownMenuItem<String?>(
                                value: c,
                                child: Text(c, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                              )),
                            ],
                            onChanged: (val) {
                              setState(() {
                                _selectedReportClientFilter = val;
                              });
                            },
                          ),
                        ),
                      ),
                      if (_selectedReportClientFilter != null)
                        IconButton(
                          icon: const Icon(Icons.cancel, size: 16, color: Colors.grey),
                          tooltip: 'Mostrar todos',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => setState(() => _selectedReportClientFilter = null),
                        ),
                    ],
                  ),
                ),

                // Lista de Reportes
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(child: Text('No hay reportes registrados.', style: TextStyle(fontSize: 12, color: Colors.black45)))
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          itemBuilder: (context, i) {
                            final item = filtered[i];
                            final isSel = _selectedReport != null && _selectedReport!['folio'] == item['folio'];
                            final clientName = (item['businessName'] ?? item['clientName'] ?? 'Cliente').toString();
                            final folio = (item['folio'] ?? 'S_N').toString();

                            final rawDate = (item['serviceDate'] ?? item['date'] ?? item['createdAt'] ?? '').toString();
                            String formattedDate = '';
                            if (rawDate.isNotEmpty) {
                              final parsed = DateTime.tryParse(rawDate);
                              if (parsed != null) {
                                formattedDate = DateFormat('dd/MM/yyyy').format(parsed);
                              } else {
                                formattedDate = rawDate.split('T').first;
                              }
                            }

                            return ListTile(
                              dense: true,
                              selected: isSel,
                              selectedTileColor: const Color(0xFFE0F2FE),
                              title: Text(clientName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE2E8F0),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text('Folio: $folio', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0F2B48))),
                                    ),
                                    if (formattedDate.isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      const Icon(Icons.calendar_today_outlined, size: 11, color: Color(0xFF64748B)),
                                      const SizedBox(width: 3),
                                      Text(formattedDate, style: const TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.w600)),
                                    ],
                                  ],
                                ),
                              ),
                              trailing: const Icon(Icons.chevron_right, size: 16, color: Colors.black38),
                              onTap: () => _onSelectReport(item),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // Lado Derecho: Visor de PDF Integrado
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: _selectedReport == null
                  ? const Center(child: Text('Selecciona un reporte para visualizar el PDF', style: TextStyle(color: Colors.black45)))
                  : _buildPdfViewerPane(
                      title: 'Reporte Folio: ${_selectedReport!['folio']}',
                      clientName: (_selectedReport!['businessName'] ?? _selectedReport!['clientName'] ?? '').toString(),
                      filePath: _selectedReport!['filePath'] as String?,
                      documentType: 'Reporte',
                      folio: (_selectedReport!['folio'] ?? '').toString(),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // --- VISTA DIVIDIDA: COTIZACIONES ---
  Widget _buildSplitQuotesView() {
    final clientNames = <String>{};
    for (final q in _quotes) {
      final name = (q['businessName'] != null && q['businessName'].toString().trim().isNotEmpty)
          ? q['businessName'].toString().trim()
          : (q['clientName'] ?? '').toString().trim();
      if (name.isNotEmpty) clientNames.add(name);
    }
    final sortedClients = clientNames.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final filtered = _quotes.where((q) {
      final client = (q['businessName'] ?? q['clientName'] ?? '').toString();
      final folio = (q['folio'] ?? '').toString().toLowerCase();

      if (_selectedQuoteClientFilter != null && _selectedQuoteClientFilter!.isNotEmpty) {
        if (client.trim().toLowerCase() != _selectedQuoteClientFilter!.trim().toLowerCase()) {
          return false;
        }
      }

      if (_searchFilter.isEmpty) return true;
      return client.toLowerCase().contains(_searchFilter) || folio.contains(_searchFilter);
    }).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 400,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Encabezado
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Historial de Cotizaciones', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F2B48))),
                      Text('${filtered.length} cotizaciones', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    ],
                  ),
                ),

                // Filtro por Cliente
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.people_alt_outlined, size: 16, color: Color(0xFF0F2B48)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            value: _selectedQuoteClientFilter,
                            isDense: true,
                            isExpanded: true,
                            hint: const Text('Filtrar por cliente...', style: TextStyle(fontSize: 12, color: Color(0xFF475569))),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('Todos los clientes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F2B48))),
                              ),
                              ...sortedClients.map((c) => DropdownMenuItem<String?>(
                                value: c,
                                child: Text(c, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                              )),
                            ],
                            onChanged: (val) {
                              setState(() {
                                _selectedQuoteClientFilter = val;
                              });
                            },
                          ),
                        ),
                      ),
                      if (_selectedQuoteClientFilter != null)
                        IconButton(
                          icon: const Icon(Icons.cancel, size: 16, color: Colors.grey),
                          tooltip: 'Mostrar todos',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => setState(() => _selectedQuoteClientFilter = null),
                        ),
                    ],
                  ),
                ),

                // Lista de Cotizaciones
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(child: Text('No hay cotizaciones registradas.', style: TextStyle(fontSize: 12, color: Colors.black45)))
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          itemBuilder: (context, i) {
                            final item = filtered[i];
                            final isSel = _selectedQuote != null && _selectedQuote!['folio'] == item['folio'];
                            final clientName = (item['businessName'] ?? item['clientName'] ?? 'Cliente').toString();
                            final folio = (item['folio'] ?? 'S_N').toString();
                            final total = (item['total'] ?? item['amount'] ?? '').toString();

                            final rawDate = (item['quoteDate'] ?? item['date'] ?? item['createdAt'] ?? '').toString();
                            String formattedDate = '';
                            if (rawDate.isNotEmpty) {
                              final parsed = DateTime.tryParse(rawDate);
                              if (parsed != null) {
                                formattedDate = DateFormat('dd/MM/yyyy').format(parsed);
                              } else {
                                formattedDate = rawDate.split('T').first;
                              }
                            }

                            return ListTile(
                              dense: true,
                              selected: isSel,
                              selectedTileColor: const Color(0xFFE0F2FE),
                              title: Text(clientName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE2E8F0),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text('Folio: $folio', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0F2B48))),
                                    ),
                                    if (formattedDate.isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      const Icon(Icons.calendar_today_outlined, size: 11, color: Color(0xFF64748B)),
                                      const SizedBox(width: 3),
                                      Text(formattedDate, style: const TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.w600)),
                                    ],
                                    if (total.isNotEmpty) ...[
                                      const Spacer(),
                                      Text(total, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                                    ],
                                  ],
                                ),
                              ),
                              trailing: const Icon(Icons.chevron_right, size: 16, color: Colors.black38),
                              onTap: () => _onSelectQuote(item),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: _selectedQuote == null
                  ? const Center(child: Text('Selecciona una cotización para visualizar', style: TextStyle(color: Colors.black45)))
                  : _buildPdfViewerPane(
                      title: 'Cotización Folio: ${_selectedQuote!['folio']}',
                      clientName: (_selectedQuote!['businessName'] ?? _selectedQuote!['clientName'] ?? '').toString(),
                      filePath: _selectedQuote!['filePath'] as String?,
                      documentType: 'Cotización',
                      folio: (_selectedQuote!['folio'] ?? '').toString(),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // --- VISTA DIVIDIDA: FACTURACIÓN CFDI ---
  Widget _buildSplitInvoicesView() {
    final filtered = _invoices.where((inv) {
      // 1. Filtro por estado
      if (_selectedInvoiceStatusFilter != 'all' && inv.status != _selectedInvoiceStatusFilter) {
        return false;
      }

      // 2. Filtro por buscador
      if (_searchFilter.isEmpty) return true;
      return inv.clientName.toLowerCase().contains(_searchFilter) ||
          inv.folio.toLowerCase().contains(_searchFilter) ||
          inv.pdfName.toLowerCase().contains(_searchFilter);
    }).toList();

    final pendingCount = _invoices.where((i) => i.status == 'pending').length;
    final paidCount = _invoices.where((i) => i.status == 'paid').length;
    final canceledCount = _invoices.where((i) => i.status == 'canceled').length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 400,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Encabezado con selector de estado (Pendientes, Pagadas, Canceladas, Todas)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.filter_list, size: 16, color: Color(0xFF0F2B48)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedInvoiceStatusFilter,
                            isDense: true,
                            isExpanded: true,
                            icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: Color(0xFF0F2B48)),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F2B48)),
                            items: [
                              DropdownMenuItem(
                                value: 'pending',
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(color: Color(0xFFE11D48), shape: BoxShape.circle),
                                    ),
                                    const SizedBox(width: 8),
                                    Text('Pendientes de Pago ($pendingCount)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F2B48))),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'paid',
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(color: Color(0xFF059669), shape: BoxShape.circle),
                                    ),
                                    const SizedBox(width: 8),
                                    Text('Pagadas ($paidCount)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F2B48))),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'canceled',
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(color: Color(0xFF64748B), shape: BoxShape.circle),
                                    ),
                                    const SizedBox(width: 8),
                                    Text('Canceladas ($canceledCount)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F2B48))),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'all',
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(color: Color(0xFF3B82F6), shape: BoxShape.circle),
                                    ),
                                    const SizedBox(width: 8),
                                    Text('Todas las facturas (${_invoices.length})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F2B48))),
                                  ],
                                ),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedInvoiceStatusFilter = val;
                                  final matching = _invoices.where((inv) {
                                    if (val != 'all' && inv.status != val) return false;
                                    return true;
                                  }).toList();

                                  if (matching.isNotEmpty) {
                                    if (_selectedInvoice == null || (val != 'all' && _selectedInvoice!.status != val)) {
                                      _onSelectInvoice(matching.first);
                                    }
                                  } else {
                                    _selectedInvoice = null;
                                    _selectedInvoiceFile = null;
                                  }
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${filtered.length}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.inbox_outlined, size: 40, color: Colors.black26),
                              const SizedBox(height: 8),
                              Text(
                                _selectedInvoiceStatusFilter == 'pending'
                                    ? 'No hay facturas pendientes de pago.'
                                    : _selectedInvoiceStatusFilter == 'paid'
                                        ? 'No hay facturas pagadas registradas.'
                                        : _selectedInvoiceStatusFilter == 'canceled'
                                            ? 'No hay facturas canceladas.'
                                            : 'No se encontraron facturas en Drive.',
                                style: const TextStyle(fontSize: 12, color: Colors.black45),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          itemBuilder: (context, i) {
                            final inv = filtered[i];
                            final isSel = _selectedInvoice != null && _selectedInvoice!.id == inv.id;
                            final isPending = inv.status == 'pending';
                            final isCanceled = inv.status == 'canceled';

                            return ListTile(
                              dense: true,
                              selected: isSel,
                              selectedTileColor: const Color(0xFFE0F2FE),
                              title: Text(inv.clientName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              subtitle: Row(
                                children: [
                                  Text(inv.pdfName, style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                                  const SizedBox(width: 6),
                                  if (inv.hasXml)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFFA7F3D0))),
                                      child: const Text('XML OK', style: TextStyle(color: Color(0xFF047857), fontSize: 8.5, fontWeight: FontWeight.bold)),
                                    ),
                                ],
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isPending
                                      ? const Color(0xFFFFF1F2)
                                      : isCanceled
                                          ? const Color(0xFFF1F5F9)
                                          : const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isPending
                                        ? const Color(0xFFFECDD3)
                                        : isCanceled
                                            ? const Color(0xFFCBD5E1)
                                            : const Color(0xFFA7F3D0),
                                  ),
                                ),
                                child: Text(
                                  isPending
                                      ? 'Pendiente'
                                      : isCanceled
                                          ? 'Cancelada'
                                          : 'Pagada',
                                  style: TextStyle(
                                    color: isPending
                                        ? const Color(0xFFBE123C)
                                        : isCanceled
                                            ? const Color(0xFF64748B)
                                            : const Color(0xFF047857),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              onTap: () => _onSelectInvoice(inv),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // Lado Derecho: Visor de la Factura con acciones rápidas
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: _selectedInvoice == null
                  ? const Center(child: Text('Selecciona una factura para visualizar', style: TextStyle(color: Colors.black45)))
                  : Column(
                      children: [
                        // Barra superior de la factura
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF8FAFC),
                            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_selectedInvoice!.clientName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F2B48))),
                                  Text('Archivo: ${_selectedInvoice!.pdfName} (${_selectedInvoice!.formattedFileSize})', style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                                ],
                              ),
                              Row(
                                children: [
                                  // Botón WhatsApp
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white),
                                    icon: const Icon(Icons.share, size: 14),
                                    label: const Text('Enviar WhatsApp', style: TextStyle(fontSize: 11)),
                                    onPressed: () {
                                      final msg = Uri.encodeComponent('Hola estimado cliente de ${_selectedInvoice!.clientName}, le compartimos el recordatorio de su factura con EJ Exterminadores.');
                                      final phone = _selectedInvoice!.clientPhone.replaceAll(RegExp(r'\D'), '');
                                      final url = phone.isNotEmpty ? 'https://wa.me/$phone?text=$msg' : 'https://wa.me/?text=$msg';
                                      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                                    },
                                  ),
                                  const SizedBox(width: 8),

                                  // Botón Imprimir si el archivo está listo
                                  if (_selectedInvoiceFile != null && _selectedInvoiceFile!.existsSync()) ...[
                                    OutlinedButton.icon(
                                      icon: const Icon(Icons.print, size: 14),
                                      label: const Text('Imprimir', style: TextStyle(fontSize: 11)),
                                      onPressed: () => Printing.layoutPdf(onLayout: (format) => _selectedInvoiceFile!.readAsBytesSync()),
                                    ),
                                    const SizedBox(width: 8),
                                  ],

                                  // Botón Marcar Pagada si está pendiente
                                  if (_selectedInvoice!.status == 'pending')
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F2B48), foregroundColor: Colors.white),
                                      icon: const Icon(Icons.check_circle_outline, size: 14),
                                      label: const Text('Marcar Pagada', style: TextStyle(fontSize: 11)),
                                      onPressed: () async {
                                        final target = _selectedInvoice!;
                                        final ok = await _driveService.markInvoiceAsPaid(target);
                                        if (ok && mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Factura movida a Pagadas en Google Drive!'), backgroundColor: Colors.green));
                                          setState(() {
                                            final idx = _invoices.indexWhere((inv) => inv.id == target.id);
                                            if (idx != -1) {
                                              _invoices[idx] = _invoices[idx].copyWith(status: 'paid');
                                            }
                                            _pendingInvoiceCount = _invoices.where((i) => i.status == 'pending').length;
                                            if (_selectedInvoiceStatusFilter == 'pending') {
                                              final remainingPending = _invoices.where((i) => i.status == 'pending').toList();
                                              if (remainingPending.isNotEmpty) {
                                                _onSelectInvoice(remainingPending.first);
                                              } else {
                                                _selectedInvoice = null;
                                                _selectedInvoiceFile = null;
                                              }
                                            }
                                          });
                                          _loadAllData();
                                        }
                                      },
                                    ),

                                  if (_selectedInvoice!.status == 'paid')
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFECFDF5),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFFA7F3D0)),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.check_circle, size: 14, color: Color(0xFF047857)),
                                          SizedBox(width: 4),
                                          Text('Factura Pagada', style: TextStyle(color: Color(0xFF047857), fontSize: 11, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),

                                  if (_selectedInvoice!.status == 'canceled')
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFFCBD5E1)),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.cancel, size: 14, color: Color(0xFF64748B)),
                                          SizedBox(width: 4),
                                          Text('Factura Cancelada', style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Previsualizador PDF
                        Expanded(
                          child: _isLoadingInvoiceFile
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const SizedBox(
                                        width: 36,
                                        height: 36,
                                        child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF0F2B48)),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Descargando factura ${_selectedInvoice?.folio ?? ''} desde Google Drive...',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F2B48)),
                                      ),
                                      const SizedBox(height: 6),
                                      const Text(
                                        'Se abrirá automáticamente al terminar.',
                                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                )
                              : (_selectedInvoiceFile != null && _selectedInvoiceFile!.existsSync())
                                  ? PdfPreview(
                                      key: ValueKey('invoice-${_selectedInvoice!.id}-${_selectedInvoiceFile!.path}-${_selectedInvoiceFile!.existsSync() ? _selectedInvoiceFile!.lengthSync() : 0}'),
                                      build: (format) => _selectedInvoiceFile!.readAsBytesSync(),
                                      allowPrinting: true,
                                      allowSharing: false,
                                      canChangeOrientation: false,
                                      canChangePageFormat: false,
                                    )
                                  : Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.cloud_off_outlined, size: 48, color: Color(0xFF94A3B8)),
                                          const SizedBox(height: 10),
                                          const Text('No se pudo descargar la factura desde Google Drive.', style: TextStyle(fontSize: 12, color: Colors.black54)),
                                          const SizedBox(height: 12),
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F2B48), foregroundColor: Colors.white),
                                            icon: const Icon(Icons.refresh, size: 16),
                                            label: const Text('Reintentar descarga'),
                                            onPressed: () {
                                              if (_selectedInvoice != null) {
                                                _onSelectInvoice(_selectedInvoice!);
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // --- PANEL DE VISOR PDF UNIVERSAL PARA REPORTES Y COTIZACIONES ---
  Widget _buildPdfViewerPane({
    required String title,
    required String clientName,
    required String? filePath,
    required String documentType,
    required String folio,
  }) {
    File? file = (filePath != null && filePath.isNotEmpty) ? File(filePath) : null;
    final exists = file != null && file.existsSync();
    final isCurrentlyLoading = _isLoadingPdf && _loadingDocId == '$documentType-$folio';

    return Column(
      children: [
        // Barra de encabezado del documento
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F2B48))),
                  Text(clientName, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                ],
              ),
              Row(
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white),
                    icon: const Icon(Icons.share, size: 14),
                    label: const Text('WhatsApp Web', style: TextStyle(fontSize: 11)),
                    onPressed: () {
                      final msg = Uri.encodeComponent('Hola estimado cliente de $clientName, le compartimos su $documentType con folio $folio de EJ Exterminadores.');
                      launchUrl(Uri.parse('https://wa.me/?text=$msg'), mode: LaunchMode.externalApplication);
                    },
                  ),
                  const SizedBox(width: 8),
                  if (exists)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.print, size: 14),
                      label: const Text('Imprimir', style: TextStyle(fontSize: 11)),
                      onPressed: () => Printing.layoutPdf(onLayout: (format) => file.readAsBytesSync()),
                    ),
                ],
              ),
            ],
          ),
        ),

        // Visor de PDF
        Expanded(
          child: isCurrentlyLoading
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 36,
                        height: 36,
                        child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF0F2B48)),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Descargando $documentType $folio desde Google Drive...',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F2B48)),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Se abrirá automáticamente al terminar.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                )
              : exists
                  ? PdfPreview(
                      key: ValueKey('$documentType-$folio-${file.path}-${file.existsSync() ? file.lengthSync() : 0}'),
                      build: (format) => file.readAsBytesSync(),
                      allowPrinting: true,
                      allowSharing: false,
                      canChangeOrientation: false,
                      canChangePageFormat: false,
                    )
                  : Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cloud_off_outlined, size: 48, color: Color(0xFF94A3B8)),
                          const SizedBox(height: 10),
                          Text('No se encontró el archivo físico de este $documentType en Google Drive.', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F2B48), foregroundColor: Colors.white),
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Reintentar descarga desde Drive'),
                            onPressed: () {
                              if (documentType == 'Reporte' && _selectedReport != null) {
                                _onSelectReport(_selectedReport!);
                              } else if (documentType == 'Cotización' && _selectedQuote != null) {
                                _onSelectQuote(_selectedQuote!);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
        ),
      ],
    );
  }
}
