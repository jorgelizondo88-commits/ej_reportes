import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/certificate_model.dart';

class CertificateViewerScreen extends StatelessWidget {
  final CertificateModel certificate;
  final File localPdfFile;

  const CertificateViewerScreen({
    super.key,
    required this.certificate,
    required this.localPdfFile,
  });

  Future<void> _sharePdf(BuildContext context) async {
    try {
      await Share.shareXFiles(
        [XFile(localPdfFile.path, name: certificate.pdfName)],
        text: 'Certificado de Fumigación - ${certificate.clientName} (EJ Exterminadores)',
        subject: 'Certificado: ${certificate.title}',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al compartir: $e')),
        );
      }
    }
  }

  Future<void> _shareViaWhatsApp(BuildContext context) async {
    final clientName = certificate.clientName;
    final docTitle = certificate.title;
    final message =
        'Estimado cliente de *$clientName*, le compartimos su Certificado de Fumigación (*$docTitle*) emitido por EJ Exterminadores. ¡Quedamos a sus órdenes!';

    try {
      await Share.shareXFiles(
        [XFile(localPdfFile.path, name: certificate.pdfName)],
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
    final addedText = DateFormat('dd/MM/yyyy HH:mm').format(certificate.addedTime.toLocal());

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              certificate.pdfName,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${certificate.clientName} • Agregado: $addedText',
              style: const TextStyle(fontSize: 11, color: Colors.white70),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0F2B48),
        foregroundColor: Colors.white,
        actions: [
          if (certificate.pdfWebViewLink != null)
            IconButton(
              icon: const Icon(Icons.open_in_new),
              tooltip: 'Abrir en Google Drive',
              onPressed: () {
                launchUrl(Uri.parse(certificate.pdfWebViewLink!), mode: LaunchMode.externalApplication);
              },
            ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Compartir PDF',
            onPressed: () => _sharePdf(context),
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            tooltip: 'Enviar por WhatsApp',
            onPressed: () => _shareViaWhatsApp(context),
          ),
        ],
      ),
      body: PdfPreview(
        build: (format) => localPdfFile.readAsBytes(),
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        allowPrinting: true,
        allowSharing: true,
        pdfFileName: certificate.pdfName,
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, -2)),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF0F2B48)),
                    foregroundColor: const Color(0xFF0F2B48),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.share_outlined, size: 18),
                  label: const Text('Compartir PDF', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () => _sharePdf(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF15803D),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.chat, size: 18),
                  label: const Text('Enviar WhatsApp', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () => _shareViaWhatsApp(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
