import 'package:flutter/material.dart';
import '../../models/report_model.dart';
import '../../services/chemical_service.dart';

class ChemicalStep extends StatefulWidget {
  final List<ChemicalProduct> selectedChemicals;
  final Function(List<ChemicalProduct>) onChemicalsChanged;

  const ChemicalStep({
    super.key,
    required this.selectedChemicals,
    required this.onChemicalsChanged,
  });

  @override
  State<ChemicalStep> createState() => _ChemicalStepState();
}

class _ChemicalStepState extends State<ChemicalStep> {
  final ChemicalService _chemicalService = ChemicalService();
  List<ChemicalProduct> _masterCatalog = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    final list = await _chemicalService.getCatalog();
    setState(() {
      _masterCatalog = list;
      _isLoading = false;
    });
  }

  bool _isSelected(ChemicalProduct product) {
    return widget.selectedChemicals.any((c) => c.name.toLowerCase() == product.name.toLowerCase());
  }

  void _toggleProduct(ChemicalProduct product, bool isChecked) {
    List<ChemicalProduct> updated = List.from(widget.selectedChemicals);
    if (isChecked) {
      updated.add(product);
    } else {
      updated.removeWhere((c) => c.name.toLowerCase() == product.name.toLowerCase());
    }
    widget.onChemicalsChanged(updated);
  }

  void _showAddOrEditCatalogDialog({ChemicalProduct? existingProduct}) {
    final nameController = TextEditingController(text: existingProduct?.name ?? '');
    final ingController = TextEditingController(text: existingProduct?.activeIngredient ?? '');
    final dosageController = TextEditingController(text: existingProduct?.dosage ?? '');
    final regController = TextEditingController(text: existingProduct?.registrationNumber ?? '');
    final methodController = TextEditingController(text: existingProduct?.applicationMethod ?? 'Aspersión manual');
    final areaController = TextEditingController(text: existingProduct?.targetArea ?? 'Perímetro general');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
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
                  existingProduct == null ? 'Nuevo Químico al Catálogo' : 'Editar Químico del Catálogo',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nombre Comercial (ej. Biothrine Flow)'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: ingController,
                  decoration: const InputDecoration(labelText: 'Ingrediente Activo (ej. Deltametrina 2.5%)'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: dosageController,
                        decoration: const InputDecoration(labelText: 'Dosis estándar'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: regController,
                        decoration: const InputDecoration(labelText: 'Registro Sanitario / COFEPRIS'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: methodController,
                  decoration: const InputDecoration(labelText: 'Método (ej. Aspersión, Gel, Termonebulización)'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: areaController,
                  decoration: const InputDecoration(labelText: 'Áreas de aplicación por defecto'),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F2B48),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () async {
                    if (nameController.text.trim().isEmpty) return;

                    final product = ChemicalProduct(
                      id: existingProduct?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                      name: nameController.text.trim(),
                      activeIngredient: ingController.text.trim().isNotEmpty ? ingController.text.trim() : 'No especificado',
                      dosage: dosageController.text.trim().isNotEmpty ? dosageController.text.trim() : 'Según etiqueta',
                      registrationNumber: regController.text.trim().isNotEmpty ? regController.text.trim() : 'Vigente',
                      applicationMethod: methodController.text.trim(),
                      targetArea: areaController.text.trim(),
                    );

                    await _chemicalService.upsertProduct(product);
                    await _loadCatalog();
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Guardar en Catálogo Permanente'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blueGrey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blueGrey.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.touch_app, color: Color(0xFF0F2B48)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Marca con una palomita los químicos aplicados en este servicio (${widget.selectedChemicals.length} seleccionados).',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton.filledTonal(
                  icon: const Icon(Icons.add),
                  tooltip: 'Añadir nuevo químico al catálogo',
                  onPressed: () => _showAddOrEditCatalogDialog(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _masterCatalog.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final product = _masterCatalog[index];
              final selected = _isSelected(product);

              return Card(
                elevation: selected ? 2 : 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: selected ? const Color(0xFF0F2B48) : Colors.grey.shade300,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                color: selected ? Colors.blue.shade50.withValues(alpha: 0.3) : Colors.white,
                child: CheckboxListTile(
                  value: selected,
                  activeColor: const Color(0xFF0F2B48),
                  title: Text(
                    product.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: selected ? const Color(0xFF0F2B48) : Colors.black87,
                    ),
                  ),
                  subtitle: Text(
                    '${product.activeIngredient} | Dosis: ${product.dosage}\nMétodo: ${product.applicationMethod} | Reg: ${product.registrationNumber}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  secondary: IconButton(
                    icon: const Icon(Icons.edit_note, size: 22, color: Colors.grey),
                    tooltip: 'Editar en catálogo',
                    onPressed: () => _showAddOrEditCatalogDialog(existingProduct: product),
                  ),
                  onChanged: (bool? val) {
                    _toggleProduct(product, val ?? false);
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}