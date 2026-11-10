import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/certificate_model.dart';
import '../../services/google_drive_sync_service.dart';
import '../cloud/google_drive_sync_screen.dart';
import 'certificate_viewer_screen.dart';

class CertificatesHubScreen extends StatefulWidget {
  final String? initialClientFilter;

  const CertificatesHubScreen({
    super.key,
    this.initialClientFilter,
  });

  @override
  State<CertificatesHubScreen> createState() => _CertificatesHubScreenState();
}

class _CertificatesHubScreenState extends State<CertificatesHubScreen> {
  final GoogleDriveSyncService _driveService = GoogleDriveSyncService();

  List<CertificateModel> _allCertificates = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isCreatingFolders = false;
  bool _newestFirst = true;
  String _searchQuery = '';
  String? _selectedClientFilter;
  final TextEditingController _searchCtrl = TextEditingController();

  final Map<String, File> _downloadedPdfs = {};

  @override
  void initState() {
    super.initState();
    if (widget.initialClientFilter != null && widget.initialClientFilter!.trim().isNotEmpty) {
      _selectedClientFilter = widget.initialClientFilter!.trim();
    }
    _initCertificates();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _initCertificates() async {
    final cached = await _driveService.getCachedCertificates();
    if (cached.isNotEmpty && mounted) {
      setState(() {
        _allCertificates = cached;
        _isLoading = false;
      });
    }

    await _loadCertificates(showSpinner: cached.isEmpty);
  }

  Future<void> _loadCertificates({bool showSpinner = false}) async {
    if (showSpinner) {
      setState(() => _isLoading = true);
    } else {
      setState(() => _isRefreshing = true);
    }

    if (!_driveService.isSignedIn) {
      await _driveService.initSilently();
    }

    if (!_driveService.isSignedIn) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
      return;
    }

    final list = await _driveService.fetchCertificates();
    if (mounted) {
      setState(() {
        _allCertificates = list;
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  Future<void> _createCertificateFoldersForAll() async {
    if (!_driveService.isSignedIn) return;
    setState(() => _isCreatingFolders = true);
    final count = await _driveService.ensureCertificateFoldersForAllClients();
    if (mounted) {
      setState(() => _isCreatingFolders = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡Carpeta "Certificados" lista en Drive para $count cliente(s)!'),
          backgroundColor: const Color(0xFF0F766E),
        ),
      );
      await _loadCertificates();
    }
  }

  List<CertificateModel> _getFilteredCertificates() {
    final filtered = _allCertificates.where((cert) {
      if (_selectedClientFilter != null && _selectedClientFilter!.isNotEmpty) {
        if (cert.clientName.trim().toLowerCase() != _selectedClientFilter!.trim().toLowerCase()) {
          return false;
        }
      }
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        final matchesClient = cert.clientName.toLowerCase().contains(q);
        final matchesName = cert.pdfName.toLowerCase().contains(q);
        final matchesTitle = cert.title.toLowerCase().contains(q);
        final matchesSub = cert.subfolderName.toLowerCase().contains(q);
        if (!matchesClient && !matchesName && !matchesTitle && !matchesSub) {
          return false;
        }
      }
      return true;
    }).toList();

    return _driveService.sortCertificates(filtered, newestFirst: _newestFirst);
  }

  List<String> _getUniqueClients() {
    final set = <String>{};
    for (final cert in _allCertificates) {
      if (cert.clientName.trim().isNotEmpty) {
        set.add(cert.clientName.trim());
      }
    }
    final list = set.toList();
    list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  Future<File?> _ensurePdfDownloaded(CertificateModel certificate) async {
    final cached = _downloadedPdfs[certificate.id];
    if (cached != null &&
        cached.existsSync() &&
        cached.lengthSync() > 100 &&
        (certificate.fileSize <= 0 || cached.lengthSync() == certificate.fileSize)) {
      return cached;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            const SizedBox(width: 12),
            Expanded(child: Text('Descargando ${certificate.pdfName} desde Google Drive...')),
          ],
        ),
        duration: const Duration(seconds: 4),
      ),
    );

    final file = await _driveService.downloadCertificatePdf(certificate);
    if (file != null && file.existsSync()) {
      _downloadedPdfs[certificate.id] = file;
      return file;
    }
    return null;
  }

