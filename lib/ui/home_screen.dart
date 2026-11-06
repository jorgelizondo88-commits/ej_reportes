import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/client_model.dart';
import '../models/report_model.dart';
import '../models/trap_monitoring_model.dart';
import '../services/client_service.dart';
import 'form/chemical_step.dart';
import 'form/general_info_step.dart';
import 'form/photos_step.dart';
import 'form/signature_step.dart';
import 'form/traps_step.dart';
import 'history/report_history_screen.dart';
import 'preview/pdf_preview_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late TabController _tabController;

  static const String _draftKey = 'ej_active_report_draft';
  static const String _folioCounterKey = 'ej_consecutive_folio_counter';

  int _formResetVersion = 0;

  late GeneralInfoData _generalData;
  List<TrapMonitoring> _traps = [];
  List<ChemicalProduct> _chemicals = [];
  List<PhotoEvidence> _evidences = [];
  Uint8List? _technicianSignature;
  Uint8List? _clientSignature;
  String _receivedByName = '';

  @override
  void initState() {
    super.initState();
    _resetToNewReportState();
    _initTabController();
    _initAppData();
  }

  // Generador del folio automático EJ-MMYY-XXXX
  String _formatFolio(int counter, DateTime date) {
    final monthStr = date.month.toString().padLeft(2, '0');
    final yearStr = (date.year % 100).toString().padLeft(2, '0');
    final sequenceStr = counter.toString().padLeft(4, '0');
    return 'EJ-$monthStr$yearStr-$sequenceStr';
  }

  void _resetToNewReportState({String? folio}) {
    final now = DateTime.now();
    _generalData = GeneralInfoData(
      reportFolio: folio ?? _formatFolio(1, now),
      serviceDate: now,
      serviceTimeStart: const TimeOfDay(hour: 9, minute: 0),
      serviceTimeEnd: const TimeOfDay(hour: 10, minute: 30),
      technicianName: '',
      clientName: '',
      businessName: '',
      clientAddress: '',
      clientPhone: '',
      clientEmail: '',
      facilityType: 'Comercial / Restaurante',
      hasTraps: true,
      targetedPests: [],
      inspectionFindings: '',
      recommendations: '',
      warranties: '',
      activeClientId: null,
    );
    _traps = [];
    _chemicals = [];
    _evidences = [];
    _clientSignature = null;
    _receivedByName = '';
  }

  Future<int> _calculateNextReportNumber() async {
    final prefs = await SharedPreferences.getInstance();
    final rawHistory = prefs.getString('ej_reports_history_list');
    int maxNumber = 0;
    if (rawHistory != null && rawHistory.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(rawHistory);
        for (final item in list) {
          final folioStr = (item['folio'] ?? item['reportFolio'] ?? '').toString();
          final match = RegExp(r'(\d+)$').firstMatch(folioStr);
          if (match != null) {
            final num = int.tryParse(match.group(1)!);
            if (num != null && num > maxNumber) {
              maxNumber = num;
            }
          }
        }
      } catch (_) {}
    }
    final counterFromPrefs = prefs.getInt(_folioCounterKey) ?? 0;
    final nextNumber = (maxNumber > counterFromPrefs ? maxNumber : counterFromPrefs) + 1;
    return nextNumber;
  }

  Future<void> _initAppData() async {
    final prefs = await SharedPreferences.getInstance();
    final rawDraft = prefs.getString(_draftKey);

    if (rawDraft != null && rawDraft.isNotEmpty) {
      await _restoreDraft();
    } else {
      final nextNumber = await _calculateNextReportNumber();
      setState(() {
        _resetToNewReportState(folio: _formatFolio(nextNumber, DateTime.now()));
      });
    }
  }

  void _initTabController() {
    final tabCount = _generalData.hasTraps ? 5 : 4;
    _tabController = TabController(length: tabCount, vsync: this);
  }

  // --- AUTOGUARDADO DE BORRADOR ---
  Future<void> _saveDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final draftMap = {
      'reportFolio': _generalData.reportFolio,
      'serviceDate': _generalData.serviceDate.toIso8601String(),
      'startHour': _generalData.serviceTimeStart.hour,
      'startMinute': _generalData.serviceTimeStart.minute,
      'endHour': _generalData.serviceTimeEnd.hour,
      'endMinute': _generalData.serviceTimeEnd.minute,
      'technicianName': _generalData.technicianName,
      'clientName': _generalData.clientName,
      'businessName': _generalData.businessName,
      'clientAddress': _generalData.clientAddress,
      'clientPhone': _generalData.clientPhone,
      'clientEmail': _generalData.clientEmail,
      'facilityType': _generalData.facilityType,
      'hasTraps': _generalData.hasTraps,
      'targetedPests': _generalData.targetedPests,
      'inspectionFindings': _generalData.inspectionFindings,
      'recommendations': _generalData.recommendations,
      'warranties': '',
      'activeClientId': _generalData.activeClientId,
      'receivedByName': _receivedByName,
      'traps': _traps.map((t) => t.toMap()).toList(),
      'chemicals': _chemicals.map((c) => c.toMap()).toList(),
      'evidences': _evidences.map((e) => e.toMap()).toList(),
      'clientSignature': _clientSignature != null ? base64Encode(_clientSignature!) : null,
    };
    await prefs.setString(_draftKey, jsonEncode(draftMap));
  }

  Future<void> _restoreDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_draftKey);
    if (raw == null || raw.isEmpty) return;

    try {
      final map = jsonDecode(raw);
      setState(() {
        _generalData = GeneralInfoData(
          reportFolio: map['reportFolio'] ?? _generalData.reportFolio,
          serviceDate: DateTime.tryParse(map['serviceDate'] ?? '') ?? DateTime.now(),
          serviceTimeStart: TimeOfDay(hour: map['startHour'] ?? 9, minute: map['startMinute'] ?? 0),
          serviceTimeEnd: TimeOfDay(hour: map['endHour'] ?? 10, minute: map['endMinute'] ?? 30),
          technicianName: map['technicianName'] ?? '',
          clientName: map['clientName'] ?? '',
          businessName: map['businessName'] ?? '',
          clientAddress: map['clientAddress'] ?? '',
          clientPhone: map['clientPhone'] ?? '',
          clientEmail: map['clientEmail'] ?? '',
          facilityType: map['facilityType'] ?? 'Comercial / Restaurante',
          hasTraps: map['hasTraps'] ?? true,
          targetedPests: List<String>.from(map['targetedPests'] ?? []),
          inspectionFindings: map['inspectionFindings'] ?? '',
          recommendations: map['recommendations'] ?? '',
          warranties: '',
          activeClientId: map['activeClientId'],
        );

        _receivedByName = map['receivedByName'] ?? '';

        if (map['traps'] != null) {
          _traps = (map['traps'] as List).map((t) => TrapMonitoring.fromMap(t)).toList();
        }
        if (map['chemicals'] != null) {
          _chemicals = (map['chemicals'] as List).map((c) => ChemicalProduct.fromMap(c)).toList();
        }
        if (map['evidences'] != null) {
          _evidences = (map['evidences'] as List).map((e) => PhotoEvidence.fromMap(e)).toList();
        }
        if (map['clientSignature'] != null) {
          _clientSignature = base64Decode(map['clientSignature']);
        }

        _tabController.dispose();
        _initTabController();
      });
    } catch (_) {}
  }

  Future<void> _clearDraftAndNewReport() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Iniciar Nuevo Reporte?'),
        content: const Text(
          'Esto limpiará todos los campos para comenzar un servicio en blanco y generará el siguiente folio consecutivo.\n\n(Los clientes guardados y el catálogo de químicos permanecerán intactos).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Limpiar Todo'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftKey);

      final nextCounter = await _calculateNextReportNumber();
      await prefs.setInt(_folioCounterKey, nextCounter);

      final nextFolio = _formatFolio(nextCounter, DateTime.now());

      setState(() {
        _resetToNewReportState(folio: nextFolio);
        _formResetVersion++;
        _tabController.dispose();
        _initTabController();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Formulario en blanco. Nuevo Folio: $nextFolio'),
            backgroundColor: const Color(0xFF0F2B48),
          ),
        );
      }
    }
  }

  void _updateGeneralData(GeneralInfoData updated) {
    final hadTraps = _generalData.hasTraps;
    setState(() {
      _generalData = updated;
      if (hadTraps != updated.hasTraps) {
        _tabController.dispose();
        _initTabController();
      }
    });
    _saveDraft();
  }

  Future<void> _syncTrapsToClient() async {
    if (_generalData.activeClientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Guarda primero el cliente en la pestaña General.')),
      );
      return;
    }

    final clientService = ClientService();
    final clients = await clientService.getSavedClients();
    final idx = clients.indexWhere((c) => c.id == _generalData.activeClientId);

    if (idx >= 0) {
      final updatedTraps = _traps.map((t) => ClientTrapTemplate(
        id: t.id,
        trapType: t.trapType,
        location: t.location,
      )).toList();

      final updatedClient = ClientModel(
        id: clients[idx].id,
        businessName: clients[idx].businessName,
        contactName: clients[idx].contactName,
        address: clients[idx].address,
        phone: clients[idx].phone,
        email: clients[idx].email,
        facilityType: clients[idx].facilityType,
        hasTraps: _generalData.hasTraps,
        defaultTraps: updatedTraps,
      );

      await clientService.saveClient(updatedClient);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Inventario permanente del cliente actualizado con ${_traps.length} trampas.'),
            backgroundColor: Colors.green.shade800,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- VALIDACIÓN DE CAMPOS OBLIGATORIOS ---
  void _navigateToPreview() {
    List<String> missingFields = [];

    // 1. Pestaña General
    if (_generalData.reportFolio.trim().isEmpty) {
      missingFields.add('Número de Folio');
    }
    if (_generalData.businessName.trim().isEmpty) {
      missingFields.add('Empresa / Razón Social');
    }
    if (_generalData.clientName.trim().isEmpty) {
      missingFields.add('Nombre del Encargado / Contacto');
    }
    if (_generalData.clientAddress.trim().isEmpty) {
      missingFields.add('Dirección del Cliente');
    }
    if (_generalData.clientPhone.trim().isEmpty) {
      missingFields.add('Teléfono del Cliente');
    }
    if (_generalData.targetedPests.isEmpty) {
      missingFields.add('Al menos una Plaga Objetivo seleccionada');
    }
    if (_generalData.inspectionFindings.trim().isEmpty) {
      missingFields.add('Hallazgos de la inspección inicial');
    }
    if (_generalData.recommendations.trim().isEmpty) {
      missingFields.add('Recomendaciones físicas / higiénicas');
    }

    // 2. Pestaña Trampas (si maneja)
    if (_generalData.hasTraps && _traps.isEmpty) {
      missingFields.add('Al menos una trampa o cebadero registrado');
    }

    // 3. Pestaña Químicos
    if (_chemicals.isEmpty) {
      missingFields.add('Al menos un Producto Químico seleccionado');
    }

    // 4. Pestaña Fotos
    if (_evidences.isEmpty) {
      missingFields.add('Al menos una Evidencia Fotográfica');
    }

    // 5. Pestaña Firmas
    if (_generalData.technicianName.trim().isEmpty) {
      missingFields.add('Nombre del Técnico Especialista');
    }
    if (_technicianSignature == null) {
      missingFields.add('Firma del Técnico Especialista');
    }
    if (_receivedByName.trim().isEmpty) {
      missingFields.add('Nombre de Quien Recibe el servicio');
    }
    if (_clientSignature == null) {
      missingFields.add('Firma de Quien Recibe (Conformidad)');
    }

    if (missingFields.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 8),
              Text('Faltan datos obligatorios', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Para generar el reporte formal en PDF, completa los siguientes campos pendientes:',
                  style: TextStyle(fontSize: 13, color: Colors.black87),
                ),
                const SizedBox(height: 12),
                ...missingFields.map(
                      (field) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
                        Expanded(
                          child: Text(
                            field,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.redAccent),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F2B48),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('Entendido / Completar'),
            ),
          ],
        ),
      );
      return;
    }

    final report = ServiceReport(
      reportFolio: _generalData.reportFolio.trim(),
      serviceDate: _generalData.serviceDate,
      serviceTimeStart: _generalData.serviceTimeStart.format(context),
      serviceTimeEnd: _generalData.serviceTimeEnd.format(context),
      technicianName: _generalData.technicianName.trim(),
      clientName: _generalData.clientName.trim(),
      businessName: _generalData.businessName.trim(),
      clientAddress: _generalData.clientAddress.trim(),
      clientPhone: _generalData.clientPhone.trim(),
      clientEmail: _generalData.clientEmail.trim(),
      facilityType: _generalData.facilityType,
      hasTraps: _generalData.hasTraps,
      targetedPests: _generalData.targetedPests,
      inspectionFindings: _generalData.inspectionFindings.trim(),
      chemicals: _chemicals,
      traps: _generalData.hasTraps ? _traps : [],
      photoEvidences: _evidences,
      recommendations: _generalData.recommendations.trim(),
      warranties: '',
      technicianSignature: _technicianSignature,
      clientSignature: _clientSignature,
      receivedByName: _receivedByName.trim(),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PdfPreviewScreen(report: report),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EJ Reportes', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0F2B48),
        foregroundColor: Colors.white,
        actions: [
          // Botón de Historial de Reportes
          IconButton(
            icon: const Icon(Icons.folder_shared_outlined),
            tooltip: 'Historial de Reportes',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ReportHistoryScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.cleaning_services),
            tooltip: 'Borrar todo / Nuevo Reporte',
            onPressed: _clearDraftAndNewReport,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.amberAccent,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(icon: const Icon(Icons.info_outline), text: 'General (${_generalData.reportFolio})'),
            if (_generalData.hasTraps)
              Tab(icon: const Icon(Icons.inventory_2_outlined), text: 'Trampas (${_traps.length})'),
            Tab(icon: const Icon(Icons.science_outlined), text: 'Químicos (${_chemicals.length})'),
            Tab(icon: const Icon(Icons.photo_camera_outlined), text: 'Fotos (${_evidences.length})'),
            const Tab(icon: Icon(Icons.draw_outlined), text: 'Firmas'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: GeneralInfoStep(
              key: ValueKey('general_info_$_formResetVersion'),
              data: _generalData,
              onChanged: _updateGeneralData,
              onTrapsPreloaded: (preloaded) {
                setState(() => _traps = preloaded);
                _saveDraft();
              },
            ),
          ),
          if (_generalData.hasTraps)
            Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    if (_generalData.activeClientId != null) ...[
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          icon: const Icon(Icons.sync, size: 16),
                          label: const Text('Fijar esta lista como inventario del cliente'),
                          onPressed: _syncTrapsToClient,
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    TrapsStep(
                      traps: _traps,
                      onTrapsChanged: (updated) {
                        setState(() => _traps = updated);
                        _saveDraft();
                      },
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: ChemicalStep(
              selectedChemicals: _chemicals,
              onChemicalsChanged: (updated) {
                setState(() => _chemicals = updated);
                _saveDraft();
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: PhotosStep(
              evidences: _evidences,
              onEvidencesChanged: (updated) {
                setState(() => _evidences = updated);
                _saveDraft();
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SignatureStep(
              key: ValueKey('signature_step_$_formResetVersion'),
              technicianName: _generalData.technicianName,
              receivedByName: _receivedByName,
              currentTechSignature: _technicianSignature,
              currentClientSignature: _clientSignature,
              onNamesChanged: (tech, receiver) {
                setState(() {
                  _generalData.technicianName = tech;
                  _receivedByName = receiver;
                });
                _saveDraft();
              },
              onSignaturesUpdated: (techSign, clientSign) {
                _technicianSignature = techSign;
                _clientSignature = clientSign;
                _saveDraft();
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                offset: const Offset(0, -2),
                blurRadius: 6,
              ),
            ],
          ),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F2B48),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text(
              'Generar y Ver Reporte PDF',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            onPressed: _navigateToPreview,
          ),
        ),
      ),
    );
  }
}