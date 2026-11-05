import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/contract_model.dart';
import '../../models/schedule_model.dart';
import '../../services/calendar_sync_service.dart';
import '../../services/contract_pdf_service.dart';
import '../../services/google_drive_sync_service.dart';

class ContractPreviewScreen extends StatefulWidget {
  final ContractModel contract;

  const ContractPreviewScreen({super.key, required this.contract});

  @override
  State<ContractPreviewScreen> createState() => _ContractPreviewScreenState();
}

class _ContractPreviewScreenState extends State<ContractPreviewScreen> {
  static const String _contractsHistoryKey = 'ej_contracts_history_list';
  bool _isSaving = false;
  bool _isSaved = false;

  String _buildFileName() {
    final folio = widget.contract.folio.trim();
    final client = widget.contract.businessName.trim().isNotEmpty
        ? widget.contract.businessName.trim()
        : widget.contract.clientName.trim();

    final cleanFolio = folio.replaceAll(RegExp(r'[^\w-]'), '_');
    final cleanClient = client
        .replaceAll(RegExp(r'[^\wáéíóúÁÉÍÓÚñÑ\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '_');

    if (cleanClient.isEmpty) {
      return cleanFolio.isEmpty ? 'Contrato.pdf' : 'Contrato_$cleanFolio.pdf';
    }
    return 'Contrato_${cleanFolio}_$cleanClient.pdf';
  }

  Future<void> _shareContract() async {
    try {
      // Si aún no está guardado, guardarlo automáticamente al compartir
      if (!_isSaved) {
        await _saveContractToHistory(showSuccessSnackbar: false);
      }

      final pdfBytes = await ContractPdfService.generateContractPdf(widget.contract);
      final fileName = _buildFileName();

      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(pdfBytes);

      final clientTitle = widget.contract.businessName.isNotEmpty
          ? widget.contract.businessName
          : widget.contract.clientName;

      await Share.shareXFiles(
        [XFile(tempFile.path, name: fileName)],
        text: 'Contrato de Póliza de Control de Plagas - Folio ${widget.contract.folio}',
        subject: 'Póliza y Contrato: $clientTitle',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al compartir contrato: $e')),
        );
      }
    }
  }

  Future<void> _saveContractToHistory({bool showSuccessSnackbar = true}) async {
    if (_isSaved) {
      if (showSuccessSnackbar && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Este contrato ya se encuentra guardado en el historial.')),
        );
      }
      return;
    }

    setState(() => _isSaving = true);

    try {
      final pdfBytes = await ContractPdfService.generateContractPdf(widget.contract);
      final fileName = _buildFileName();

      final appDir = await getApplicationDocumentsDirectory();
      final savedContractsDir = Directory('${appDir.path}/contratos_guardados');
      if (!await savedContractsDir.exists()) {
        await savedContractsDir.create(recursive: true);
      }

      final savedFile = File('${savedContractsDir.path}/$fileName');
      await savedFile.writeAsBytes(pdfBytes);

      final contractWithFile = widget.contract.copyWith(pdfPath: savedFile.path);

      final prefs = await SharedPreferences.getInstance();
      final existingHistory = prefs.getString(_contractsHistoryKey);
      List<dynamic> list = [];
      if (existingHistory != null) {
        try {
          list = jsonDecode(existingHistory);
        } catch (_) {
          list = [];
        }
      }

      // Evitar duplicados por folio
      list.removeWhere((item) => item['folio'] == widget.contract.folio);
      list.insert(0, contractWithFile.toMap());

      await prefs.setString(_contractsHistoryKey, jsonEncode(list));

      // Sincronización automática en segundo plano con Google Drive (Offline-First)
      GoogleDriveSyncService().enqueueAndSync(
        clientName: widget.contract.businessName.isNotEmpty ? widget.contract.businessName : widget.contract.clientName,
        documentType: 'Contrato',
        folio: widget.contract.folio,
        localFilePath: savedFile.path,
        fileName: fileName,
      );

      // Actualizar contador del folio consecutivo
      try {
        final parts = widget.contract.folio.split('-');
        if (parts.length >= 4) {
          final num = int.tryParse(parts.last);
          if (num != null) {
            final current = prefs.getInt('ej_contracts_folio_counter') ?? 0;
            if (num > current) {
              await prefs.setInt('ej_contracts_folio_counter', num);
            }
          }
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _isSaved = true;
          _isSaving = false;
        });
        if (showSuccessSnackbar) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.green,
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Contrato guardado correctamente en tu historial.'),
                ],
              ),
            ),
          );
        }
        await _promptScheduleVisits();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    }
  }

  Future<void> _promptScheduleVisits() async {
    final contract = widget.contract;
    final totalVisits = contract.totalVisits > 0 ? contract.totalVisits : 12;

    final shouldSchedule = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.calendar_month, color: Color(0xFF0F2B48)),
            SizedBox(width: 8),
            Text('¿Agendar en Calendario?'),
          ],
        ),
        content: Text(
          '¿Deseas agendar de una vez las $totalVisits visitas de esta póliza en tu Calendario y Google Calendar?\n\n'
          'Si prefieres programarlas manualmente después según vayas coordinando con el cliente, elige "No".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No, programar manualmente'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F2B48),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, agendar visitas'),
          ),
        ],
      ),
    );

    if (shouldSchedule == true) {
      await _scheduleContractVisits(contract, totalVisits);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0F2B48),
            duration: const Duration(seconds: 4),
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('¡Se agendaron las $totalVisits visitas en tu Calendario y Google Calendar!'),
                ),
              ],
            ),
          ),
        );
      }
    }
  }

  Future<void> _scheduleContractVisits(ContractModel contract, int totalVisits) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final syncService = CalendarSyncService();
      final clientName = contract.businessName.isNotEmpty ? contract.businessName : contract.clientName;
      final phone = contract.phone.isNotEmpty ? contract.phone : contract.representativePhone;
      final address = contract.address;
      final startDate = contract.startDate;

      final List<ScheduledVisit> visits = [];
      for (int i = 0; i < totalVisits; i++) {
        final totalMonth = startDate.month + i;
        final year = startDate.year + ((totalMonth - 1) ~/ 12);
        final month = ((totalMonth - 1) % 12) + 1;
        final nextMonthFirst = (month == 12) ? DateTime(year + 1, 1, 1) : DateTime(year, month + 1, 1);
        final lastDay = nextMonthFirst.subtract(const Duration(days: 1)).day;
        final actualDay = startDate.day.clamp(1, lastDay);
        final visitDate = DateTime(year, month, actualDay);

        final visit = ScheduledVisit(
          id: '${DateTime.now().millisecondsSinceEpoch}_${i}_contract',
          visitNumber: i + 1,
          date: visitDate,
          time: '09:00 AM',
          serviceType: 'Servicio de Control de Plagas',
          status: 'Pendiente',
          notes: 'Póliza: ${contract.folio}',
          scheduleId: contract.folio,
          clientBusinessName: clientName,
          clientContactName: contract.representativeName.isNotEmpty ? contract.representativeName : contract.clientName,
          clientPhone: phone,
          clientAddress: address,
          isProspect: false,
          isInAgenda: true,
          reminderMinutes: const [10080, 2880, 120],
        );

        final evId = await syncService.syncVisitToGoogleCalendar(
          visit,
          clientNameOverride: clientName,
          phoneOverride: phone,
          addressOverride: address,
          notesOverride: 'Póliza/Contrato: ${contract.folio}',
          customReminderMinutes: const [10080, 2880, 120],
        );
        if (evId != null) {
          visit.calendarEventId = evId;
        }

        visits.add(visit);
      }

      final scheduleModel = ScheduleModel(
        id: 'schedule_contract_${DateTime.now().millisecondsSinceEpoch}',
        folio: contract.folio,
        createdAt: DateTime.now(),
        title: 'Póliza de Servicio ($totalVisits visitas)',
        clientBusinessName: clientName,
        clientContactName: contract.representativeName.isNotEmpty ? contract.representativeName : contract.clientName,
        clientPhone: phone,
        clientAddress: address,
        clientEmail: '',
        facilityType: contract.serviceType,
        isProspect: false,
        appointmentCategory: 'Poliza',
        recurrenceType: 'monthly_same_day',
        visitsPerMonth: 1,
        durationMonths: contract.durationMonths > 0 ? contract.durationMonths : 12,
        startDate: startDate,
        defaultTime: '09:00 AM',
        serviceType: 'Servicio de Control de Plagas',
        notes: 'Póliza: ${contract.folio}',
        isInAgenda: true,
        visits: visits,
      );

      final raw = prefs.getString('ej_schedules_history_list');
      List list = [];
      if (raw != null && raw.isNotEmpty) {
        try {
          list = jsonDecode(raw);
        } catch (_) {}
      }

      final entry = {
        'id': scheduleModel.id,
        'folio': scheduleModel.folio,
        'createdAt': scheduleModel.createdAt.toIso8601String(),
        'businessName': scheduleModel.clientBusinessName,
        'clientName': scheduleModel.clientContactName,
        'phone': scheduleModel.clientPhone,
        'clientAddress': scheduleModel.clientAddress,
        'recurrenceDescription': scheduleModel.recurrenceDescription,
        'totalVisits': totalVisits,
        'completedVisits': 0,
        'isProspect': false,
        'isInAgenda': true,
        'appointmentCategory': 'Poliza',
        'scheduleData': scheduleModel.toMap(),
      };

      list.insert(0, entry);
      await prefs.setString('ej_schedules_history_list', jsonEncode(list));
    } catch (e) {
      debugPrint('Error agendando visitas de contrato: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final fileName = _buildFileName();
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, _isSaved),
        ),
        title: Text(
          'Contrato: ${widget.contract.folio}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF0F2B48),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Compartir Contrato',
            onPressed: _shareContract,
          ),
        ],
      ),
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          Navigator.pop(context, _isSaved);
        },
        child: InteractiveViewer(
          minScale: 1.0,
          maxScale: 3.5,
          child: PdfPreview(
            build: (format) => ContractPdfService.generateContractPdf(widget.contract),
            allowPrinting: false,
            allowSharing: false,
            canChangeOrientation: false,
            canChangePageFormat: false,
            canDebug: false,
            maxPageWidth: screenWidth,
            pdfFileName: fileName,
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4, offset: const Offset(0, -2)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: const BorderSide(color: Color(0xFF0F2B48), width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.save_alt, color: Color(0xFF0F2B48)),
                label: Text(
                  _isSaved ? 'Guardado' : 'Guardar',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F2B48)),
                ),
                onPressed: _isSaving ? null : _saveContractToHistory,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F2B48),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.share),
                label: const Text(
                  'Enviar WhatsApp',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: _shareContract,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
