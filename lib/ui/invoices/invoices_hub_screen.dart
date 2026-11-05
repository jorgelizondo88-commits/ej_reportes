import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/invoice_model.dart';
import '../../services/google_drive_sync_service.dart';
import '../cloud/google_drive_sync_screen.dart';
import 'invoice_viewer_screen.dart';

class InvoicesHubScreen extends StatefulWidget {
  final String? initialClientFilter;
  final int initialTab;

  const InvoicesHubScreen({
    super.key,
    this.initialClientFilter,
    this.initialTab = 0,
  });

  @override
  State<InvoicesHubScreen> createState() => _InvoicesHubScreenState();
}

class _InvoicesHubScreenState extends State<InvoicesHubScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GoogleDriveSyncService _driveService = GoogleDriveSyncService();

  List<InvoiceModel> _allInvoices = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String _searchQuery = '';
  String? _selectedClientFilter;
  final TextEditingController _searchCtrl = TextEditingController();

  final Map<String, File> _downloadedPdfs = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: (widget.initialTab >= 0 && widget.initialTab <= 2) ? widget.initialTab : 0,
    );
    if (widget.initialClientFilter != null && widget.initialClientFilter!.isNotEmpty) {
      _selectedClientFilter = widget.initialClientFilter;
    }
    _initInvoices();
  }

  Future<void> _initInvoices() async {
    // 1. Mostrar inmediatamente las facturas guardadas en caché local (0 ms, sin esperas)
    final cached = await _driveService.getCachedInvoices();
    if (cached.isNotEmpty && mounted) {
      setState(() {
        _allInvoices = cached;
        _isLoading = false;
      });
    }

    // 2. Refrescar silenciosamente desde Google Drive en segundo plano
    await _loadInvoices(showSpinner: cached.isEmpty);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInvoices({bool showSpinner = false}) async {
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

    final list = await _driveService.fetchInvoices();
    if (mounted) {
      setState(() {
        _allInvoices = list;
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  List<InvoiceModel> _filterByStatus(String status) {
    return _allInvoices.where((inv) {
      if (inv.status != status) return false;
      if (_selectedClientFilter != null && _selectedClientFilter!.isNotEmpty) {
        if (inv.clientName.trim().toLowerCase() != _selectedClientFilter!.trim().toLowerCase()) {
          return false;
        }
      }
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        final matchesClient = inv.clientName.toLowerCase().contains(q);
        final matchesFolio = inv.folio.toLowerCase().contains(q);
        final matchesName = inv.pdfName.toLowerCase().contains(q);
        if (!matchesClient && !matchesFolio && !matchesName) return false;
      }
      return true;
    }).toList();
  }

  List<String> _getUniqueClients() {
    final set = <String>{};
    for (final inv in _allInvoices) {
      if (inv.clientName.isNotEmpty) {
        set.add(inv.clientName);
      }
    }
    final list = set.toList();
    list.sort((a, b) => a.compareTo(b));
    return list;
  }

  Future<File?> _ensurePdfDownloaded(InvoiceModel invoice) async {
    if (_downloadedPdfs.containsKey(invoice.id) && _downloadedPdfs[invoice.id]!.existsSync()) {
      return _downloadedPdfs[invoice.id]!;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            const SizedBox(width: 12),
            Expanded(child: Text('Descargando ${invoice.pdfName} desde Google Drive...')),
          ],
        ),
        duration: const Duration(seconds: 4),
      ),
    );

    final file = await _driveService.downloadInvoicePdf(invoice);
    if (file != null && file.existsSync()) {
      _downloadedPdfs[invoice.id] = file;
      return file;
    }
    return null;
  }

  Future<void> _viewInvoice(InvoiceModel invoice) async {
    final file = await _ensurePdfDownloaded(invoice);
    if (file == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo descargar el PDF de la factura desde Google Drive.')),
        );
      }
      return;
    }

    if (!mounted) return;
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => InvoiceViewerScreen(
          invoice: invoice,
          localPdfFile: file,
        ),
      ),
    );

    if (changed == true) {
      _loadInvoices();
    }
  }

  Future<void> _shareWhatsApp(InvoiceModel invoice) async {
    final file = await _ensurePdfDownloaded(invoice);
    if (file == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo obtener el PDF de la factura desde Google Drive.')),
        );
      }
      return;
    }

    final clientName = invoice.clientName;
    final folio = invoice.folio;
    final message = 'Estimado cliente de *$clientName*, le compartimos la factura *$folio* de EJ Exterminadores correspondiente a sus servicios de control de plagas. Agradecemos su apoyo con la gestión del pago. ¡Quedamos a sus órdenes!';

    try {
      await Share.shareXFiles(
        [XFile(file.path, name: invoice.pdfName)],
        text: message,
        subject: 'Factura $folio - $clientName',
      );
    } catch (_) {
      final phone = invoice.clientPhone.replaceAll(RegExp(r'\D'), '');
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

  Future<void> _confirmMarkPaid(InvoiceModel invoice) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Color(0xFF16A34A)),
            SizedBox(width: 8),
            Text('¿Marcar como Pagada?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Confirmas que "${invoice.clientName}" ya pagó esta factura?'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('📄 PDF: ${invoice.pdfName}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  if (invoice.hasXml) ...[
                    const SizedBox(height: 4),
                    Text('📑 XML: ${invoice.xmlFileName ?? "archivo.xml"}', style: TextStyle(fontSize: 12, color: Colors.green.shade900)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'En Google Drive, se moverán automáticamente tanto el PDF como el XML de "Pendientes_de_Pago" a "Pagadas".',
              style: TextStyle(fontSize: 11.5, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar Pago'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Moviendo factura a "Pagadas" en Google Drive...')),
      );

      final ok = await _driveService.markInvoiceAsPaid(invoice);
      if (mounted) {
        if (ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Factura y XML movidos a "Pagadas" exitosamente!'),
              backgroundColor: Color(0xFF16A34A),
            ),
          );
          _loadInvoices();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al mover la factura en Google Drive.')),
          );
        }
      }
    }
  }

  Future<void> _changeStatus(InvoiceModel invoice, String newStatus) async {
    bool ok = false;
    if (newStatus == 'canceled') {
      ok = await _driveService.markInvoiceAsCanceled(invoice);
    } else if (newStatus == 'pending') {
      ok = await _driveService.markInvoiceAsPending(invoice);
    }

    if (mounted) {
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Estado de factura actualizado a: $newStatus')),
        );
        _loadInvoices();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al actualizar en Google Drive.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingList = _filterByStatus('pending');
    final paidList = _filterByStatus('paid');
    final canceledList = _filterByStatus('canceled');
    final uniqueClients = _getUniqueClients();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Facturación & Cobranza', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0F2B48),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: _loadInvoices,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Pendientes'),
                  if (pendingList.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.shade600,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${pendingList.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Pagadas'),
                  if (paidList.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.shade600,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${paidList.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Canceladas'),
                  if (canceledList.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Text('(${canceledList.length})', style: const TextStyle(fontSize: 11)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: !_driveService.isSignedIn
          ? _buildNotConnectedView()
          : Column(
              children: [
                // BARRA DE BÚSQUEDA Y FILTRO DE CLIENTE
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
                                hintText: 'Buscar por cliente o folio...',
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
                      if (_selectedClientFilter != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFBFDBFE)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('Cliente: $_selectedClientFilter', style: const TextStyle(fontSize: 11.5, color: Color(0xFF1E40AF), fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 4),
                                  InkWell(
                                    onTap: () => setState(() => _selectedClientFilter = null),
                                    child: const Icon(Icons.close, size: 14, color: Color(0xFF1E40AF)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                const Divider(height: 1),
                if (_isRefreshing)
                  const LinearProgressIndicator(
                    minHeight: 2.5,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF16A34A)),
                  ),

                // CONTENIDO DE LAS PESTAÑAS
                Expanded(
                  child: (_isLoading && _allInvoices.isEmpty)
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 14),
                              Text('Consultando facturas en Google Drive...', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        )
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildInvoiceList(pendingList, 'pending'),
                            _buildInvoiceList(paidList, 'paid'),
                            _buildInvoiceList(canceledList, 'canceled'),
                          ],
                        ),
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
              decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
              child: Icon(Icons.cloud_off_outlined, size: 36, color: Colors.blue.shade800),
            ),
            const SizedBox(height: 16),
            const Text(
              'Conecta Google Drive para ver tus facturas',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF0F2B48)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Tus facturas en PDF y XML se consultan directamente desde la carpeta "5_Facturas" de tus clientes en Google Drive.',
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
                _loadInvoices();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceList(List<InvoiceModel> list, String status) {
    if (list.isEmpty) {
      String msg = 'No hay facturas pendientes de pago.';
      IconData icon = Icons.check_circle_outline;
      Color iconCol = Colors.green;

      if (status == 'paid') {
        msg = 'No hay facturas en la carpeta de Pagadas.';
        icon = Icons.receipt_long_outlined;
        iconCol = Colors.blue;
      } else if (status == 'canceled') {
        msg = 'No hay facturas canceladas.';
        icon = Icons.cancel_outlined;
        iconCol = Colors.grey;
      }

      return RefreshIndicator(
        onRefresh: _loadInvoices,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 40),
            Center(
              child: Column(
                children: [
                  Icon(icon, size: 48, color: iconCol.withValues(alpha: 0.6)),
                  const SizedBox(height: 12),
                  Text(msg, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F2B48))),
                  const SizedBox(height: 6),
                  if (status == 'pending') ...[
                    const Text(
                      'Arrastra los archivos PDF y XML de tus facturas a la carpeta "5_Facturas/Pendientes_de_Pago" de tu cliente en Google Drive desde la computadora para verlas aquí.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0F2B48),
                        side: const BorderSide(color: Color(0xFF0F2B48)),
                      ),
                      icon: const Icon(Icons.sync_lock_outlined, size: 16),
                      label: const Text('¿Subiste una factura y no aparece? Actualizar acceso a Drive', style: TextStyle(fontSize: 12)),
                      onPressed: () async {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Actualizando permisos de Google Drive...')),
                        );
                        await _driveService.requestFullDriveAccess();
                        _loadInvoices();
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
      onRefresh: _loadInvoices,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final inv = list[index];
          return _buildInvoiceCard(inv);
        },
      ),
    );
  }

  Widget _buildInvoiceCard(InvoiceModel inv) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final formattedDate = dateFormat.format(inv.createdTime);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ENCABEZADO: CLIENTE + ESTADO
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        inv.clientName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F2B48)),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F2B48).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Folio: ${inv.folio}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0F2B48)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (inv.hasXml)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.green.shade300),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check, size: 11, color: Colors.green.shade800),
                                  const SizedBox(width: 2),
                                  Text('PDF + XML', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green.shade900)),
                                ],
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text('Solo PDF', style: TextStyle(fontSize: 10, color: Colors.grey.shade700)),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
                  onSelected: (val) {
                    if (val == 'paid') {
                      _confirmMarkPaid(inv);
                    } else if (val == 'canceled') {
                      _changeStatus(inv, 'canceled');
                    } else if (val == 'pending') {
                      _changeStatus(inv, 'pending');
                    } else if (val == 'drive' && inv.pdfWebViewLink != null) {
                      launchUrl(Uri.parse(inv.pdfWebViewLink!), mode: LaunchMode.externalApplication);
                    }
                  },
                  itemBuilder: (context) => [
                    if (inv.status != 'paid')
                      const PopupMenuItem(value: 'paid', child: Text('Mover a Pagadas')),
                    if (inv.status != 'pending')
                      const PopupMenuItem(value: 'pending', child: Text('Regresar a Pendientes')),
                    if (inv.status != 'canceled')
                      const PopupMenuItem(value: 'canceled', child: Text('Marcar como Cancelada')),
                    if (inv.pdfWebViewLink != null) ...[
                      const PopupMenuDivider(),
                      const PopupMenuItem(value: 'drive', child: Text('Abrir en Google Drive')),
                    ],
                  ],
                ),
              ],
            ),

            const SizedBox(height: 10),

            // DETALLES DEL ARCHIVO
            Row(
              children: [
                const Icon(Icons.picture_as_pdf, size: 16, color: Colors.red),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    inv.pdfName,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  formattedDate,
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // BOTONES DE ACCIÓN: VER, WHATSAPP, MARCAR PAGADA
            Row(
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    side: const BorderSide(color: Color(0xFF0F2B48)),
                    foregroundColor: const Color(0xFF0F2B48),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('Ver PDF', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: () => _viewInvoice(inv),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    side: const BorderSide(color: Color(0xFF25D366)),
                    foregroundColor: const Color(0xFF15803D),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  icon: const Icon(Icons.chat, size: 15, color: Color(0xFF25D366)),
                  label: const Text('WhatsApp', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: () => _shareWhatsApp(inv),
                ),
                const Spacer(),
                if (inv.status == 'pending')
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Pagada', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () => _confirmMarkPaid(inv),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: inv.status == 'paid' ? Colors.green.shade50 : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      inv.status == 'paid' ? 'Pagada' : 'Cancelada',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: inv.status == 'paid' ? Colors.green.shade800 : Colors.grey.shade800,
                      ),
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
