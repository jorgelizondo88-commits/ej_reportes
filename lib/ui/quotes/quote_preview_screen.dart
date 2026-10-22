import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/quote_model.dart';
import '../../services/quote_pdf_service.dart';

class QuotePreviewScreen extends StatefulWidget {
  final QuoteModel quote;

  const QuotePreviewScreen({super.key, required this.quote});

  @override
  State<QuotePreviewScreen> createState() => _QuotePreviewScreenState();
}

class _QuotePreviewScreenState extends State<QuotePreviewScreen> {
  static const String _quotesHistoryKey = 'ej_quotes_history_list';
  bool _isSaved = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _checkIfAlreadySaved();
  }

  Future<void> _checkIfAlreadySaved() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_quotesHistoryKey);
    if (raw != null && raw.isNotEmpty) {
      final List list = jsonDecode(raw);
      final exists = list.any((item) => item['folio'] == widget.quote.quoteFolio);
      if (mounted) setState(() => _isSaved = exists);
    }
  }

  Future<void> _saveToHistory() async {
    setState(() => _isSaving = true);
    try {
      final pdfBytes = await QuotePdfService.generateQuotePdf(widget.quote);

      final appDir = await getApplicationDocumentsDirectory();
      final quotesDir = Directory('${appDir.path}/cotizaciones_guardadas');
      if (!await quotesDir.exists()) {
        await quotesDir.create(recursive: true);
      }

      final cleanFolio = widget.quote.quoteFolio.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final filePath = '${quotesDir.path}/$cleanFolio.pdf';
      final file = File(filePath);
      await file.writeAsBytes(pdfBytes, flush: true);

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_quotesHistoryKey);
      List<dynamic> historyList = raw != null && raw.isNotEmpty ? jsonDecode(raw) : [];

      final entry = {
        'folio': widget.quote.quoteFolio,
        'businessName': widget.quote.clientBusinessName,
        'clientName': widget.quote.clientContactName,
        'clientPhone': widget.quote.clientPhone,
        'clientAddress': widget.quote.clientAddress,
        'clientEmail': widget.quote.clientEmail,
        'quoteDate': widget.quote.quoteDate.toIso8601String(),
        'validDays': widget.quote.validDays,
        'validUntilDate': widget.quote.validUntilDate.toIso8601String(),
        'totalAmount': widget.quote.totalAmount,
        'subtotal': widget.quote.subtotal,
        'applyIva': widget.quote.applyIva,
        'filePath': file.path,
        'itemsCount': widget.quote.items.length,
        'savedAt': DateTime.now().toIso8601String(),
      };

      final existingIndex = historyList.indexWhere((item) => item['folio'] == widget.quote.quoteFolio);
      if (existingIndex >= 0) {
        historyList[existingIndex] = entry;
      } else {
        historyList.insert(0, entry);
      }

      await prefs.setString(_quotesHistoryKey, jsonEncode(historyList));

      if (mounted) {
        setState(() {
          _isSaved = true;
          _isSaving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡Cotización #${widget.quote.quoteFolio} guardada en el historial!'),
            backgroundColor: Colors.green.shade800,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar la cotización: $e'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    }
  }

  Future<void> _shareQuote() async {
    try {
      final pdfBytes = await QuotePdfService.generateQuotePdf(widget.quote);
      final tempDir = await getTemporaryDirectory();
      final cleanFolio = widget.quote.quoteFolio.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final file = File('${tempDir.path}/$cleanFolio.pdf');
      await file.writeAsBytes(pdfBytes);

      final clientTitle = widget.quote.clientBusinessName.isNotEmpty
          ? widget.quote.clientBusinessName
          : widget.quote.clientContactName;

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Cotización de Servicios de Control de Plagas - Folio ${widget.quote.quoteFolio}',
        subject: 'Cotización: $clientTitle',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al compartir: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Cotización #${widget.quote.quoteFolio}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        backgroundColor: const Color(0xFF0F2B48),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Compartir Cotización',
            onPressed: _shareQuote,
          ),
          IconButton(
            icon: _isSaving
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            )
                : Icon(
              _isSaved ? Icons.bookmark : Icons.bookmark_border,
              color: _isSaved ? Colors.amberAccent : Colors.white,
            ),
            tooltip: _isSaved ? 'Guardada' : 'Guardar en Historial',
            onPressed: _isSaving ? null : _saveToHistory,
          ),
        ],
      ),
      body: InteractiveViewer(
        minScale: 1.0,
        maxScale: 3.5,
        panEnabled: true,
        scaleEnabled: true,
        child: PdfPreview(
          build: (format) => QuotePdfService.generateQuotePdf(widget.quote),
          allowPrinting: true,
          allowSharing: true,
          canChangePageFormat: false,
          canChangeOrientation: false,
          canDebug: false,
          maxPageWidth: screenWidth,
          pdfFileName: 'Cotizacion_${widget.quote.quoteFolio}.pdf',
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, -3)),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    side: const BorderSide(color: Color(0xFF0F2B48)),
                    foregroundColor: const Color(0xFF0F2B48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.share, size: 20),
                  label: const Text('Compartir PDF', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: _shareQuote,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    backgroundColor: _isSaved ? Colors.green.shade800 : const Color(0xFF0F2B48),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: Icon(_isSaved ? Icons.check_circle : Icons.save, size: 20),
                  label: Text(
                    _isSaved ? '¡Guardada!' : 'Guardar en Historial',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: _isSaving ? null : _saveToHistory,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
