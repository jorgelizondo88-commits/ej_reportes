import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/certificate_model.dart';
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

  List<CertificateModel> _certificates = [];
  CertificateModel? _selectedCertificate;
  File? _selectedCertificateFile;
  bool _isLoadingCertificateFile = false;
  bool _isRefreshingCertificates = false;
  bool _isCreatingCertFolders = false;
  String? _selectedCertificateClientFilter;
  bool _sortCertificatesNewestFirst = true;

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

  String _docClientName(Map<String, dynamic> item, {String fallback = ''}) {
    final bn = (item['businessName'] ?? '').toString().trim();
    if (bn.isNotEmpty) return bn;
    final cn = (item['clientName'] ?? '').toString().trim();
    if (cn.isNotEmpty) return cn;
    return fallback;
  }

  Future<void> _persistResolvedFilePath(String prefsKey, String folio, String resolvedPath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(prefsKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final targetKey = _driveService.normalizeFolioKey(folio);
      bool updated = false;
      final list = decoded.map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        if (_driveService.normalizeFolioKey((m['folio'] ?? '').toString()) == targetKey) {
          m['filePath'] = resolvedPath;
          updated = true;
        }
        return m;
      }).toList();
      if (updated) {
        await prefs.setString(prefsKey, jsonEncode(list));
      }
    } catch (_) {}
  }

  Future<void> _onSelectReport(Map<String, dynamic> item) async {
    final folio = (item['folio'] ?? 'S_N').toString();
    final targetKey = _driveService.normalizeFolioKey(folio);
    final clientName = _docClientName(item);
    final currentPath = item['filePath'] as String?;
    final currentFile = (currentPath != null && currentPath.isNotEmpty) ? File(currentPath) : null;
    final localExists = currentFile != null && currentFile.existsSync() && currentFile.lengthSync() > 100;

    _failedDownloads.remove('Reporte-$folio');

    setState(() {
      _selectedReport = item;
      _isLoadingPdf = !localExists;
      _loadingDocId = 'Reporte-$folio';
    });

    if (!localExists) {
      try {
        File? resolved = await _driveService.findLocalCachedPdf(
          documentType: 'Reporte',
          folio: folio,
        );
        resolved ??= await _driveService.downloadDocumentPdf(
          clientName: clientName,
          documentType: 'Reporte',
          folio: folio,
        );

        if (resolved != null && resolved.existsSync() && resolved.lengthSync() > 100) {
          item['filePath'] = resolved.path;
          for (final r in _reports) {
            if (_driveService.normalizeFolioKey((r['folio'] ?? '').toString()) == targetKey) {
              r['filePath'] = resolved.path;
            }
          }
          await _persistResolvedFilePath('ej_reports_history_list', folio, resolved.path);
          if (mounted &&
              _selectedReport != null &&
              _driveService.normalizeFolioKey((_selectedReport!['folio'] ?? '').toString()) == targetKey) {
            setState(() {
              _selectedReport!['filePath'] = resolved!.path;
              _isLoadingPdf = false;
              _loadingDocId = null;
            });
          }
        } else if (mounted &&
            _selectedReport != null &&
            _driveService.normalizeFolioKey((_selectedReport!['folio'] ?? '').toString()) == targetKey) {
          setState(() {
            _failedDownloads.add('Reporte-$folio');
            _isLoadingPdf = false;
            _loadingDocId = null;
          });
        }
      } catch (e) {
        if (mounted &&
            _selectedReport != null &&
            _driveService.normalizeFolioKey((_selectedReport!['folio'] ?? '').toString()) == targetKey) {
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
    final targetKey = _driveService.normalizeFolioKey(folio);
    final clientName = _docClientName(item);
    final currentPath = item['filePath'] as String?;
    final currentFile = (currentPath != null && currentPath.isNotEmpty) ? File(currentPath) : null;
    final localExists = currentFile != null && currentFile.existsSync() && currentFile.lengthSync() > 100;

    _failedDownloads.remove('Cotización-$folio');

    setState(() {
      _selectedQuote = item;
      _isLoadingPdf = !localExists;
      _loadingDocId = 'Cotización-$folio';
    });

    if (!localExists) {
      try {
        File? resolved = await _driveService.findLocalCachedPdf(
          documentType: 'Cotización',
          folio: folio,
        );
        resolved ??= await _driveService.downloadDocumentPdf(
          clientName: clientName,
          documentType: 'Cotización',
          folio: folio,
        );

        if (resolved != null && resolved.existsSync() && resolved.lengthSync() > 100) {
          item['filePath'] = resolved.path;
          for (final q in _quotes) {
            if (_driveService.normalizeFolioKey((q['folio'] ?? '').toString()) == targetKey) {
              q['filePath'] = resolved.path;
            }
          }
          await _persistResolvedFilePath('ej_quotes_history_list', folio, resolved.path);
          if (mounted &&
              _selectedQuote != null &&
              _driveService.normalizeFolioKey((_selectedQuote!['folio'] ?? '').toString()) == targetKey) {
            setState(() {
              _selectedQuote!['filePath'] = resolved!.path;
              _isLoadingPdf = false;
              _loadingDocId = null;
            });
          }
        } else if (mounted &&
            _selectedQuote != null &&
            _driveService.normalizeFolioKey((_selectedQuote!['folio'] ?? '').toString()) == targetKey) {
          setState(() {
            _failedDownloads.add('Cotización-$folio');
            _isLoadingPdf = false;
            _loadingDocId = null;
          });
        }
      } catch (e) {
        if (mounted &&
            _selectedQuote != null &&
            _driveService.normalizeFolioKey((_selectedQuote!['folio'] ?? '').toString()) == targetKey) {
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

  Future<void> _onSelectCertificate(CertificateModel cert) async {
    setState(() {
      _selectedCertificate = cert;
      _selectedCertificateFile = null;
      _isLoadingCertificateFile = true;
    });
    try {
      final file = await _driveService.downloadCertificatePdf(cert);
      if (mounted && _selectedCertificate?.id == cert.id) {
        setState(() {
          _selectedCertificateFile = file;
          _isLoadingCertificateFile = false;
        });
      }
    } catch (_) {
      if (mounted && _selectedCertificate?.id == cert.id) {
        setState(() {
          _isLoadingCertificateFile = false;
        });
      }
    }
  }

  Future<void> _refreshCertificatesOnly() async {
    if (_isRefreshingCertificates) return;
    setState(() => _isRefreshingCertificates = true);
    try {
      if (!_driveService.isSignedIn) {
        await _driveService.initSilently();
      }
      if (_driveService.isSignedIn) {
        final fresh = await _driveService.fetchCertificates();
        if (mounted) {
          setState(() {
            _certificates = fresh;
            if (fresh.isNotEmpty) {
              if (_selectedCertificate == null) {
                _onSelectCertificate(fresh.first);
              } else {
                final idx = fresh.indexWhere((c) => c.id == _selectedCertificate!.id);
                if (idx >= 0) {
                  _selectedCertificate = fresh[idx];
                } else {
                  _onSelectCertificate(fresh.first);
                }
              }
            } else {
              _selectedCertificate = null;
              _selectedCertificateFile = null;
            }
          });
        }
      }
    } finally {
      if (mounted) setState(() => _isRefreshingCertificates = false);
    }
  }

  Future<void> _createAllCertificateFoldersDesktop() async {
    if (!_driveService.isSignedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conecta Google Drive primero en "Nube Google Drive".')),
      );
      return;
    }
    setState(() => _isCreatingCertFolders = true);
    try {
      final count = await _driveService.ensureCertificateFoldersForAllClients();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡Carpeta "Certificados" preparada en Drive para $count cliente(s)!'),
            backgroundColor: const Color(0xFF0F766E),
          ),
        );
      }
      await _refreshCertificatesOnly();
    } finally {
      if (mounted) setState(() => _isCreatingCertFolders = false);
    }
  }

  Future<void> _shareCertificateDesktop(CertificateModel cert) async {
    final message =
        'Estimado cliente de *${cert.clientName}*, le compartimos su Certificado de Fumigación (*${cert.title}*) emitido por EJ Exterminadores. ¡Quedamos a sus órdenes!';
    final file = _selectedCertificate?.id == cert.id ? _selectedCertificateFile : null;

    if (file != null && file.existsSync()) {
      try {
        await Share.shareXFiles(
          [XFile(file.path, name: cert.pdfName)],
          text: message,
          subject: 'Certificado de Fumigación - ${cert.clientName}',
        );
        return;
      } catch (_) {}
    }

    final msgEncoded = Uri.encodeComponent(message.replaceAll('*', ''));
    final phone = cert.clientPhone.replaceAll(RegExp(r'\D'), '');
    final url = phone.isNotEmpty ? 'https://wa.me/52$phone?text=$msgEncoded' : 'https://wa.me/?text=$msgEncoded';
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
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
    await _driveService.reconcileLocalHistoryStorage(prefs);

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

    // 5. Facturas y Certificados desde caché local primero para rapidez inmediata
    final cachedInvoices = await _driveService.getCachedInvoices();
    final pendingInvs = cachedInvoices.where((i) => i.status == 'pending').toList();
    final cachedCertificates = await _driveService.getCachedCertificates();

    if (mounted) {
      Map<String, dynamic>? reportToLoad;
      Map<String, dynamic>? quoteToLoad;
      CertificateModel? certToLoad;

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
        _certificates = cachedCertificates;

        if (_reports.isNotEmpty) {
          if (_selectedReport == null) {
            _selectedReport = _reports.first;
            reportToLoad = _reports.first;
          } else {
            final selFolioKey = _driveService.normalizeFolioKey((_selectedReport!['folio'] ?? '').toString());
            final idx = _reports.indexWhere(
              (r) => _driveService.normalizeFolioKey((r['folio'] ?? '').toString()) == selFolioKey,
            );
            _selectedReport = idx >= 0 ? _reports[idx] : _reports.first;
            if (!syncFromCloud && _selectedModuleIndex == 0) {
              final p = _selectedReport!['filePath'] as String?;
              if (p == null || p.isEmpty || !File(p).existsSync() || File(p).lengthSync() <= 100) {
                reportToLoad = _selectedReport;
              }
            }
          }
        } else {
          _selectedReport = null;
        }

        if (_quotes.isNotEmpty) {
          if (_selectedQuote == null) {
            _selectedQuote = _quotes.first;
          } else {
            final selFolioKey = _driveService.normalizeFolioKey((_selectedQuote!['folio'] ?? '').toString());
            final idx = _quotes.indexWhere(
              (q) => _driveService.normalizeFolioKey((q['folio'] ?? '').toString()) == selFolioKey,
            );
            _selectedQuote = idx >= 0 ? _quotes[idx] : _quotes.first;
          }
          if (!syncFromCloud && _selectedModuleIndex == 1) {
            final p = _selectedQuote!['filePath'] as String?;
            if (p == null || p.isEmpty || !File(p).existsSync() || File(p).lengthSync() <= 100) {
              quoteToLoad = _selectedQuote;
            }
          }
        } else {
          _selectedQuote = null;
        }

        if (_invoices.isNotEmpty && _selectedInvoice == null) {
          final pending = _invoices.where((i) => i.status == 'pending').toList();
          _selectedInvoice = pending.isNotEmpty ? pending.first : _invoices.first;
        }

        if (_certificates.isNotEmpty) {
          if (_selectedCertificate == null) {
            _selectedCertificate = _certificates.first;
          } else {
            final idx = _certificates.indexWhere((c) => c.id == _selectedCertificate!.id);
            _selectedCertificate = idx >= 0 ? _certificates[idx] : _certificates.first;
          }
          if (!syncFromCloud &&
              _selectedModuleIndex == 10 &&
              (_selectedCertificateFile == null || !_selectedCertificateFile!.existsSync())) {
            certToLoad = _selectedCertificate;
          }
        } else {
          _selectedCertificate = null;
          _selectedCertificateFile = null;
        }
      });

      if (reportToLoad != null) {
        _onSelectReport(reportToLoad!);
      } else if (quoteToLoad != null) {
        _onSelectQuote(quoteToLoad!);
      } else if (certToLoad != null) {
        _onSelectCertificate(certToLoad!);
      }
    }

    if (syncFromCloud && !_isCloudSyncing) {
      _isCloudSyncing = true;
      try {
        if (!_driveService.isSignedIn) {
          await _driveService.initSilently();
          if (mounted) setState(() {});
        }

        if (_driveService.isSignedIn) {
          // Refrescar facturas y certificados en paralelo en segundo plano
          final driveResults = await Future.wait([
            _driveService.fetchInvoices(),
            _driveService.fetchCertificates(),
          ]);
          final freshInvoices = driveResults[0] as List<InvoiceModel>;
          final freshCertificates = driveResults[1] as List<CertificateModel>;
          if (mounted) {
            CertificateModel? certToAutoDownload;
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

              _certificates = freshCertificates;
              if (freshCertificates.isNotEmpty) {
                if (_selectedCertificate == null) {
                  _selectedCertificate = freshCertificates.first;
                } else {
                  final idx = freshCertificates.indexWhere((c) => c.id == _selectedCertificate!.id);
                  _selectedCertificate = idx >= 0 ? freshCertificates[idx] : freshCertificates.first;
                }
                if (_selectedModuleIndex == 10 &&
                    (_selectedCertificateFile == null || !_selectedCertificateFile!.existsSync())) {
                  certToAutoDownload = _selectedCertificate;
                }
              } else {
                _selectedCertificate = null;
                _selectedCertificateFile = null;
              }
            });
            if (certToAutoDownload != null) {
              _onSelectCertificate(certToAutoDownload!);
            }
          }

          // Sincronización bidireccional segura (cola pendiente + Copia Maestra + archivos en Drive), sin bucle recursivo
          final uploaded = await _driveService.processQueue(updateMasterBackup: false);
          final merged = await _driveService.pullAndMergeCloudDatabase();
          final discovered = await _driveService.discoverDriveDocuments();
          final healed = await _driveService.reconcileLocalHistoryStorage(
            prefs,
            pushCleanToCloudIfDeduped: !uploaded,
          );
          if (uploaded) {
            await _driveService.backupDatabaseToCloud(force: true);
          }
          if ((merged || discovered > 0 || uploaded || healed) && mounted) {
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
                _sidebarItem(
                  10,
                  Icons.verified_outlined,
                  'Certificados',
                  badge: _certificates.isNotEmpty ? '${_certificates.length}' : null,
                  badgeColor: const Color(0xFF0F766E),
                  iconColor: const Color(0xFF5EEAD4),
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
            if (p == null || p.isEmpty || !File(p).existsSync() || File(p).lengthSync() <= 100) {
              _onSelectReport(_selectedReport!);
            }
          } else if (index == 1 && _selectedQuote != null) {
            final p = _selectedQuote!['filePath'] as String?;
            if (p == null || p.isEmpty || !File(p).existsSync() || File(p).lengthSync() <= 100) {
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
          } else if (index == 10 && _selectedCertificate != null) {
            if (_selectedCertificateFile == null || !_selectedCertificateFile!.existsSync()) {
              _onSelectCertificate(_selectedCertificate!);
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
      case 10:
        return _buildSplitCertificatesView();
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
      final name = _docClientName(r);
      if (name.isNotEmpty) clientNames.add(name);
    }
    final sortedClients = clientNames.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final filtered = _reports.where((r) {
      final client = _docClientName(r);
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
                            final isSel = _selectedReport != null &&
                                _driveService.normalizeFolioKey((_selectedReport!['folio'] ?? '').toString()) ==
                                    _driveService.normalizeFolioKey((item['folio'] ?? '').toString());
                            final clientName = _docClientName(item, fallback: 'Cliente');
                            final folio = (item['folio'] ?? 'S_N').toString();

                            final rawDate = (item['serviceDate'] ?? item['date'] ?? item['createdAt'] ?? '').toString();
                            String formattedDate = '';
                            if (rawDate.isNotEmpty) {
                              final parsed = _driveService.parseHistoryDate(rawDate);
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
                      clientName: _docClientName(_selectedReport!),
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
      final name = _docClientName(q);
      if (name.isNotEmpty) clientNames.add(name);
    }
    final sortedClients = clientNames.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final filtered = _quotes.where((q) {
      final client = _docClientName(q);
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
                            final isSel = _selectedQuote != null &&
                                _driveService.normalizeFolioKey((_selectedQuote!['folio'] ?? '').toString()) ==
                                    _driveService.normalizeFolioKey((item['folio'] ?? '').toString());
                            final clientName = _docClientName(item, fallback: 'Cliente');
                            final folio = (item['folio'] ?? 'S_N').toString();
                            final rawTotal = item['totalAmount'] ?? item['total'] ?? item['amount'];
                            String total = '';
                            if (rawTotal is num && rawTotal > 0) {
                              total = NumberFormat.currency(locale: 'es_MX', symbol: '\$').format(rawTotal);
                            } else if (rawTotal is String && rawTotal.trim().isNotEmpty) {
                              final parsedNum = double.tryParse(rawTotal.replaceAll(RegExp(r'[^\d.]'), ''));
                              total = (parsedNum != null && parsedNum > 0)
                                  ? NumberFormat.currency(locale: 'es_MX', symbol: '\$').format(parsedNum)
                                  : rawTotal.trim();
                            }

                            final rawDate = (item['quoteDate'] ?? item['date'] ?? item['createdAt'] ?? '').toString();
                            String formattedDate = '';
                            if (rawDate.isNotEmpty) {
                              final parsed = _driveService.parseHistoryDate(rawDate);
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
                                    Flexible(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE2E8F0),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'Folio: $folio',
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0F2B48)),
                                        ),
                                      ),
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
                      clientName: _docClientName(_selectedQuote!),
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

  // --- VISTA DIVIDIDA: CERTIFICADOS DE FUMIGACIÓN ---
  Widget _buildSplitCertificatesView() {
    final clientNames = <String>{};
    for (final c in _certificates) {
      final name = c.clientName.trim();
      if (name.isNotEmpty) clientNames.add(name);
    }
    final sortedClients = clientNames.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final effectiveClientFilter =
        (_selectedCertificateClientFilter != null && sortedClients.contains(_selectedCertificateClientFilter))
            ? _selectedCertificateClientFilter
            : null;

    final filtered = _certificates.where((cert) {
      if (effectiveClientFilter != null && effectiveClientFilter.isNotEmpty) {
        if (cert.clientName.trim().toLowerCase() != effectiveClientFilter.trim().toLowerCase()) {
          return false;
        }
      }
      if (_searchFilter.isEmpty) return true;
      return cert.clientName.toLowerCase().contains(_searchFilter) ||
          cert.title.toLowerCase().contains(_searchFilter) ||
          cert.pdfName.toLowerCase().contains(_searchFilter) ||
          cert.subfolderName.toLowerCase().contains(_searchFilter);
    }).toList();

    final sortedFiltered = _driveService.sortCertificates(
      filtered,
      newestFirst: _sortCertificatesNewestFirst,
    );
    final dateFmt = DateFormat('dd/MM/yyyy • HH:mm');

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
                // Encabezado con orden y actualización
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_outlined, size: 17, color: Color(0xFF0F766E)),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Certificados en Drive',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F2B48)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: () => setState(() => _sortCertificatesNewestFirst = !_sortCertificatesNewestFirst),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDFA),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF99F6E4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.swap_vert, size: 13, color: Color(0xFF0F766E)),
                              const SizedBox(width: 3),
                              Text(
                                _sortCertificatesNewestFirst ? 'Recientes' : 'Antiguos',
                                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      _isRefreshingCertificates
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F766E)),
                            )
                          : IconButton(
                              icon: const Icon(Icons.refresh, size: 17, color: Color(0xFF0F2B48)),
                              tooltip: 'Actualizar certificados desde Google Drive',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: _refreshCertificatesOnly,
                            ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${sortedFiltered.length}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                        ),
                      ),
                    ],
                  ),
                ),

                // Filtro por Cliente + botón crear carpetas Certificados
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
                            value: effectiveClientFilter,
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
                                _selectedCertificateClientFilter = val;
                                final matches = _certificates.where((cert) {
                                  if (val != null && cert.clientName.trim().toLowerCase() != val.trim().toLowerCase()) {
                                    return false;
                                  }
                                  return true;
                                }).toList();
                                final ordered = _driveService.sortCertificates(matches, newestFirst: _sortCertificatesNewestFirst);
                                if (ordered.isNotEmpty && (_selectedCertificate == null || !ordered.any((c) => c.id == _selectedCertificate!.id))) {
                                  _onSelectCertificate(ordered.first);
                                }
                              });
                            },
                          ),
                        ),
                      ),
                      if (effectiveClientFilter != null) ...[
                        IconButton(
                          icon: const Icon(Icons.cancel, size: 16, color: Colors.grey),
                          tooltip: 'Mostrar todos',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => setState(() => _selectedCertificateClientFilter = null),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Tooltip(
                        message: 'Crear carpeta "Certificados" en Drive para todos los clientes',
                        child: InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: _isCreatingCertFolders ? null : _createAllCertificateFoldersDesktop,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: _isCreatingCertFolders
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F766E)),
                                  )
                                : const Icon(Icons.create_new_folder_outlined, size: 15, color: Color(0xFF0F766E)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Lista de Certificados
                Expanded(
                  child: sortedFiltered.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _driveService.isSignedIn ? Icons.verified_outlined : Icons.cloud_off_outlined,
                                  size: 42,
                                  color: Colors.black26,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  !_driveService.isSignedIn
                                      ? 'Conecta tu cuenta en "Nube Google Drive" para leer los certificados.'
                                      : _certificates.isEmpty
                                          ? 'No se encontraron PDFs en carpetas "Certificados" de Google Drive.\n\nSube tus PDFs a Clientes / [Cliente] / Certificados y presiona Actualizar.'
                                          : 'No hay certificados que coincidan con el filtro.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 12, color: Colors.black54, height: 1.4),
                                ),
                                if (_driveService.isSignedIn && _certificates.isEmpty) ...[
                                  const SizedBox(height: 14),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0F766E),
                                      foregroundColor: Colors.white,
                                    ),
                                    icon: const Icon(Icons.create_new_folder_outlined, size: 15),
                                    label: const Text('Crear carpetas "Certificados"', style: TextStyle(fontSize: 11.5)),
                                    onPressed: _isCreatingCertFolders ? null : _createAllCertificateFoldersDesktop,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: sortedFiltered.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          itemBuilder: (context, i) {
                            final cert = sortedFiltered[i];
                            final isSel = _selectedCertificate != null && _selectedCertificate!.id == cert.id;
                            return ListTile(
                              dense: true,
                              selected: isSel,
                              selectedTileColor: const Color(0xFFE0F2FE),
                              leading: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0FDFA),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF99F6E4)),
                                ),
                                child: const Icon(Icons.verified_outlined, size: 17, color: Color(0xFF0F766E)),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      cert.clientName,
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F2B48)),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (cert.subfolderName.isNotEmpty)
                                    Container(
                                      margin: const EdgeInsets.only(left: 6),
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        cert.subfolderName,
                                        style: const TextStyle(fontSize: 9.5, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    cert.pdfName,
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      const Icon(Icons.schedule, size: 11, color: Color(0xFF0F766E)),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Agregado: ${dateFmt.format(cert.addedTime)}',
                                        style: const TextStyle(fontSize: 10, color: Color(0xFF0F766E), fontWeight: FontWeight.w600),
                                      ),
                                      if (cert.formattedFileSize.isNotEmpty) ...[
                                        const Spacer(),
                                        Text(
                                          cert.formattedFileSize,
                                          style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B)),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                              onTap: () => _onSelectCertificate(cert),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // Lado Derecho: Visor PDF de Certificados
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: _selectedCertificate == null
                  ? const Center(
                      child: Text(
                        'Selecciona un certificado para visualizar',
                        style: TextStyle(color: Colors.black45),
                      ),
                    )
                  : Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF8FAFC),
                            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedCertificate!.clientName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F2B48)),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '${_selectedCertificate!.pdfName} • Agregado: ${dateFmt.format(_selectedCertificate!.addedTime)}${_selectedCertificate!.formattedFileSize.isNotEmpty ? ' (${_selectedCertificate!.formattedFileSize})' : ''}',
                                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF25D366),
                                      foregroundColor: Colors.white,
                                    ),
                                    icon: const Icon(Icons.share, size: 14),
                                    label: const Text('Enviar / WhatsApp', style: TextStyle(fontSize: 11)),
                                    onPressed: () => _shareCertificateDesktop(_selectedCertificate!),
                                  ),
                                  if (_selectedCertificateFile != null && _selectedCertificateFile!.existsSync())
                                    OutlinedButton.icon(
                                      icon: const Icon(Icons.print, size: 14),
                                      label: const Text('Imprimir', style: TextStyle(fontSize: 11)),
                                      onPressed: () => Printing.layoutPdf(
                                        onLayout: (format) => _selectedCertificateFile!.readAsBytes(),
                                      ),
                                    ),
                                  if (_selectedCertificate!.pdfWebViewLink != null && _selectedCertificate!.pdfWebViewLink!.isNotEmpty)
                                    OutlinedButton.icon(
                                      icon: const Icon(Icons.open_in_new, size: 14),
                                      label: const Text('Drive', style: TextStyle(fontSize: 11)),
                                      onPressed: () => launchUrl(
                                        Uri.parse(_selectedCertificate!.pdfWebViewLink!),
                                        mode: LaunchMode.externalApplication,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: _isLoadingCertificateFile
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const SizedBox(
                                        width: 36,
                                        height: 36,
                                        child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF0F766E)),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Descargando ${_selectedCertificate!.pdfName} desde Google Drive...',
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
                              : (_selectedCertificateFile != null && _selectedCertificateFile!.existsSync())
                                  ? PdfPreview(
                                      key: ValueKey('cert-${_selectedCertificate!.id}-${_selectedCertificateFile!.path}-${_selectedCertificateFile!.lengthSync()}'),
                                      build: (format) => _selectedCertificateFile!.readAsBytes(),
                                      allowPrinting: true,
                                      allowSharing: false,
                                      canChangeOrientation: false,
                                      canChangePageFormat: false,
                                      onError: (context, error) => Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.error_outline, size: 42, color: Colors.redAccent),
                                            const SizedBox(height: 10),
                                            Text('No se pudo renderizar el certificado: $error', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                                          ],
                                        ),
                                      ),
                                    )
                                  : Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.cloud_off_outlined, size: 48, color: Color(0xFF94A3B8)),
                                          const SizedBox(height: 10),
                                          const Text(
                                            'No se pudo descargar el certificado desde Google Drive.',
                                            style: TextStyle(fontSize: 12, color: Colors.black54),
                                          ),
                                          const SizedBox(height: 12),
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF0F766E),
                                              foregroundColor: Colors.white,
                                            ),
                                            icon: const Icon(Icons.refresh, size: 16),
                                            label: const Text('Reintentar descarga'),
                                            onPressed: () {
                                              if (_selectedCertificate != null) {
                                                _onSelectCertificate(_selectedCertificate!);
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
    final exists = file != null && file.existsSync() && file.lengthSync() > 100;
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
                      build: (format) => file.readAsBytes(),
                      allowPrinting: true,
                      allowSharing: false,
                      canChangeOrientation: false,
                      canChangePageFormat: false,
                      onError: (context, error) => Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, size: 42, color: Colors.redAccent),
                            const SizedBox(height: 10),
                            Text('No se pudo renderizar el PDF: $error', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                          ],
                        ),
                      ),
                    )
                  : Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cloud_off_outlined, size: 48, color: Color(0xFF94A3B8)),
                          const SizedBox(height: 10),
                          Text(
                            _driveService.isSignedIn
                                ? 'No se encontró el archivo físico de este documento en Google Drive.'
                                : 'Conecta tu cuenta en "Nube Google Drive" para descargar este PDF.',
                            style: const TextStyle(fontSize: 12, color: Colors.black54),
                          ),
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
