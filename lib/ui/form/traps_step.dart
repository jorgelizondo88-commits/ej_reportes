import 'package:flutter/material.dart';
import '../../models/trap_monitoring_model.dart';

class TrapsStep extends StatefulWidget {
  final List<TrapMonitoring> traps;
  final Function(List<TrapMonitoring>) onTrapsChanged;

  const TrapsStep({
    super.key,
    required this.traps,
    required this.onTrapsChanged,
  });

  @override
  State<TrapsStep> createState() => _TrapsStepState();
}

class _TrapsStepState extends State<TrapsStep> {
  final List<String> _trapTypes = [
    'Estación de cebado (Roedor)',
    'Trampa mecánica / Goma',
    'Trampa de golpe',
    'Lámpara de luz UV / Placa adhesiva',
  ];

  final List<String> _statuses = [
    'Sin actividad',
    'Con actividad',
    'Captura detectada',
    'Cebo degradado / Reemplazado',
    'Dañada / Obstruida',
  ];

  void _showAddTrapDialog({TrapMonitoring? existingTrap, int? index}) {
    final idController = TextEditingController(
      text: existingTrap?.id ?? 'T-${(widget.traps.length + 1).toString().padLeft(2, '0')}',
    );
    final locationController = TextEditingController(text: existingTrap?.location ?? '');
    final countController = TextEditingController(
      text: existingTrap != null && existingTrap.captureCount > 0
          ? existingTrap.captureCount.toString()
          : '0',
    );
    final obsController = TextEditingController(text: existingTrap?.observations ?? '');

    String selectedType = existingTrap?.trapType ?? _trapTypes.first;
    String selectedStatus = existingTrap?.status ?? _statuses.first;
    double consumptionPercent = (existingTrap?.consumptionPercentage ?? 0).toDouble();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isBaitStation = selectedType.contains('cebado');
            final isCapture = selectedStatus == 'Captura detectada' || !isBaitStation;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      existingTrap == null ? 'Nueva Trampa / Dispositivo' : 'Editar Dispositivo',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: idController,
                            decoration: const InputDecoration(
                              labelText: 'ID / Folio',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String>(
                            value: selectedType,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Tipo',
                              border: OutlineInputBorder(),
                            ),
                            items: _trapTypes.map((type) {
                              return DropdownMenuItem(
                                value: type,
                                child: Text(type, overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setModalState(() => selectedType = val);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: locationController,
                      decoration: const InputDecoration(
                        labelText: 'Ubicación específica',
                        hintText: 'Ej. Andén 2, Bodega Este, Cocina',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.pin_drop_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Slider de consumo de cebo (0% a 100% en saltos de 10)
                    if (isBaitStation) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.blueGrey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Consumo de Cebo:',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F2B48),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${consumptionPercent.toInt()}%',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Slider(
                              value: consumptionPercent,
                              min: 0,
                              max: 100,
                              divisions: 10,
                              activeColor: const Color(0xFF0F2B48),
                              label: '${consumptionPercent.toInt()}%',
                              onChanged: (val) {
                                setModalState(() {
                                  consumptionPercent = val;
                                  if (val > 0 && selectedStatus == 'Sin actividad') {
                                    selectedStatus = 'Con actividad';
                                  }
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    DropdownButtonFormField<String>(
                      value: selectedStatus,
                      decoration: const InputDecoration(
                        labelText: 'Estado / Condición',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.analytics_outlined),
                      ),
                      items: _statuses.map((status) {
                        return DropdownMenuItem(value: status, child: Text(status));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedStatus = val);
                      },
                    ),

                    if (isCapture) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: countController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Cantidad de Capturas (Goma / Mecánica)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.pest_control_outlined),
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),
                    TextField(
                      controller: obsController,
                      decoration: const InputDecoration(
                        labelText: 'Observaciones (ej. Limpieza, cambio de placa)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.notes_outlined),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F2B48),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () {
                        if (idController.text.trim().isEmpty) return;

                        final newTrap = TrapMonitoring(
                          id: idController.text.trim(),
                          location: locationController.text.trim().isNotEmpty
                              ? locationController.text.trim()
                              : 'Área General',
                          trapType: selectedType,
                          consumptionPercentage: consumptionPercent.toInt(),
                          status: selectedStatus,
                          captureCount: int.tryParse(countController.text.trim()) ?? 0,
                          observations: obsController.text.trim(),
                        );

                        List<TrapMonitoring> updatedList = List.from(widget.traps);
                        if (index != null) {
                          updatedList[index] = newTrap;
                        } else {
                          updatedList.add(newTrap);
                        }

                        widget.onTrapsChanged(updatedList);
                        Navigator.pop(context);
                      },
                      child: Text(existingTrap == null ? 'Registrar Trampa' : 'Guardar Cambios'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _removeTrap(int index) {
    List<TrapMonitoring> updatedList = List.from(widget.traps);
    updatedList.removeAt(index);
    widget.onTrapsChanged(updatedList);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Dispositivos Registrados (${widget.traps.length})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0F2B48),
              ),
              onPressed: () => _showAddTrapDialog(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Añadir Trampa'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (widget.traps.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: const Column(
              children: [
                Icon(Icons.inventory_2_outlined, size: 40, color: Colors.grey),
                SizedBox(height: 8),
                Text(
                  'No hay trampas registradas para este servicio.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.traps.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final trap = widget.traps[index];
              return Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF1E6091).withValues(alpha: 0.15),
                    child: Text(
                      trap.id,
                      style: const TextStyle(
                        color: Color(0xFF0F2B48),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  title: Text(
                    '${trap.trapType} - ${trap.location}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: Text(
                    'Consumo: ${trap.consumptionPercentage}% | Estado: ${trap.status}'
                        '${trap.captureCount > 0 ? " (${trap.captureCount} capturas)" : ""}\n'
                        '${trap.observations.isNotEmpty ? "Nota: ${trap.observations}" : ""}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        onPressed: () => _showAddTrapDialog(existingTrap: trap, index: index),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                        onPressed: () => _removeTrap(index),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}