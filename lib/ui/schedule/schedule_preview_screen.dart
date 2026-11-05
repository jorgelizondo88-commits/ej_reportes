import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/schedule_model.dart';
import '../../services/calendar_sync_service.dart';
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
  bool _isSyncing = false;

  Future<void> _syncToGoogleCalendar() async {
    setState(() => _isSyncing = true);
    try {
      final service = CalendarSyncService();
      int synced = 0;
      for (final v in widget.schedule.visits) {
        final res = await service.syncVisitToGoogleCalendar(
          v,
          clientNameOverride: widget.schedule.clientBusinessName,
          phoneOverride: widget.schedule.clientPhone,
          addressOverride: widget.schedule.clientAddress,
        );
        if (res != null) synced++;
      }
      await _saveToHistory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡$synced visitas sincronizadas con Google Calendar!'),
            backgroundColor: const Color(0xFF0F2B48),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al sincronizar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

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
        'isInAgenda': widget.schedule.isInAgenda,
        'filePath': file.path,
        'scheduleData': widget.schedule.toMap(),
        'savedAt': DateTime.now().toIso8601String(),
      };

      // Prevención de Duplicados: Si ya existen visitas activas en agenda para este mismo cliente
      if (widget.schedule.isInAgenda) {
        final existingWithSameClient = historyList.where((item) {
          if (item['folio'] == widget.schedule.folio) return false;
          final bName = (item['businessName'] ?? '').toString().trim().toLowerCase();
          final currentBName = widget.schedule.clientBusinessName.trim().toLowerCase();
          final hasInAgenda = item['isInAgenda'] == true ||
              (item['scheduleData'] != null && item['scheduleData']['isInAgenda'] == true);
          return currentBName.isNotEmpty && bName == currentBName && hasInAgenda;
        }).toList();

        if (existingWithSameClient.isNotEmpty && mounted) {
          final choice = await showDialog<String>(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(child: Text('Cliente con visitas previas', style: TextStyle(fontSize: 16))),
                ],
              ),
              content: Text(
                'Detectamos que "${widget.schedule.clientBusinessName}" ya tiene visitas activas en tu Agenda de Trabajo.\n\n'
                '¿Cómo deseas manejar esta nueva póliza?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, 'keep_both'),
                  child: const Text('Mantener ambas'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, 'replace_old'),
                  child: const Text('Reemplazar anteriores', style: TextStyle(color: Colors.red)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F2B48), foregroundColor: Colors.white),
                  onPressed: () => Navigator.pop(context, 'only_pdf'),
                  child: const Text('Solo guardar PDF'),
                ),
              ],
            ),
          );

          if (choice == 'only_pdf') {
            entry['isInAgenda'] = false;
            final mapData = entry['scheduleData'] as Map<String, dynamic>;
            mapData['isInAgenda'] = false;
          } else if (choice == 'replace_old') {
            for (final oldItem in existingWithSameClient) {
              oldItem['isInAgenda'] = false;
              if (oldItem['scheduleData'] != null) {
                (oldItem['scheduleData'] as Map<String, dynamic>)['isInAgenda'] = false;
              }
            }
          }
        }
      }

      // Sincronización opcional con Google Calendar
      if (entry['isInAgenda'] == true && mounted) {
        final syncGoogle = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('¿Sincronizar con Google Calendar?'),
            content: Text(
              'Has agregado estas ${widget.schedule.visits.length} visitas a tu Agenda de la app.\n\n'
              '¿Deseas sincronizarlas también con Google Calendar en tu teléfono y PC?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Solo en la App'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F2B48), foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Sí, con Google Calendar'),
              ),
            ],
          ),
        );

        if (syncGoogle == true) {
          final syncService = CalendarSyncService();
          for (final v in widget.schedule.visits) {
            final evId = await syncService.syncVisitToGoogleCalendar(v);
            if (evId != null) v.calendarEventId = evId;
          }
          entry['scheduleData'] = widget.schedule.toMap();
        }
      }

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

  String _buildFileName() {
    final clientTitle = widget.schedule.clientBusinessName.isNotEmpty
        ? widget.schedule.clientBusinessName
        : widget.schedule.clientContactName;
    final cleanClient = clientTitle
        .trim()
        .replaceAll(RegExp(r'[^\wáéíóúÁÉÍÓÚñÑ\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '_');
    final cleanFolio = widget.schedule.folio.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

    return cleanClient.isNotEmpty
        ? 'Cronograma_${cleanFolio}_$cleanClient.pdf'
        : 'Cronograma_$cleanFolio.pdf';
  }

  Future<void> _shareSchedule() async {
    try {
      final pdfBytes = await SchedulePdfService.generateSchedulePdf(widget.schedule);
      final tempDir = await getTemporaryDirectory();
      final fileName = _buildFileName();
      final file = File('${tempDir.path}/$fileName');
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
    final screenWidth = MediaQuery.of(context).size.width;
    final fileName = _buildFileName();

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
            icon: _isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            tooltip: 'Sincronizar visitas con Google Calendar',
            onPressed: _isSyncing ? null : _syncToGoogleCalendar,
          ),
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
          allowPrinting: false,
          allowSharing: false,
          canChangePageFormat: false,
          canChangeOrientation: false,
          canDebug: false,
          maxPageWidth: screenWidth,
          pdfFileName: fileName,
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
