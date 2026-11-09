import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/client_model.dart';
import '../../models/trap_layout_model.dart';
import '../../services/client_service.dart';
import '../../services/trap_layout_pdf_service.dart';
import '../../services/trap_layout_service.dart';
import '../../services/google_drive_sync_service.dart';

class TrapLayoutCanvasScreen extends StatefulWidget {
  final TrapLayoutModel? initialLayout;

  const TrapLayoutCanvasScreen({super.key, this.initialLayout});

  @override
  State<TrapLayoutCanvasScreen> createState() => _TrapLayoutCanvasScreenState();
}

enum CanvasInteractionMode {
  drawWalls, // Trazar muros / planta (puntos y líneas)
  placeTraps, // Colocar estaciones de control
}

class _TrapLayoutCanvasScreenState extends State<TrapLayoutCanvasScreen> {
  final TrapLayoutService _layoutService = TrapLayoutService();
  final ClientService _clientService = ClientService();
  final ImagePicker _picker = ImagePicker();

  late TrapLayoutModel _layout;
  bool _isNew = true;
  bool _isSaving = false;
  String _selectedTrapType = 'Cebadero Exterior';

  CanvasInteractionMode _currentMode = CanvasInteractionMode.placeTraps;
  final List<TrapWallPoint> _activeWallPoints = [];
  String _activeWallLabel = '';

  List<ClientModel> _savedClients = [];
  ClientModel? _selectedClient;

