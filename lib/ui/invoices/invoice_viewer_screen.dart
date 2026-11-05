import 'dart:io';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/invoice_model.dart';
import '../../services/google_drive_sync_service.dart';

class InvoiceViewerScreen extends StatefulWidget {
  final InvoiceModel invoice;
  final File localPdfFile;

  const InvoiceViewerScreen({
    super.key,
    required this.invoice,
    required this.localPdfFile,
  });

  @override
  State<InvoiceViewerScreen> createState() => _InvoiceViewerScreenState();
}

class _InvoiceViewerScreenState extends State<InvoiceViewerScreen> {
  final GoogleDriveSyncService _driveService = GoogleDriveSyncService();
  bool _isProcessing = false;
  late InvoiceModel _currentInvoice;

  @override
  void initState() {
    super.initState();
    _currentInvoice = widget.invoice;
  }

  Future<void> _sharePdf() async {
    try {
      await Share.shareXFiles(
        [XFile(widget.localPdfFile.path, name: _currentInvoice.pdfName)],
        text: 'Factura ${_currentInvoice.folio} - ${_currentInvoice.clientName} (EJ Exterminadores)',
        subject: 'Factura: ${_currentInvoice.folio}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al compartir: $e')),
        );
      }
    }
  }

  Future<void> _shareViaWhatsApp() async {
    final clientName = _currentInvoice.clientName;
    final folio = _currentInvoice.folio;
    final message = 'Estimado cliente de *$clientName*, le compartimos la factura *$folio* de EJ Exterminadores correspondiente a sus servicios de control de plagas. Agradecemos su apoyo con la gestión del pago. ¡Quedamos a sus órdenes!';

    try {
      // Compartir archivo directamente por Share con el texto precargado
      await Share.shareXFiles(
        [XFile(widget.localPdfFile.path, name: _currentInvoice.pdfName)],
        text: message,
        subject: 'Factura $folio - $clientName',
      );
    } catch (_) {
      // Alternativa vía URL directa de WhatsApp si falla
      final phone = _currentInvoice.clientPhone.replaceAll(RegExp(r'\D'), '');
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

  Future<void> _confirmMarkPaid() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Color(0xFF16A34A)),
            SizedBox(width: 8),
            Text('¿Confirmar Pago?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Confirmas que el cliente "${_currentInvoice.clientName}" ya pagó esta factura?'),
            const SizedBox(height: 12),
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
                  Text('📄 PDF: ${_currentInvoice.pdfName}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  if (_currentInvoice.hasXml) ...[
                    const SizedBox(height: 4),
                    Text('📑 XML: ${_currentInvoice.xmlFileName ?? "archivo.xml"}', style: TextStyle(fontSize: 12, color: Colors.green.shade900)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'En Google Drive, ambos archivos se moverán automáticamente de "Pendientes_de_Pago" a "Pagadas".',
              style: TextStyle(fontSize: 11.5, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, Marcar Pagada'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isProcessing = true);
      final ok = await _driveService.markInvoiceAsPaid(_currentInvoice);
      setState(() => _isProcessing = false);

      if (mounted) {
        if (ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Factura marcada como pagada y movida en Google Drive con éxito!'),
              backgroundColor: Color(0xFF16A34A),
            ),
          );
          Navigator.pop(context, true); // Devuelve true para refrescar la lista
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo mover la factura en Google Drive. Revisa tu conexión.')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_currentInvoice.pdfName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            Text(_currentInvoice.clientName, style: const TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        backgroundColor: const Color(0xFF0F2B48),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Compartir Factura',
            onPressed: _sharePdf,
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            tooltip: 'Enviar por WhatsApp',
            onPressed: _shareViaWhatsApp,
          ),
        ],
      ),
      body: Stack(
        children: [
          PdfPreview(
            build: (format) => widget.localPdfFile.readAsBytesSync(),
            canChangeOrientation: false,
            canChangePageFormat: false,
            canDebug: false,
            allowPrinting: true,
            allowSharing: true,
            pdfFileName: _currentInvoice.pdfName,
          ),
          if (_isProcessing)
            Container(
              color: Colors.black45,
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(width: 16),
                        Text('Moviendo en Google Drive...', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, -2))],
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF25D366)),
                    foregroundColor: const Color(0xFF15803D),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.chat, color: Color(0xFF25D366), size: 18),
                  label: const Text('Enviar WhatsApp', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: _isProcessing ? null : _shareViaWhatsApp,
                ),
              ),
              const SizedBox(width: 10),
              if (_currentInvoice.status == 'pending')
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Marcar Pagada', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: _isProcessing ? null : _confirmMarkPaid,
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: _currentInvoice.status == 'paid' ? Colors.green.shade100 : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _currentInvoice.status == 'paid' ? Icons.check_circle : Icons.cancel_outlined,
                        color: _currentInvoice.status == 'paid' ? Colors.green.shade800 : Colors.grey.shade700,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _currentInvoice.status == 'paid' ? 'Pagada' : 'Cancelada',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _currentInvoice.status == 'paid' ? Colors.green.shade900 : Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