  Future<void> _viewCertificate(CertificateModel certificate) async {
    final file = await _ensurePdfDownloaded(certificate);
    if (file == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo descargar el PDF del certificado desde Google Drive.')),
        );
      }
      return;
    }

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CertificateViewerScreen(
          certificate: certificate,
          localPdfFile: file,
        ),
      ),
    );
  }

  Future<void> _shareCertificate(CertificateModel certificate, {bool viaWhatsApp = false}) async {
    final file = await _ensurePdfDownloaded(certificate);
    if (file == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo obtener el PDF del certificado desde Google Drive.')),
        );
      }
      return;
    }

    final clientName = certificate.clientName;
    final docTitle = certificate.title;
    final message = viaWhatsApp
        ? 'Estimado cliente de *$clientName*, le compartimos su Certificado de Fumigación (*$docTitle*) emitido por EJ Exterminadores. ¡Quedamos a sus órdenes!'
        : 'Certificado de Fumigación - $clientName ($docTitle)';

    try {
      await Share.shareXFiles(
        [XFile(file.path, name: certificate.pdfName)],
        text: message,
        subject: 'Certificado de Fumigación - $clientName',
      );
    } catch (_) {
      final phone = certificate.clientPhone.replaceAll(RegExp(r'\D'), '');
      final encodedText = Uri.encodeComponent(message);
      final url = phone.isNotEmpty
          ? 'https://wa.me/52$phone?text=$encodedText'
          : 'https://wa.me/?text=$encodedText';
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _getFilteredCertificates();
    final uniqueClients = _getUniqueClients();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Certificados de Fumigación', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0F2B48),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_newestFirst ? Icons.arrow_downward : Icons.arrow_upward),
            tooltip: _newestFirst ? 'Orden: Más recientes primero' : 'Orden: Más antiguos primero',
            onPressed: () {
              setState(() => _newestFirst = !_newestFirst);
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar desde Google Drive',
            onPressed: _loadCertificates,
          ),
        ],
      ),
      body: !_driveService.isSignedIn
          ? _buildNotConnectedView()
          : Column(
              children: [
                // BARRA DE BÚSQUEDA, ORDEN Y FILTRO DE CLIENTE
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchCtrl,
                              decoration: InputDecoration(
                                hintText: 'Buscar por cliente o nombre de certificado...',
                                prefixIcon: const Icon(Icons.search, size: 20),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 18),
                                        onPressed: () {
                                          setState(() {
                                            _searchCtrl.clear();
                                            _searchQuery = '';
                                          });
                                        },
                                      )
                                    : null,
                                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                isDense: true,
                              ),
                              onChanged: (val) => setState(() => _searchQuery = val),
                            ),
                          ),
                          if (uniqueClients.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            PopupMenuButton<String?>(
                              tooltip: 'Filtrar por cliente',
                              icon: Icon(
                                Icons.filter_alt_outlined,
                                color: _selectedClientFilter != null ? const Color(0xFF0F2B48) : Colors.grey,
                              ),
                              onSelected: (val) => setState(() => _selectedClientFilter = val),
                              itemBuilder: (context) => [
                                const PopupMenuItem(value: null, child: Text('Todos los clientes')),
                                const PopupMenuDivider(),
                                ...uniqueClients.map((c) => PopupMenuItem(value: c, child: Text(c))),
                              ],
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            _newestFirst ? Icons.schedule : Icons.history,
                            size: 14,
                            color: const Color(0xFF0F766E),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              _newestFirst
                                  ? '${filteredList.length} certificado(s) • Más recientes arriba'
                                  : '${filteredList.length} certificado(s) • Más antiguos arriba',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF475569),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (_selectedClientFilter != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFCCFBF1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF99F6E4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 140),
                                    child: Text(
                                      _selectedClientFilter!,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF0F766E),
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  InkWell(
                                    onTap: () => setState(() => _selectedClientFilter = null),
                                    child: const Icon(Icons.close, size: 14, color: Color(0xFF0F766E)),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),
                if (_isRefreshing || _isCreatingFolders)
                  const LinearProgressIndicator(
                    minHeight: 2.5,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0F766E)),
                  ),

                // LISTA DE CERTIFICADOS
                Expanded(
                  child: (_isLoading && _allCertificates.isEmpty)
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 14),
                              Text('Consultando certificados en Google Drive...', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        )
                      : _buildCertificatesList(filteredList),
                ),
              ],
            ),
    );
  }

  Widget _buildNotConnectedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(color: Colors.teal.shade50, shape: BoxShape.circle),
              child: Icon(Icons.verified_outlined, size: 36, color: Colors.teal.shade800),
            ),
            const SizedBox(height: 16),
            const Text(
              'Conecta Google Drive para ver tus certificados',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF0F2B48)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Tus certificados de fumigación en PDF se consultan directamente desde la carpeta "Certificados" de cada cliente en Google Drive.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F2B48),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.cloud_sync),
              label: const Text('Conectar con Google Drive'),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const GoogleDriveSyncScreen()),
                );
                _loadCertificates();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCertificatesList(List<CertificateModel> list) {
    if (list.isEmpty) {
      final hasFilter = _selectedClientFilter != null || _searchQuery.trim().isNotEmpty;
      return RefreshIndicator(
        onRefresh: _loadCertificates,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 36),
            Center(
              child: Column(
                children: [
                  Icon(Icons.verified_outlined, size: 52, color: Colors.teal.withValues(alpha: 0.55)),
                  const SizedBox(height: 12),
                  Text(
                    hasFilter
                        ? 'No se encontraron certificados con ese filtro.'
                        : 'Aún no hay certificados PDF en Drive.',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F2B48)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Agrega manualmente los archivos PDF a la carpeta "EJ Exterminadores / Clientes / [Cliente] / Certificados" en tu Google Drive y desliza hacia abajo para actualizar.',
                    style: TextStyle(fontSize: 12.5, color: Colors.grey, height: 1.4),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  if (!hasFilter) ...[
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                      ),
                      icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                      label: const Text('Crear carpetas "Certificados" en Drive ahora', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                      onPressed: _isCreatingFolders ? null : _createCertificateFoldersForAll,
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0F2B48),
                        side: const BorderSide(color: Color(0xFF0F2B48)),
                      ),
                      icon: const Icon(Icons.sync_lock_outlined, size: 16),
                      label: const Text('¿Subiste un certificado y no aparece? Actualizar acceso', style: TextStyle(fontSize: 12)),
                      onPressed: () async {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Actualizando permisos de Google Drive...')),
                        );
                        await _driveService.requestFullDriveAccess();
                        _loadCertificates();
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCertificates,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: list.length,
        itemBuilder: (context, index) => _buildCertificateCard(list[index]),
      ),
    );
  }

  Widget _buildCertificateCard(CertificateModel cert) {
    final dateStr = DateFormat('dd/MM/yyyy • HH:mm').format(cert.addedTime.toLocal());

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCCFBF1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.verified_outlined, color: Color(0xFF0F766E), size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cert.clientName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F2B48)),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDFA),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF99F6E4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.schedule, size: 11, color: Color(0xFF0F766E)),
                                const SizedBox(width: 4),
                                Text(
                                  'Agregado: $dateStr',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F766E),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (cert.subfolderName.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                cert.subfolderName,
                                style: TextStyle(fontSize: 10, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                              ),
                            ),
                          if (cert.formattedFileSize.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                cert.formattedFileSize,
                                style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
                  onSelected: (val) {
                    if (val == 'share') {
                      _shareCertificate(cert);
                    } else if (val == 'drive' && cert.pdfWebViewLink != null) {
                      launchUrl(Uri.parse(cert.pdfWebViewLink!), mode: LaunchMode.externalApplication);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'share', child: Text('Compartir archivo PDF')),
                    if (cert.pdfWebViewLink != null)
                      const PopupMenuItem(value: 'drive', child: Text('Abrir en Google Drive')),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.picture_as_pdf, size: 16, color: Colors.red),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    cert.pdfName,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      side: const BorderSide(color: Color(0xFF0F2B48)),
                      foregroundColor: const Color(0xFF0F2B48),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                    ),
                    icon: const Icon(Icons.visibility_outlined, size: 16),
                    label: const Text('Ver PDF', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () => _viewCertificate(cert),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      backgroundColor: const Color(0xFF15803D),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                    ),
                    icon: const Icon(Icons.chat, size: 15),
                    label: const Text('WhatsApp', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () => _shareCertificate(cert, viaWhatsApp: true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
