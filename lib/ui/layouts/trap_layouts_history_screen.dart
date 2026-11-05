import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/trap_layout_model.dart';
import '../../services/trap_layout_pdf_service.dart';
import '../../services/trap_layout_service.dart';
import 'trap_layout_canvas_screen.dart';

class TrapLayoutsHistoryScreen extends StatefulWidget {
  const TrapLayoutsHistoryScreen({super.key});

  @override
  State<TrapLayoutsHistoryScreen> createState() => _TrapLayoutsHistoryScreenState();
}

class _TrapLayoutsHistoryScreenState extends State<TrapLayoutsHistoryScreen> {
  final TrapLayoutService _layoutService = TrapLayoutService();
  List<TrapLayoutModel> _layouts = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadLayouts();
  }

  Future<void> _loadLayouts() async {
    setState(() => _isLoading = true);
    final list = await _layoutService.getAllLayouts();
    if (mounted) {
      setState(() {
        _layouts = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteLayout(TrapLayoutModel layout) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar Plano?'),
        content: Text('Se eliminará permanentemente el plano "${layout.folio}" de "${layout.clientBusinessName}".'),
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
      await _layoutService.deleteLayout(layout.id);
      _loadLayouts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Plano eliminado correctamente.')),
        );
      }
    }
  }

  Future<void> _shareLayoutPdf(TrapLayoutModel layout) async {
    try {
      final pdfBytes = await TrapLayoutPdfService.generateLayoutPdf(layout);
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/Plano_Layout_${layout.folio.replaceAll("#", "")}.pdf');
      await file.writeAsBytes(pdfBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Plano Oficial de Estaciones de Control EJ Exterminadores: ${layout.clientBusinessName} (${layout.facilityName})',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al compartir PDF: $e')),
        );
      }
    }
  }

  void _previewLayoutPdf(TrapLayoutModel layout) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text('Plano Oficial ${layout.folio}'),
            backgroundColor: const Color(0xFF0F2B48),
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.share),
                tooltip: 'Compartir PDF',
                onPressed: () => _shareLayoutPdf(layout),
              ),
            ],
          ),
          body: PdfPreview(
            build: (format) => TrapLayoutPdfService.generateLayoutPdf(layout),
            allowPrinting: true,
            allowSharing: true,
            canChangeOrientation: false,
            canChangePageFormat: false,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _layouts.where((l) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return l.clientBusinessName.toLowerCase().contains(q) ||
          l.facilityName.toLowerCase().contains(q) ||
          l.folio.toLowerCase().contains(q) ||
          l.clientAddress.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Planos y Layouts de Trampas', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0F2B48),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar lista',
            onPressed: _loadLayouts,
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de búsqueda
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar por cliente, planta o folio (#EJ-LAY)...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
            ),
          ),

          // Lista de planos
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.architecture, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isEmpty
                                  ? 'Aún no tienes planos guardados.'
                                  : 'No se encontraron planos para "$_searchQuery".',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F2B48),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                              ),
                              icon: const Icon(Icons.add_circle_outline),
                              label: const Text('Crear Primer Plano'),
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const TrapLayoutCanvasScreen()),
                                );
                                _loadLayouts();
                              },
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(14, 6, 14, 90),
                        itemCount: filtered.length,
                        itemBuilder: (context, idx) {
                          final item = filtered[idx];
                          final hasImg = item.backgroundImagePath != null && File(item.backgroundImagePath!).existsSync();
                          final dateStr = DateFormat('dd/MM/yyyy').format(item.updatedAt);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Encabezado de la tarjeta
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Miniatura del plano
                                      Container(
                                        width: 54,
                                        height: 54,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0F2B48).withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.grey.shade300),
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: hasImg
                                            ? Image.file(File(item.backgroundImagePath!), fit: BoxFit.cover)
                                            : const Icon(Icons.architecture, color: Color(0xFF0F2B48), size: 28),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF0F2B48),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    item.folio,
                                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                                  ),
                                                ),
                                                Text(dateStr, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              item.clientBusinessName.isNotEmpty ? item.clientBusinessName : 'Cliente sin nombre',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F2B48)),
                                            ),
                                            Text(
                                              item.facilityName,
                                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),

                                  if (item.clientAddress.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Icon(Icons.location_on, size: 14, color: Colors.grey.shade500),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            item.clientAddress,
                                            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],

                                  const SizedBox(height: 8),
                                  const Divider(height: 1),
                                  const SizedBox(height: 8),

                                  // Resumen de trampas instaladas
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      _badge('${item.totalPins} Dispositivos', const Color(0xFF0F2B48)),
                                      if (item.totalExteriorBaitStations > 0)
                                        _badge('${item.totalExteriorBaitStations} Cebaderos Ext.', const Color(0xFF15803D)),
                                      if (item.totalMechanicalTraps > 0)
                                        _badge('${item.totalMechanicalTraps} Mecánicas Int.', const Color(0xFF1D4ED8)),
                                      if (item.totalGlueTraps > 0)
                                        _badge('${item.totalGlueTraps} Gomas', const Color(0xFFD97706)),
                                      if (item.totalUvLamps > 0)
                                        _badge('${item.totalUvLamps} Luz UV', const Color(0xFF7E22CE)),
                                    ],
                                  ),

                                  const SizedBox(height: 10),

                                  // Botones de acción
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            side: const BorderSide(color: Color(0xFF0F2B48)),
                                            padding: const EdgeInsets.symmetric(vertical: 8),
                                            visualDensity: VisualDensity.compact,
                                          ),
                                          icon: const Icon(Icons.edit, size: 16, color: Color(0xFF0F2B48)),
                                          label: const Text('Editar Plano', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F2B48))),
                                          onPressed: () async {
                                            await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => TrapLayoutCanvasScreen(initialLayout: item),
                                              ),
                                            );
                                            _loadLayouts();
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF0F2B48),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 8),
                                            visualDensity: VisualDensity.compact,
                                          ),
                                          icon: const Icon(Icons.picture_as_pdf, size: 16),
                                          label: const Text('Ver / PDF', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                          onPressed: () => _previewLayoutPdf(item),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        icon: const Icon(Icons.share, size: 19, color: Color(0xFF0F2B48)),
                                        tooltip: 'Compartir PDF',
                                        onPressed: () => _shareLayoutPdf(item),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 19, color: Colors.redAccent),
                                        tooltip: 'Eliminar plano',
                                        onPressed: () => _deleteLayout(item),
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
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0F2B48),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Nuevo Plano / Layout', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const TrapLayoutCanvasScreen()),
          );
          _loadLayouts();
        },
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.6),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}