  // Tipos de trampas soportados con códigos y colores oficiales
  final List<Map<String, dynamic>> _trapTypesConfig = [
    {
      'type': 'Cebadero Exterior',
      'prefix': 'C',
      'label': 'Cebadero Ext.',
      'color': const Color(0xFF15803D),
      'icon': Icons.shield,
      'zone': 'Exterior',
    },
    {
      'type': 'Trampa Mecánica Interior',
      'prefix': 'TM',
      'label': 'Mecánica Int.',
      'color': const Color(0xFF1D4ED8),
      'icon': Icons.pan_tool,
      'zone': 'Interior',
    },
    {
      'type': 'Trampa de Goma',
      'prefix': 'TG',
      'label': 'Goma Adhesiva',
      'color': const Color(0xFFD97706),
      'icon': Icons.sticky_note_2,
      'zone': 'Interior',
    },
    {
      'type': 'Lámpara Luz UV',
      'prefix': 'LU',
      'label': 'Lámpara UV',
      'color': const Color(0xFF7E22CE),
      'icon': Icons.lightbulb,
      'zone': 'Interior',
    },
    {
      'type': 'Punto de Monitoreo',
      'prefix': 'PM',
      'label': 'Monitoreo',
      'color': const Color(0xFFDC2626),
      'icon': Icons.location_on,
      'zone': 'Perímetro',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadClients();
    if (widget.initialLayout != null) {
      _layout = widget.initialLayout!;
      _isNew = false;
      _currentMode = (_layout.walls.isEmpty && _layout.backgroundType == 'grid' && _layout.pins.isEmpty)
          ? CanvasInteractionMode.drawWalls
          : CanvasInteractionMode.placeTraps;
    } else {
      _layout = TrapLayoutModel(
        id: 'layout_${DateTime.now().millisecondsSinceEpoch}',
        folio: '#EJ-LAY-TMP',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        clientBusinessName: '',
        facilityName: 'Planta Principal',
        backgroundType: 'grid',
      );
      _initNewFolio();
      _currentMode = CanvasInteractionMode.drawWalls;
    }
  }

  Future<void> _loadClients() async {
    final clients = await _clientService.getSavedClients();
    if (mounted) setState(() => _savedClients = clients);
  }

  Future<void> _initNewFolio() async {
    final folio = await _layoutService.generateNextFolio();
    if (mounted) setState(() => _layout = _layout.copyWithFolio(folio));
  }

  // --- MÉTODOS DE CARGA DE FONDO DEL PLANO ---

  Future<void> _pickBackgroundImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 92);
      if (picked != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final layoutsDir = Directory('${appDir.path}/planos_imagenes');
        if (!layoutsDir.existsSync()) {
          layoutsDir.createSync(recursive: true);
        }

        final fileName = 'plano_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final savedFile = await File(picked.path).copy('${layoutsDir.path}/$fileName');

        setState(() {
          _layout.backgroundImagePath = savedFile.path;
          _layout.backgroundType = source == ImageSource.camera ? 'camera' : 'gallery';
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Plano cargado exitosamente! Ahora toca sobre él para sembrar las trampas.'),
              backgroundColor: Color(0xFF0F2B48),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando imagen: $e')),
        );
      }
    }
  }

  void _showBackgroundSourceSelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Elegir Fondo para el Plano', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F2B48))),
              const SizedBox(height: 6),
              const Text('Puedes usar una foto real, una imagen satelital o una cuadrícula limpia:', style: TextStyle(fontSize: 12.5, color: Colors.grey)),
              const SizedBox(height: 16),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Color(0xFFE0E7FF), child: Icon(Icons.camera_alt, color: Color(0xFF3730A3))),
                title: const Text('Tomar Foto a Plano en Papel o Pared', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                subtitle: const Text('Fotografía directamente el plano arquitectónico que tenga el cliente.', style: TextStyle(fontSize: 11.5)),
                onTap: () {
                  Navigator.pop(context);
                  _pickBackgroundImage(ImageSource.camera);
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Color(0xFFDCFCE7), child: Icon(Icons.photo_library, color: Color(0xFF166534))),
                title: const Text('Seleccionar de Galería (Google Maps o Imagen)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                subtitle: const Text('Sube una captura de Google Maps satelital o plano en imagen.', style: TextStyle(fontSize: 11.5)),
                onTap: () {
                  Navigator.pop(context);
                  _pickBackgroundImage(ImageSource.gallery);
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Color(0xFFFEF3C7), child: Icon(Icons.grid_4x4, color: Color(0xFF92400E))),
                title: const Text('Lienzo Técnico Cuadriculado (Sin Foto)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                subtitle: const Text('Cuadrícula esquemática milimétrica lista para colocar trampas.', style: TextStyle(fontSize: 11.5)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _layout.backgroundImagePath = null;
                    _layout.backgroundType = 'grid';
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- GESTIÓN DE MUROS Y TRAZADO DE PLANTA ---

  void _closeActiveWall() {
    if (_activeWallPoints.length < 3) return;
    final label = _activeWallLabel.isNotEmpty
        ? _activeWallLabel
        : (_layout.walls.isEmpty ? 'Nave Principal' : 'Área ${_layout.walls.length + 1}');

    setState(() {
      _layout.walls.add(TrapWallPath(
        id: 'wall_${DateTime.now().millisecondsSinceEpoch}',
        points: List.from(_activeWallPoints),
        isClosed: true,
        label: label,
      ));
      _activeWallPoints.clear();
      _activeWallLabel = '';
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Perímetro "$label" completado.'),
          duration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFF0F2B48),
        ),
      );
    }
  }

  void _finishOpenWall() {
    if (_activeWallPoints.length < 2) return;
    final label = _activeWallLabel.isNotEmpty ? _activeWallLabel : 'División Interior';

    setState(() {
      _layout.walls.add(TrapWallPath(
        id: 'wall_${DateTime.now().millisecondsSinceEpoch}',
        points: List.from(_activeWallPoints),
        isClosed: false,
        label: label,
      ));
      _activeWallPoints.clear();
      _activeWallLabel = '';
    });
  }

  void _undoLastWallPoint() {
    setState(() {
      if (_activeWallPoints.isNotEmpty) {
        _activeWallPoints.removeLast();
      } else if (_layout.walls.isNotEmpty) {
        _layout.walls.removeLast();
      }
    });
  }

  void _clearAllWalls() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Borrar trazos de la planta?'),
        content: const Text('Se eliminarán todos los muros y figuras trazadas en el plano.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              setState(() {
                _layout.walls.clear();
                _activeWallPoints.clear();
              });
              Navigator.pop(context);
            },
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
  }

  void _showWallTemplatesModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Plantillas Rápidas de Naves', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F2B48))),
              const SizedBox(height: 4),
              const Text('Inserta una forma base en 1 toque y luego coloca tus trampas:', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.crop_square, color: Color(0xFF0F2B48), size: 28),
                title: const Text('Nave Rectangular Estándar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                subtitle: const Text('Plano simétrico centrado de 4 esquinas', style: TextStyle(fontSize: 11.5)),
                onTap: () {
                  Navigator.pop(context);
                  _applyTemplate([
                    TrapWallPoint(x: 0.12, y: 0.15),
                    TrapWallPoint(x: 0.88, y: 0.15),
                    TrapWallPoint(x: 0.88, y: 0.85),
                    TrapWallPoint(x: 0.12, y: 0.85),
                  ], 'Nave Principal');
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.view_column, color: Color(0xFF0F2B48), size: 28),
                title: const Text('Nave con 2 Zonas (Nave + Oficinas)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                subtitle: const Text('Perímetro rectangular con muro divisor interior', style: TextStyle(fontSize: 11.5)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _layout.walls.clear();
                    _activeWallPoints.clear();
                    _layout.walls.add(TrapWallPath(
                      id: 'wall_${DateTime.now().millisecondsSinceEpoch}',
                      points: [
                        TrapWallPoint(x: 0.12, y: 0.15),
                        TrapWallPoint(x: 0.88, y: 0.15),
                        TrapWallPoint(x: 0.88, y: 0.85),
                        TrapWallPoint(x: 0.12, y: 0.85),
                      ],
                      isClosed: true,
                      label: 'Nave Industrial',
                    ));
                    _layout.walls.add(TrapWallPath(
                      id: 'wall_${DateTime.now().millisecondsSinceEpoch + 1}',
                      points: [
                        TrapWallPoint(x: 0.50, y: 0.15),
                        TrapWallPoint(x: 0.50, y: 0.85),
                      ],
                      isClosed: false,
                      label: 'Muro Divisorio',
                    ));
                  });
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.turn_right, color: Color(0xFF0F2B48), size: 28),
                title: const Text('Planta en forma de L', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                subtitle: const Text('Distribución angular de 6 vértices', style: TextStyle(fontSize: 11.5)),
                onTap: () {
                  Navigator.pop(context);
                  _applyTemplate([
                    TrapWallPoint(x: 0.12, y: 0.15),
                    TrapWallPoint(x: 0.88, y: 0.15),
                    TrapWallPoint(x: 0.88, y: 0.50),
                    TrapWallPoint(x: 0.55, y: 0.50),
                    TrapWallPoint(x: 0.55, y: 0.85),
                    TrapWallPoint(x: 0.12, y: 0.85),
                  ], 'Planta en L');
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.holiday_village, color: Color(0xFF0F2B48), size: 28),
                title: const Text('Planta en forma de U (con Patio Central)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                subtitle: const Text('Diseño con patio de maniobras al centro', style: TextStyle(fontSize: 11.5)),
                onTap: () {
                  Navigator.pop(context);
                  _applyTemplate([
                    TrapWallPoint(x: 0.12, y: 0.15),
                    TrapWallPoint(x: 0.88, y: 0.15),
                    TrapWallPoint(x: 0.88, y: 0.85),
                    TrapWallPoint(x: 0.65, y: 0.85),
                    TrapWallPoint(x: 0.65, y: 0.45),
                    TrapWallPoint(x: 0.35, y: 0.45),
                    TrapWallPoint(x: 0.35, y: 0.85),
                    TrapWallPoint(x: 0.12, y: 0.85),
                  ], 'Planta en U');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _applyTemplate(List<TrapWallPoint> pts, String label) {
    setState(() {
      _layout.walls.clear();
      _activeWallPoints.clear();
      _layout.walls.add(TrapWallPath(
        id: 'wall_${DateTime.now().millisecondsSinceEpoch}',
        points: pts,
        isClosed: true,
        label: label,
      ));
    });
  }

  // --- GESTIÓN DE PINES INTERACTIVOS ---

  String _getNextCodeForType(String type) {
    final cfg = _trapTypesConfig.firstWhere(
      (c) => c['type'] == type,
      orElse: () => _trapTypesConfig.first,
    );
    final prefix = cfg['prefix'] as String;

    int maxNum = 0;
    for (final p in _layout.pins) {
      if (p.code.startsWith('$prefix-')) {
        final numPart = int.tryParse(p.code.replaceFirst('$prefix-', '')) ?? 0;
        if (numPart > maxNum) maxNum = numPart;
      }
    }
    return '$prefix-${(maxNum + 1).toString().padLeft(2, '0')}';
  }

  void _onCanvasTapped(TapDownDetails details, BoxConstraints constraints) {
    final double tapX = (details.localPosition.dx / constraints.maxWidth).clamp(0.04, 0.96);
    final double tapY = (details.localPosition.dy / constraints.maxHeight).clamp(0.04, 0.96);

    // Si estamos en modo Trazar Muros:
    if (_currentMode == CanvasInteractionMode.drawWalls) {
      // Si ya hay al menos 3 puntos y el usuario toca cerca del primer punto, cerrar perímetro:
      if (_activeWallPoints.length >= 3) {
        final first = _activeWallPoints.first;
        final dx = (tapX - first.x) * constraints.maxWidth;
        final dy = (tapY - first.y) * constraints.maxHeight;
        if (dx * dx + dy * dy < 32 * 32) {
          _closeActiveWall();
          return;
        }
      }

      setState(() {
        _activeWallPoints.add(TrapWallPoint(x: tapX, y: tapY));
      });
      return;
    }

    // Si estamos en modo Colocar Trampas:
    final cfg = _trapTypesConfig.firstWhere((c) => c['type'] == _selectedTrapType);
    final nextCode = _getNextCodeForType(_selectedTrapType);

    final newPin = TrapPinModel(
      id: 'pin_${DateTime.now().millisecondsSinceEpoch}',
      code: nextCode,
      type: _selectedTrapType,
      x: tapX,
      y: tapY,
      zone: cfg['zone'] as String,
      area: '',
    );

    setState(() {
      _layout.pins.add(newPin);
    });

    _showEditPinBottomSheet(newPin, isNewPlacement: true);
  }

  void _showEditPinBottomSheet(TrapPinModel pin, {bool isNewPlacement = false}) {
    final codeCtrl = TextEditingController(text: pin.code);
    final areaCtrl = TextEditingController(text: pin.area);
    String selectedZone = pin.zone;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 18,
            bottom: MediaQuery.of(context).viewInsets.bottom + 18,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: _getColorForType(pin.type),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            pin.code,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isNewPlacement ? 'Nueva Estación Agregada' : 'Editar Estación ${pin.code}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F2B48)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: 'Eliminar esta estación',
                    onPressed: () {
                      setState(() => _layout.pins.removeWhere((p) => p.id == pin.id));
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Tipo: ${pin.type}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87)),
              const SizedBox(height: 10),
              TextField(
                controller: codeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Código / Numeración',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: areaCtrl,
                autofocus: isNewPlacement,
                decoration: const InputDecoration(
                  labelText: 'Ubicación / Área específica',
                  hintText: 'Ej. Andén 2 junto a portón, Comedor bajo microondas...',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text('Zona: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(width: 8),
                  ...['Exterior', 'Interior', 'Perímetro'].map((z) {
                    final sel = z == selectedZone;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(z, style: TextStyle(fontSize: 11.5, color: sel ? Colors.white : Colors.black87)),
                        selected: sel,
                        selectedColor: const Color(0xFF0F2B48),
                        onSelected: (val) => setModalState(() => selectedZone = z),
                      ),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F2B48),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Guardar Datos de la Estación'),
                onPressed: () {
                  setState(() {
                    pin.code = codeCtrl.text.trim();
                    pin.area = areaCtrl.text.trim();
                    pin.zone = selectedZone;
                  });
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAllStationsCenso() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Censo de Estaciones y Trampas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F2B48))),
                      Text('Total: ${_layout.pins.length} dispositivos colocados', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const Divider(),
              Expanded(
                child: _layout.pins.isEmpty
                    ? const Center(child: Text('Aún no has colocado ninguna trampa en el plano.'))
                    : ListView.builder(
                        itemCount: _layout.pins.length,
                        itemBuilder: (context, i) {
                          final pin = _layout.pins[i];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _getColorForType(pin.type),
                                child: Text(pin.code, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                              ),
                              title: Text(pin.area.isNotEmpty ? pin.area : 'Sin descripción de área', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                              subtitle: Text('${pin.type} • Zona: ${pin.zone}', style: const TextStyle(fontSize: 11.5)),
                              trailing: IconButton(
                                icon: const Icon(Icons.edit, size: 18, color: Color(0xFF0F2B48)),
                                onPressed: () {
                                  Navigator.pop(context);
                                  _showEditPinBottomSheet(pin);
                                },
                              ),
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

  // --- GUARDADO Y GENERACIÓN DE PDF ---

  Future<void> _saveLayout() async {
    if (_isSaving) return;

    if (_activeWallPoints.length >= 3) {
      _closeActiveWall();
    }

    if (_layout.clientBusinessName.isEmpty) {
      _showClientAndFacilityDialog(thenSave: true);
      return;
    }

    setState(() => _isSaving = true);

    bool success = false;
    bool cloudMasterUpdated = false;
    try {
      success = await _layoutService.saveLayout(_layout);
      if (success) {
        await _clientService.ensureClientExistsLocal(ClientModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          businessName: _layout.clientBusinessName.trim(),
          contactName: _layout.clientContactName.trim(),
          address: _layout.clientAddress.trim(),
          phone: _layout.clientPhone.trim(),
          email: '',
          facilityType: 'Comercial / Restaurante',
          hasTraps: false,
        ));

        try {
          final pdfBytes = await TrapLayoutPdfService.generateLayoutPdf(_layout);
          final tempDir = await getTemporaryDirectory();
          final fileName = 'Plano_Layout_${_layout.folio.replaceAll("#", "")}.pdf';
          final file = File('${tempDir.path}/$fileName');
          await file.writeAsBytes(pdfBytes);

          cloudMasterUpdated = await GoogleDriveSyncService().saveAndSyncMasterBackup(
            clientName: _layout.clientBusinessName,
            documentType: 'Plano',
            folio: _layout.folio,
            localFilePath: file.path,
            fileName: fileName,
          );
        } catch (_) {
          cloudMasterUpdated = await GoogleDriveSyncService().saveAndSyncMasterBackup();
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            !success
                ? 'Error al guardar el plano.'
                : (cloudMasterUpdated
                    ? '¡Plano guardado y Copia Maestra actualizada en Drive!'
                    : '¡Plano guardado localmente! (Sin conexión a Drive en este momento)'),
          ),
          backgroundColor: !success
              ? Colors.red
              : (cloudMasterUpdated ? Colors.green.shade800 : Colors.orange.shade800),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _showClientAndFacilityDialog({bool thenSave = false, bool thenPdf = false}) {
    final clientCtrl = TextEditingController(text: _layout.clientBusinessName);
    final facilityCtrl = TextEditingController(text: _layout.facilityName);
    final addressCtrl = TextEditingController(text: _layout.clientAddress);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Datos del Cliente y Planta', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width > 500 ? 450 : MediaQuery.of(context).size.width * 0.85,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_savedClients.isNotEmpty) ...[
                  DropdownButtonFormField<ClientModel>(
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Elegir del Directorio',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    initialValue: _selectedClient,
                    selectedItemBuilder: (BuildContext context) {
                      return _savedClients.map<Widget>((ClientModel c) {
                        return Text(
                          c.businessName,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        );
                      }).toList();
                    },
                    items: _savedClients.map((c) {
                      return DropdownMenuItem(
                        value: c,
                        child: Text(
                          c.businessName,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        _selectedClient = val;
                        clientCtrl.text = val.businessName;
                        addressCtrl.text = val.address;
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                ],
                TextField(
                  controller: clientCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre de la Empresa o Cliente *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: facilityCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre de la Planta / Sucursal', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: addressCtrl,
                  decoration: const InputDecoration(labelText: 'Dirección o Ubicación', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F2B48), foregroundColor: Colors.white),
            onPressed: () async {
              if (clientCtrl.text.trim().isEmpty) return;
              setState(() {
                _layout.clientBusinessName = clientCtrl.text.trim();
                _layout.facilityName = facilityCtrl.text.trim().isNotEmpty ? facilityCtrl.text.trim() : 'Planta Principal';
                _layout.clientAddress = addressCtrl.text.trim();
              });
              Navigator.pop(context);

              if (thenSave) await _saveLayout();
              if (thenPdf) await _previewAndExportPdf();
            },
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  Future<void> _previewAndExportPdf() async {
    if (_activeWallPoints.length >= 3) {
      _closeActiveWall();
    }

    if (_layout.clientBusinessName.isEmpty) {
      _showClientAndFacilityDialog(thenPdf: true);
      return;
    }

    await _saveLayout();

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text('Plano Oficial ${_layout.folio}'),
            backgroundColor: const Color(0xFF0F2B48),
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.share),
                tooltip: 'Compartir PDF por WhatsApp',
                onPressed: () async {
                  final pdfBytes = await TrapLayoutPdfService.generateLayoutPdf(_layout);
                  final tempDir = await getTemporaryDirectory();
                  final file = File('${tempDir.path}/Plano_Layout_${_layout.folio.replaceAll("#", "")}.pdf');
                  await file.writeAsBytes(pdfBytes);
                  await Share.shareXFiles(
                    [XFile(file.path)],
                    text: 'Plano Oficial de Estaciones de Control EJ Exterminadores: ${_layout.clientBusinessName}',
                  );
                },
              ),
            ],
          ),
          body: PdfPreview(
            build: (format) => TrapLayoutPdfService.generateLayoutPdf(_layout),
            allowPrinting: true,
            allowSharing: true,
            canChangeOrientation: false,
            canChangePageFormat: false,
          ),
        ),
      ),
    );
  }

  Color _getColorForType(String type) {
    if (type.contains('Cebadero')) return const Color(0xFF15803D);
    if (type.contains('Mecánica') || type.contains('Golpe')) return const Color(0xFF1D4ED8);
    if (type.contains('Goma') || type.contains('Adhesiva')) return const Color(0xFFD97706);
    if (type.contains('Luz UV') || type.contains('Lámpara')) return const Color(0xFF7E22CE);
    return const Color(0xFFDC2626);
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = _layout.backgroundImagePath != null && File(_layout.backgroundImagePath!).existsSync();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_isNew ? 'Nuevo Plano y Layout' : 'Editar Plano ${_layout.folio}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(
              _layout.clientBusinessName.isNotEmpty ? '${_layout.clientBusinessName} • ${_layout.facilityName}' : 'Toca para agregar datos del cliente',
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0F2B48),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note),
            tooltip: 'Datos del Cliente',
            onPressed: () => _showClientAndFacilityDialog(),
          ),
          IconButton(
            icon: const Icon(Icons.image),
            tooltip: 'Cambiar Fondo / Plano',
            onPressed: _showBackgroundSourceSelector,
          ),
          IconButton(
            icon: const Icon(Icons.list_alt),
            tooltip: 'Ver Censo de Trampas',
            onPressed: _showAllStationsCenso,
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Generar PDF',
            onPressed: _isSaving ? null : _previewAndExportPdf,
          ),
        ],
      ),
      body: Column(
        children: [
          // Selector de Modo: 1. Trazar Muros vs 2. Colocar Trampas
          Container(
            color: const Color(0xFF0F2B48),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _currentMode = CanvasInteractionMode.drawWalls),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _currentMode == CanvasInteractionMode.drawWalls ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.architecture, size: 16, color: _currentMode == CanvasInteractionMode.drawWalls ? const Color(0xFF0F2B48) : Colors.white70),
                          const SizedBox(width: 6),
                          Text(
                            '1. Trazar Muros (${_layout.walls.length})',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _currentMode == CanvasInteractionMode.drawWalls ? const Color(0xFF0F2B48) : Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      if (_activeWallPoints.length >= 3) {
                        _closeActiveWall();
                      }
                      setState(() => _currentMode = CanvasInteractionMode.placeTraps);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _currentMode == CanvasInteractionMode.placeTraps ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.location_on, size: 16, color: _currentMode == CanvasInteractionMode.placeTraps ? const Color(0xFF0F2B48) : Colors.white70),
                          const SizedBox(width: 6),
                          Text(
                            '2. Colocar Trampas (${_layout.pins.length})',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _currentMode == CanvasInteractionMode.placeTraps ? const Color(0xFF0F2B48) : Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Banner Informativo Contextual
          if (_currentMode == CanvasInteractionMode.drawWalls)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: const Color(0xFFEFF6FF),
              child: Row(
                children: [
                  const Icon(Icons.touch_app, size: 16, color: Color(0xFF1E40AF)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _activeWallPoints.isEmpty
                          ? 'Toca la pantalla para marcar cada esquina de la nave o área.'
                          : 'Punto ${_activeWallPoints.length} marcado. Sigue tocando o presiona "Cerrar Perímetro".',
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF1E40AF), fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (_activeWallPoints.isNotEmpty)
                    TextButton.icon(
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
                      icon: const Icon(Icons.undo, size: 15),
                      label: const Text('Deshacer', style: TextStyle(fontSize: 11)),
                      onPressed: _undoLastWallPoint,
                    ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: const Color(0xFF0F2B48).withValues(alpha: 0.06),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.touch_app, size: 18, color: Color(0xFF0F2B48)),
                        const SizedBox(width: 8),
                        Text(
                          'Toca la pantalla para ubicar: ',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                        ),
                        Flexible(
                          child: Text(
                            _selectedTrapType,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _getColorForType(_selectedTrapType)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${_layout.pins.length} en plano',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F2B48)),
                  ),
                ],
              ),
            ),

          // LIENZO INTERACTIVO DEL PLANO
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  onTapDown: (details) => _onCanvasTapped(details, constraints),
                  child: Container(
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    color: Colors.grey.shade200,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // 1. Fondo del plano (Foto real o Cuadrícula)
                        Positioned.fill(
                          child: hasImage
                              ? Image.file(
                                  File(_layout.backgroundImagePath!),
                                  fit: BoxFit.contain,
                                )
                              : _buildBlueprintGrid(),
                        ),

                        // 2. Capa de Muros y Trazos de la Planta
                        Positioned.fill(
                          child: CustomPaint(
                            painter: WallsCanvasPainter(
                              walls: _layout.walls,
                              activePoints: _activeWallPoints,
                              isDrawMode: _currentMode == CanvasInteractionMode.drawWalls,
                            ),
                          ),
                        ),

                        // 3. Rosa de los Vientos / Indicador de Norte
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.9),
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)],
                            ),
                            child: const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('▲', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red)),
                                Text('N', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0F2B48))),
                              ],
                            ),
                          ),
                        ),

                        // 4. PINES SEMBRADOS EN EL PLANO
                        ..._layout.pins.map((pin) {
                          final double pinX = pin.x * constraints.maxWidth - 16;
                          final double pinY = pin.y * constraints.maxHeight - 16;
                          final color = _getColorForType(pin.type);

                          return Positioned(
                            left: pinX,
                            top: pinY,
                            child: GestureDetector(
                              onTap: () => _showEditPinBottomSheet(pin),
                              onPanUpdate: _currentMode == CanvasInteractionMode.placeTraps
                                  ? (dragDetails) {
                                      setState(() {
                                        pin.x = ((pin.x * constraints.maxWidth + dragDetails.delta.dx) / constraints.maxWidth).clamp(0.04, 0.96);
                                        pin.y = ((pin.y * constraints.maxHeight + dragDetails.delta.dy) / constraints.maxHeight).clamp(0.04, 0.96);
                                      });
                                    }
                                  : null,
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.35),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  pin.code,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // BARRA FLOTANTE INFERIOR (DEPENDIENDO DEL MODO)
          if (_currentMode == CanvasInteractionMode.drawWalls)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6, offset: const Offset(0, -2))],
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _activeWallPoints.length >= 3 ? const Color(0xFF16A34A) : Colors.grey.shade400,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            icon: const Icon(Icons.check_circle_outline, size: 16),
                            label: Text(_activeWallPoints.length >= 3 ? 'Cerrar Perímetro (${_activeWallPoints.length} pts)' : 'Cerrar Perímetro'),
                            onPressed: _activeWallPoints.length >= 3 ? _closeActiveWall : null,
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF0F2B48)),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            icon: const Icon(Icons.add, size: 16, color: Color(0xFF0F2B48)),
                            label: const Text('Muro Interior', style: TextStyle(color: Color(0xFF0F2B48), fontSize: 12)),
                            onPressed: _activeWallPoints.length >= 2 ? _finishOpenWall : null,
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF0F2B48)),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            icon: const Icon(Icons.dashboard_customize, size: 16, color: Color(0xFF0F2B48)),
                            label: const Text('Plantillas Rápidas', style: TextStyle(color: Color(0xFF0F2B48), fontSize: 12)),
                            onPressed: _showWallTemplatesModal,
                          ),
                          const SizedBox(width: 8),
                          if (_layout.walls.isNotEmpty || _activeWallPoints.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.delete_sweep, color: Colors.red),
                              tooltip: 'Limpiar muros',
                              onPressed: _clearAllWalls,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F2B48),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.arrow_forward, size: 18),
                        label: const Text('Listo: Ir a Colocar Trampas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                        onPressed: () {
                          if (_activeWallPoints.length >= 3) {
                            _closeActiveWall();
                          }
                          setState(() => _currentMode = CanvasInteractionMode.placeTraps);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6, offset: const Offset(0, -2))],
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _trapTypesConfig.map((cfg) {
                          final type = cfg['type'] as String;
                          final label = cfg['label'] as String;
                          final color = cfg['color'] as Color;
                          final isSel = type == _selectedTrapType;
                          final count = _layout.pins.where((p) => p.type == type).length;

                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              avatar: CircleAvatar(
                                backgroundColor: color,
                                radius: 8,
                              ),
                              label: Text(
                                '$label ($count)',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                  color: isSel ? Colors.white : Colors.black87,
                                ),
                              ),
                              selected: isSel,
                              selectedColor: color,
                              onSelected: (val) {
                                if (val) setState(() => _selectedTrapType = type);
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF0F2B48)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F2B48)),
                                  )
                                : const Icon(Icons.save_outlined, size: 18),
                            label: Text(
                              _isSaving ? 'Guardando...' : 'Guardar Plano',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            onPressed: _isSaving ? null : _saveLayout,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F2B48),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            icon: const Icon(Icons.picture_as_pdf, size: 18),
                            label: const Text('Generar PDF Oficial', style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: _isSaving ? null : _previewAndExportPdf,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBlueprintGrid() {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: CustomPaint(
        painter: BlueprintGridPainter(),
        child: _layout.walls.isEmpty && _activeWallPoints.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.architecture, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 10),
                      Text(
                        'Lienzo de Dibujo Técnico',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '1. Toca la pantalla para marcar cada esquina de la nave.\n2. Presiona "Cerrar Perímetro".\n3. O presiona "Plantillas Rápidas" abajo para insertar una forma.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500, height: 1.35),
                      ),
                    ],
                  ),
                ),
              )
            : null,
      ),
    );
  }
}

