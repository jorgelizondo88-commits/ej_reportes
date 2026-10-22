import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/schedule_model.dart';
import '../../services/schedule_pdf_service.dart';

class SchedulePreviewScreen extends StatefulWidget {
  final ScheduleModel schedule;

  const SchedulePreviewScreen({super.key, required this.schedule});

  @override
  State<SchedulePreviewScreen> createState() => _SchedulePreviewScreenState();
}

class _SchedulePreviewScreenState extends State<SchedulePreviewScreen> {
  static const String _schedulesHistoryKey = 'ej_schedules_history_list';
  bool _isSaved = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _checkIfAlreadySaved();
  }

  Future<void> _checkIfAlreadySaved() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_schedulesHistoryKey);
    if (raw != null && raw.isNotEmpty) {
      final List list = jsonDecode(raw);
      final exists = list.any((item) => item['folio'] == widget.schedule.folio);
      if (mounted) setState(() => _isSaved = exists);
    }
  }

  Future<void> _saveToHistory() async {
    setState(() => _isSaving = true);
    try {
      final pdfBytes = await SchedulePdfService.generateSchedulePdf(widget.schedule);

      final appDir = await getApplicationDocumentsDirectory();
      final schedulesDir = Directory('${appDir.path}/calendarizaciones_guardadas');
      if (!await schedulesDir.exists()) {
        await schedulesDir.create(recursive: true);
      }

      final cleanFolio = widget.schedule.folio.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final filePath = '${schedulesDir.path}/$cleanFolio.pdf';
      final file = File(filePath);
      await file.writeAsBytes(pdfBytes, flush: true);

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_schedulesHistoryKey);
      List<dynamic> historyList = raw != null && raw.isNotEmpty ? jsonDecode(raw) : [];

      final entry = {
        'id': widget.schedule.id,
        'folio': widget.schedule.folio,
        'title': widget.schedule.title,
        'businessName': widget.schedule.clientBusinessName,
        'clientName': widget.schedule.clientContactName,
        'clientPhone': widget.schedule.clientPhone,
        'clientAddress': widget.schedule.clientAddress,
        'clientEmail': widget.schedule.clientEmail,
        'facilityType': widget.schedule.facilityType,
        'createdAt': widget.schedule.createdAt.toIso8601String(),
        'startDate': widget.schedule.startDate.toIso8601String(),
        'durationMonths': widget.schedule.durationMonths,
        'recurrenceDescription': widget.schedule.recurrenceDescription,
        'totalVisits': widget.schedule.totalVisits,
        'completedVisits': widget.schedule.completedVisits,
        'filePath': file.path,
        'scheduleData': widget.schedule.toMap(),
        'savedAt': DateTime.now().toIso8601String(),
      };

      final existingIndex = historyList.indexWhere((item) => item['folio'] == widget.schedule.folio);
      if (existingIndex >= 0) {
        historyList[existingIndex] = entry;
      } else {
        historyList.insert(0, entry);
      }

      await prefs.setString(_schedulesHistoryKey, jsonEncode(historyList));

      if (mounted) {
        setState(() {
          _isSaved = true;
          _isSaving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡Cronograma #${widget.schedule.folio} guardado en el historial!'),
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
            content: Text('Error al guardar calendarización: $e'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    }
  }

  Future<void> _shareSchedule() async {
    try {
      final pdfBytes = await SchedulePdfService.generateSchedulePdf(widget.schedule);
      final tempDir = await getTemporaryDirectory();
      final cleanFolio = widget.schedule.folio.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final file = File('${tempDir.path}/$cleanFolio.pdf');
      await file.writeAsBytes(pdfBytes);

      final clientTitle = widget.schedule.clientBusinessName.isNotEmpty
          ? widget.schedule.clientBusinessName
          : widget.schedule.clientContactName;

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Calendario Oficial de Servicios - EJ Exterminadores (Folio ${widget.schedule.folio})',
        subject: 'Programa de Servicios: $clientTitle',
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Cronograma #${widget.schedule.folio}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        backgroundColor: const Color(0xFF0F2B48),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Compartir Calendario',
            onPressed: _shareSchedule,
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
            tooltip: _isSaved ? 'Guardado' : 'Guardar en Historial',
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
          build: (format) => SchedulePdfService.generateSchedulePdf(widget.schedule),
          allowPrinting: true,
          allowSharing: true,
          canChangePageFormat: false,
          canChangeOrientation: false,
          canDebug: false,
          pdfFileName: 'Cronograma_${widget.schedule.folio}.pdf',
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, -3)),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.share, color: Color(0xFF0F2B48), size: 18),
                  label: const Text('Compartir PDF', style: TextStyle(color: Color(0xFF0F2B48), fontWeight: FontWeight.bold)),
                  onPressed: _shareSchedule,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isSaved ? Colors.green.shade700 : const Color(0xFF0F2B48),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: Icon(_isSaved ? Icons.check : Icons.save, size: 18),
                  label: Text(
                    _isSaved ? 'Guardado ✓' : 'Guardar en Historial',
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
