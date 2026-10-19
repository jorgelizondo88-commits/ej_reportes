import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/report_model.dart';

class ChemicalService {
  static const String _catalogKey = 'ej_chemical_catalog';

  /// Catálogo oficial predeterminado
  static List<ChemicalProduct> get _defaultProducts => [
    ChemicalProduct(
      id: 'chem_fiprax',
      name: 'Fiprax',
      activeIngredient: 'Fipronil 2.5% CE',
      dosage: '5 a 10 ml / Litro',
      registrationNumber: 'RSCO-URB-INAC-177-315-009-2.5',
      applicationMethod: 'Aspersión focalizada / Inyección',
      targetArea: 'Zoclos, grietas, hendiduras y perímetro contra cucaracha y termita',
    ),
    ChemicalProduct(
      id: 'chem_resifum',
      name: 'Resifum',
      activeIngredient: 'Cipermetrina 21.29% CE',
      dosage: '5 a 10 ml / Litro',
      registrationNumber: 'RSCO-URB-INAC-115-315-009-21.3',
      applicationMethod: 'Aspersión manual / motorizada',
      targetArea: 'Perímetros exteriores, andenes, bodegas y áreas industriales',
    ),
    ChemicalProduct(
      id: 'chem_ddvp',
      name: 'DDVP (Diclorvos 500)',
      activeIngredient: 'Diclorvos 50% CE',
      dosage: '5 a 10 ml / Litro',
      registrationNumber: 'RSCO-URB-INAC-103-315-009-50',
      applicationMethod: 'Termonebulización / Nebulización en frío (ULV)',
      targetArea: 'Drenajes, registros sanitarios, fosas y bodegas cerradas sin personal',
    ),
    ChemicalProduct(
      id: 'chem_tayson',
      name: 'Tayson 4E',
      activeIngredient: 'Clorpirifos etil 44.5% CE',
      dosage: '5 a 10 ml / Litro',
      registrationNumber: 'RSCO-URB-INAC-111-315-009-44.5',
      applicationMethod: 'Aspersión perimetral / Tratamiento de choque',
      targetArea: 'Cimentaciones, registros exteriores y perímetros industriales',
    ),
    ChemicalProduct(
      id: 'chem_biothrine',
      name: 'Biothrine Flow',
      activeIngredient: 'Deltametrina 2.5% SC',
      dosage: '10 ml / Litro',
      registrationNumber: 'RSCO-DOM-INAC-119-315-009-2.5',
      applicationMethod: 'Aspersión manual',
      targetArea: 'Perímetro interior, oficinas y áreas de bajo olor',
    ),
    ChemicalProduct(
      id: 'chem_termidor',
      name: 'Termidor 25 CE',
      activeIngredient: 'Fipronil 2.5%',
      dosage: '4 ml / Litro',
      registrationNumber: 'RSCO-URB-INAC-177-315-009-2.5',
      applicationMethod: 'Aspersión perimetral',
      targetArea: 'Grietas, hendiduras y barrera antitermita',
    ),
    ChemicalProduct(
      id: 'chem_maxforce',
      name: 'Maxforce Gel',
      activeIngredient: 'Imidacloprid 2.15%',
      dosage: 'Gotas de 0.1 g / m²',
      registrationNumber: 'RSCO-DOM-INAC-179-315-015-2.15',
      applicationMethod: 'Aplicación de Gel focalizado',
      targetArea: 'Cocina, alacenas, tarjas y motores eléctricos',
    ),
    ChemicalProduct(
      id: 'chem_kothrine',
      name: 'K-Othrine WG 250',
      activeIngredient: 'Deltametrina 25%',
      dosage: '5 g / 5 Litros',
      registrationNumber: 'RSCO-DOM-INAC-119-315-034-25',
      applicationMethod: 'Aspersión manual',
      targetArea: 'Áreas comerciales, comedores y áreas secas',
    ),
  ];

  /// Obtiene todos los productos del catálogo maestro guardado
  Future<List<ChemicalProduct>> getCatalog() async {
    final prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_catalogKey);

    if (raw == null || raw.isEmpty) {
      await saveCatalog(_defaultProducts);
      return _defaultProducts;
    }

    try {
      final List<dynamic> list = jsonDecode(raw);
      List<ChemicalProduct> savedList = list.map((item) => ChemicalProduct.fromMap(item)).toList();

      // Sincroniza automáticamente los nuevos químicos si no existían en la memoria
      bool modified = false;
      for (var def in _defaultProducts) {
        if (!savedList.any((p) => p.name.toLowerCase() == def.name.toLowerCase())) {
          savedList.add(def);
          modified = true;
        }
      }

      if (modified) {
        await saveCatalog(savedList);
      }

      return savedList;
    } catch (_) {
      return _defaultProducts;
    }
  }

  Future<void> saveCatalog(List<ChemicalProduct> products) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(products.map((p) => p.toMap()).toList());
    await prefs.setString(_catalogKey, raw);
  }

  Future<void> upsertProduct(ChemicalProduct product) async {
    final catalog = await getCatalog();
    final index = catalog.indexWhere((p) => p.id == product.id);

    if (index >= 0) {
      catalog[index] = product;
    } else {
      catalog.add(product);
    }
    await saveCatalog(catalog);
  }

  Future<void> deleteProduct(String id) async {
    final catalog = await getCatalog();
    catalog.removeWhere((p) => p.id == id);
    await saveCatalog(catalog);
  }
}