class WallsCanvasPainter extends CustomPainter {
  final List<TrapWallPath> walls;
  final List<TrapWallPoint> activePoints;
  final bool isDrawMode;

  WallsCanvasPainter({
    required this.walls,
    required this.activePoints,
    required this.isDrawMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final wallPaint = Paint()
      ..color = const Color(0xFF0F2B48)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = const Color(0xFF0F2B48).withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    // 1. Dibujar muros guardados
    for (final wall in walls) {
      if (wall.points.length < 2) continue;
      final path = Path();
      path.moveTo(wall.points.first.x * size.width, wall.points.first.y * size.height);
      for (int i = 1; i < wall.points.length; i++) {
        path.lineTo(wall.points[i].x * size.width, wall.points[i].y * size.height);
      }
      if (wall.isClosed && wall.points.length >= 3) {
        path.close();
        canvas.drawPath(path, fillPaint);
      }
      canvas.drawPath(path, wallPaint);

      // Dibujar etiqueta en centroide
      if (wall.label.isNotEmpty && wall.points.isNotEmpty) {
        final cx = wall.points.map((p) => p.x).reduce((a, b) => a + b) / wall.points.length * size.width;
        final cy = wall.points.map((p) => p.y).reduce((a, b) => a + b) / wall.points.length * size.height;
        _drawLabel(canvas, Offset(cx, cy), wall.label);
      }
    }

    // 2. Dibujar trazo activo en proceso
    if (activePoints.isNotEmpty) {
      final activeLinePaint = Paint()
        ..color = const Color(0xFF2563EB)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final activePath = Path();
      activePath.moveTo(activePoints.first.x * size.width, activePoints.first.y * size.height);
      for (int i = 1; i < activePoints.length; i++) {
        activePath.lineTo(activePoints[i].x * size.width, activePoints[i].y * size.height);
      }
      canvas.drawPath(activePath, activeLinePaint);

      // Dibujar manijas circulares con números
      for (int i = 0; i < activePoints.length; i++) {
        final pt = activePoints[i];
        final center = Offset(pt.x * size.width, pt.y * size.height);
        final isFirst = i == 0;

        final circlePaint = Paint()
          ..color = isFirst ? const Color(0xFF16A34A) : const Color(0xFF2563EB)
          ..style = PaintingStyle.fill;

        canvas.drawCircle(center, isFirst ? 11 : 9, circlePaint);
        canvas.drawCircle(
          center,
          isFirst ? 11 : 9,
          Paint()
            ..color = Colors.white
            ..strokeWidth = 2
            ..style = PaintingStyle.stroke,
        );

        // Texto del número
        final textSpan = TextSpan(
          text: '${i + 1}',
          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
        );
        final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
        tp.layout();
        tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
      }
    }
  }

  void _drawLabel(Canvas canvas, Offset pos, String text) {
    final textSpan = TextSpan(
      text: text,
      style: const TextStyle(
        color: Color(0xFF0F2B48),
        fontSize: 11,
        fontWeight: FontWeight.bold,
      ),
    );
    final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
    tp.layout();

    final bgRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: pos, width: tp.width + 12, height: tp.height + 6),
      const Radius.circular(4),
    );

    canvas.drawRRect(bgRect, Paint()..color = Colors.white.withValues(alpha: 0.9));
    canvas.drawRRect(bgRect, Paint()..color = const Color(0xFF0F2B48).withValues(alpha: 0.3)..style = PaintingStyle.stroke..strokeWidth = 0.8);
    tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant WallsCanvasPainter oldDelegate) => true;
}

class BlueprintGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFCBD5E1).withValues(alpha: 0.6)
      ..strokeWidth = 0.5;

    const double step = 25.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

extension TrapLayoutModelExt on TrapLayoutModel {
  TrapLayoutModel copyWithFolio(String newFolio) {
    return TrapLayoutModel(
      id: id,
      folio: newFolio,
      createdAt: createdAt,
      updatedAt: updatedAt,
      clientBusinessName: clientBusinessName,
      clientContactName: clientContactName,
      clientPhone: clientPhone,
      clientAddress: clientAddress,
      facilityName: facilityName,
      backgroundType: backgroundType,
      backgroundImagePath: backgroundImagePath,
      gridTitle: gridTitle,
      pins: pins,
      walls: walls,
      technicalNotes: technicalNotes,
      technicianName: technicianName,
    );
  }
}
