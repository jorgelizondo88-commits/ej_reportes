import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/schedule_model.dart';
import 'schedule_form_screen.dart';
import 'schedule_preview_screen.dart';

class ScheduleHistoryScreen extends StatefulWidget {
  const ScheduleHistoryScreen({super.key});

  @override
  State<ScheduleHistoryScreen> createState() => _ScheduleHistoryScreenState();
}

class _ScheduleHistoryScreenState extends State<ScheduleHistoryScreen> with SingleTickerProviderStateMixin {
  static const String _schedulesHistoryKey = 'ej_schedules_history_list';

  late TabController _tabController;
  List<Map<String, dynamic>> _schedules = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _agendaFilter = 'Todas'; // 'Todas', 'Pendientes', 'Realizadas', 'Este Mes'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSchedules();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSchedules() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_schedulesHistoryKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final List list = jsonDecode(raw);
        _schedules = list.map((item) => Map<String, dynamic>.from(item)).toList();
      } catch (_) {
        _schedules = [];
      }
    } else {
      _schedules = [];
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _saveSchedulesList() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_schedulesHistoryKey, jsonEncode(_schedules));
  }

  Future<void> _toggleVisitStatus(Map<String, dynamic> scheduleEntry, ScheduledVisit visit) async {
    setState(() {
      if (visit.status == 'Realizada') {
        visit.status = 'Pendiente';
        visit.completedDate = null;
      } else {
        visit.status = 'Realizada';
        visit.completedDate = DateTime.now();
      }

      // Actualizar conteos
      final scheduleModel = ScheduleModel.fromMap(scheduleEntry['scheduleData']);
      final vIdx = scheduleModel.visits.indexWhere((v) => v.id == visit.id);
      if (vIdx >= 0) {
        scheduleModel.visits[vIdx] = visit;
        scheduleEntry['scheduleData'] = scheduleModel.toMap();
        scheduleEntry['completedVisits'] = scheduleModel.completedVisits;
      }
    });

    await _saveSchedulesList();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            visit.status == 'Realizada'
                ? '¡Visita #${visit.visitNumber} marcada como REALIZADA!'
                : 'Visita #${visit.visitNumber} marcada como Pendiente.',
          ),
          backgroundColor: visit.status == 'Realizada' ? Colors.green.shade800 : Colors.blueGrey,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _deleteSchedule(int index) async {
    final schedule = _schedules[index];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar Cronograma?'),
        content: Text('Se eliminará la calendarización #${schedule['folio']} de ${schedule['businessName']}.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (schedule['filePath'] != null) {
        try {
          final file = File(schedule['filePath']);
          if (await file.exists()) await file.delete();
        } catch (_) {}
      }

      setState(() {
        _schedules.removeAt(index);
      });
      await _saveSchedulesList();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cronograma eliminado del historial.')),
        );
      }
    }
  }

  void _openSchedulePdf(Map<String, dynamic> entry) {
    if (entry['scheduleData'] != null) {
      final model = ScheduleModel.fromMap(entry['scheduleData']);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => SchedulePreviewScreen(schedule: model)),
      );
    } else if (entry['filePath'] != null && File(entry['filePath']).existsSync()) {
      Share.shareXFiles([XFile(entry['filePath'])]);
    }
  }

  void _manageVisitsBottomSheet(Map<String, dynamic> entry) {
    final model = ScheduleModel.fromMap(entry['scheduleData']);
    final fullFormat = DateFormat('EEEE, dd \'de\' MMMM \'de\' yyyy', 'es_MX');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Visitas de #${entry['folio']}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F2B48))),
                        Text('${entry['businessName']} • ${model.completedVisits} de ${model.totalVisits} realizadas',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const Divider(),
              Expanded(
                child: ListView.separated(
                  itemCount: model.visits.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, idx) {
                    final v = model.visits[idx];
                    final isDone = v.status == 'Realizada';

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      leading: CircleAvatar(
                        backgroundColor: isDone ? Colors.green.shade100 : Colors.grey.shade200,
                        child: Icon(
                          isDone ? Icons.check_circle : Icons.schedule,
                          color: isDone ? Colors.green.shade800 : Colors.grey.shade600,
                        ),
                      ),
                      title: Text(
                        'Visita #${v.visitNumber} • ${fullFormat.format(v.date)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDone ? Colors.green.shade900 : Colors.black87,
                        ),
                      ),
                      subtitle: Text('${v.time} • ${v.serviceType}'),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDone ? Colors.green.shade700 : const Color(0xFF0F2B48),
                          foregroundColor: Colors.white,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        ),
                        child: Text(isDone ? 'Realizada ✓' : 'Marcar'),
                        onPressed: () async {
                          await _toggleVisitStatus(entry, v);
                          setModalState(() {});
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredSchedules = _schedules.where((s) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final folio = (s['folio'] ?? '').toString().toLowerCase();
      final bName = (s['businessName'] ?? '').toString().toLowerCase();
      final cName = (s['clientName'] ?? '').toString().toLowerCase();
      return folio.contains(q) || bName.contains(q) || cName.contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendarización y Agenda', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0F2B48),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amberAccent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.description_outlined), text: 'Pólizas y Contratos'),
            Tab(icon: Icon(Icons.calendar_today_outlined), text: 'Agenda de Visitas'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0F2B48),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nueva Calendarización'),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ScheduleFormScreen()),
          );
          _loadSchedules();
        },
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // TAB 1: PÓLIZAS Y CRONOGRAMAS
                _buildSchedulesTab(filteredSchedules),

                // TAB 2: AGENDA DE VISITAS
                _buildAgendaTab(),
              ],
            ),
    );
  }

  Widget _buildSchedulesTab(List<Map<String, dynamic>> schedules) {
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Column(
      children: [
        // Barra de búsqueda
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Buscar por cliente o folio (#EJ-CAL)...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.grey.shade100,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
            onChanged: (val) => setState(() => _searchQuery = val.trim()),
          ),
        ),

        Expanded(
          child: schedules.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 56, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        _searchQuery.isEmpty
                            ? 'Aún no tienes calendarizaciones guardadas.'
                            : 'No se encontraron resultados para "$_searchQuery".',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  itemCount: schedules.length,
                  itemBuilder: (context, idx) {
                    final item = schedules[idx];
                    final total = item['totalVisits'] ?? 0;
                    final completed = item['completedVisits'] ?? 0;
                    final progress = total > 0 ? (completed / total).clamp(0.0, 1.0) : 0.0;
                    final isComplete = total > 0 && completed == total;
                    final created = DateTime.tryParse(item['createdAt'] ?? '') ?? DateTime.now();

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
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F2B48).withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '#${item['folio']}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F2B48)),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isComplete ? Colors.green.shade50 : Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: isComplete ? Colors.green.shade300 : Colors.blue.shade300),
                                  ),
                                  child: Text(
                                    isComplete ? 'Completado ✓' : '$completed de $total visitas',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isComplete ? Colors.green.shade800 : Colors.blue.shade800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item['businessName']?.isNotEmpty == true ? item['businessName'] : (item['clientName'] ?? 'Cliente'),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F2B48)),
                            ),
                            if (item['clientName']?.isNotEmpty == true && item['clientName'] != item['businessName']) ...[
                              const SizedBox(height: 2),
                              Text('Contacto: ${item['clientName']}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                            ],
                            const SizedBox(height: 4),
                            Text(
                              'Regla: ${item['recurrenceDescription'] ?? 'Mensual'}',
                              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade800, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 8),
                            // Barra de progreso
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 6,
                                backgroundColor: Colors.grey.shade200,
                                color: isComplete ? Colors.green : const Color(0xFF0F2B48),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Emisión: ${dateFormat.format(created)}',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.list_alt, size: 20, color: Color(0xFF0F2B48)),
                                      tooltip: 'Gestionar Visitas',
                                      onPressed: () => _manageVisitsBottomSheet(item),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 20, color: Color(0xFF0F2B48)),
                                      tooltip: 'Ver PDF',
                                      onPressed: () => _openSchedulePdf(item),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                                      tooltip: 'Eliminar',
                                      onPressed: () => _deleteSchedule(idx),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAgendaTab() {
    // Recopilar todas las visitas de todas las calendarizaciones
    final List<Map<String, dynamic>> allVisits = [];
    final now = DateTime.now();

    for (var s in _schedules) {
      if (s['scheduleData'] != null) {
        final model = ScheduleModel.fromMap(s['scheduleData']);
        for (var v in model.visits) {
          allVisits.add({
            'schedule': s,
            'visit': v,
            'date': v.date,
          });
        }
      }
    }

    // Ordenar cronológicamente
    allVisits.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));

    // Filtrar
    final filtered = allVisits.where((item) {
      final v = item['visit'] as ScheduledVisit;
      final d = item['date'] as DateTime;
      if (_agendaFilter == 'Pendientes') return v.status == 'Pendiente';
      if (_agendaFilter == 'Realizadas') return v.status == 'Realizada';
      if (_agendaFilter == 'Este Mes') return d.month == now.month && d.year == now.year;
      return true;
    }).toList();

    final fullFormat = DateFormat('EEEE, dd \'de\' MMMM \'de\' yyyy', 'es_MX');

    return Column(
      children: [
        // Filtros rápidos
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: ['Todas', 'Este Mes', 'Pendientes', 'Realizadas'].map((filter) {
              final isSel = _agendaFilter == filter;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(filter, style: TextStyle(color: isSel ? Colors.white : Colors.black87, fontSize: 12)),
                  selected: isSel,
                  selectedColor: const Color(0xFF0F2B48),
                  checkmarkColor: Colors.white,
                  onSelected: (_) => setState(() => _agendaFilter = filter),
                ),
              );
            }).toList(),
          ),
        ),

        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_available, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 8),
                      Text('No hay visitas con el filtro "$_agendaFilter".', style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  itemCount: filtered.length,
                  itemBuilder: (context, idx) {
                    final item = filtered[idx];
                    final s = item['schedule'] as Map<String, dynamic>;
                    final v = item['visit'] as ScheduledVisit;
                    final isDone = v.status == 'Realizada';

                    return Card(
                      elevation: 1,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isDone ? Colors.green.shade100 : const Color(0xFF0F2B48).withValues(alpha: 0.1),
                          child: Icon(
                            isDone ? Icons.check : Icons.schedule,
                            color: isDone ? Colors.green.shade800 : const Color(0xFF0F2B48),
                          ),
                        ),
                        title: Text(
                          fullFormat.format(v.date),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isDone ? Colors.green.shade900 : Colors.black87,
                            decoration: isDone ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 2),
                            Text('${s['businessName']} • ${v.time}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            Text('${s['clientAddress'] ?? ''}', style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                          ],
                        ),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDone ? Colors.green.shade700 : const Color(0xFF0F2B48),
                            foregroundColor: Colors.white,
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          ),
                          child: Text(isDone ? 'Realizada ✓' : 'Completar'),
                          onPressed: () => _toggleVisitStatus(s, v),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
