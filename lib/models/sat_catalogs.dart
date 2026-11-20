class SatProductItem {
  final String code;
  final String description;
  final String category;

  const SatProductItem({
    required this.code,
    required this.description,
    required this.category,
  });
}

class SatUnitItem {
  final String code;
  final String name;

  const SatUnitItem({
    required this.code,
    required this.name,
  });

  String get label => '$code - $name';
}

class SatCatalogs {
  /// Unidades de medida oficiales del SAT más comunes en México
  static const List<SatUnitItem> units = [
    SatUnitItem(code: 'E48', name: 'Unidad de servicio'),
    SatUnitItem(code: 'H87', name: 'Pieza'),
    SatUnitItem(code: 'XPK', name: 'Paquete'),
    SatUnitItem(code: 'XBX', name: 'Caja'),
    SatUnitItem(code: 'ACT', name: 'Actividad'),
    SatUnitItem(code: 'KGM', name: 'Kilogramo'),
    SatUnitItem(code: 'LTR', name: 'Litro'),
    SatUnitItem(code: 'MTR', name: 'Metro'),
    SatUnitItem(code: 'MTK', name: 'Metro cuadrado'),
    SatUnitItem(code: 'DAY', name: 'Día'),
    SatUnitItem(code: 'MON', name: 'Mes'),
    SatUnitItem(code: 'XUN', name: 'Unidad'),
    SatUnitItem(code: 'SET', name: 'Conjunto / Juego'),
  ];

  /// Catálogo de productos y servicios SAT especializados en Manejo Integrado de Plagas y afines
  static const List<SatProductItem> products = [
    // --- CONTROL DE PLAGAS (SERVICIOS) ---
    SatProductItem(
      code: '72102100',
      description: 'Servicios de control y exterminación de plagas',
      category: 'Control de Plagas',
    ),
    SatProductItem(
      code: '72102101',
      description: 'Servicios de exterminación de roedores (ratas y ratones)',
      category: 'Control de Plagas',
    ),
    SatProductItem(
      code: '72102102',
      description: 'Servicios de control de insectos rastreros y voladores',
      category: 'Control de Plagas',
    ),
    SatProductItem(
      code: '72102103',
      description: 'Servicios de control y exclusión de aves y murciélagos',
      category: 'Control de Plagas',
    ),
    SatProductItem(
      code: '72102104',
      description: 'Servicios de control de termitas y plagas de la madera',
      category: 'Control de Plagas',
    ),

    // --- DISPOSITIVOS Y TRAMPAS (HARDWARE POR PIEZAS) ---
    SatProductItem(
      code: '10191700',
      description: 'Dispositivos para control de plagas (cebaderos, trampas mecánicas)',
      category: 'Dispositivos y Trampas',
    ),
    SatProductItem(
      code: '10191509',
      description: 'Estaciones de cebado y trampas para roedores',
      category: 'Dispositivos y Trampas',
    ),
    SatProductItem(
      code: '42281504',
      description: 'Lámparas trampa de luz UV / Insectocutores para insectos voladores',
      category: 'Dispositivos y Trampas',
    ),
    SatProductItem(
      code: '10191500',
      description: 'Productos para el control de plagas (plaguicidas, cebos y geles)',
      category: 'Dispositivos y Trampas',
    ),
    SatProductItem(
      code: '10191502',
      description: 'Insecticidas químicos y geles cucarachicidas',
      category: 'Dispositivos y Trampas',
    ),

    // --- DESINFECCIÓN Y SANITIZACIÓN ---
    SatProductItem(
      code: '76111501',
      description: 'Servicios de desinfección y sanitización ambiental',
      category: 'Desinfección',
    ),
    SatProductItem(
      code: '76111500',
      description: 'Servicios de limpieza y desinfección de edificios y oficinas',
      category: 'Desinfección',
    ),
    SatProductItem(
      code: '42281500',
      description: 'Equipos y suministros para desinfección',
      category: 'Desinfección',
    ),

    // --- JARDINERÍA Y MANTENIMIENTO ---
    SatProductItem(
      code: '70111700',
      description: 'Servicios de mantenimiento y cuidado de parques y jardines',
      category: 'Jardinería',
    ),
    SatProductItem(
      code: '70111706',
      description: 'Servicios de fumigación y control fitosanitario de árboles y plantas',
      category: 'Jardinería',
    ),
    SatProductItem(
      code: '72102900',
      description: 'Servicios de mantenimiento y reparación general de instalaciones',
      category: 'Mantenimiento',
    ),
    SatProductItem(
      code: '76121500',
      description: 'Servicios de recolección y manejo de residuos',
      category: 'Mantenimiento',
    ),
    SatProductItem(
      code: '81141600',
      description: 'Servicios de inspección técnica y consultoría de bioseguridad',
      category: 'Mantenimiento',
    ),
  ];

  static List<SatProductItem> searchProducts(String query) {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) return products;
    return products.where((p) {
      return p.code.contains(clean) ||
          p.description.toLowerCase().contains(clean) ||
          p.category.toLowerCase().contains(clean);
    }).toList();
  }
}
