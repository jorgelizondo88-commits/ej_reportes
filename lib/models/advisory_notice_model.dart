class AdvisoryNoticeModel {
  final String id;
  final String title;
  final String category; // 'Oficinas y Corporativos', 'Restaurantes y Cocinas', 'Almacenes y Bodegas', 'Servicio Técnico'
  final String targetAudience;
  final String iconEmoji;
  final String objective;
  final String problemStatement;
  final List<String> mandatoryRules;
  final List<String> facilityRecommendations;
  final String technicalDisclaimer;

  const AdvisoryNoticeModel({
    required this.id,
    required this.title,
    required this.category,
    required this.targetAudience,
    required this.iconEmoji,
    required this.objective,
    required this.problemStatement,
    required this.mandatoryRules,
    required this.facilityRecommendations,
    required this.technicalDisclaimer,
  });

  static List<AdvisoryNoticeModel> getAllNotices() {
    return const [
      // 1. INDUCCIÓN A NUEVA PÓLIZA Y PROCESO DE CONTROL
      AdvisoryNoticeModel(
        id: 'induccion_nueva_poliza',
        title: 'Inicio de Póliza: Inducción al Control de Plagas y Curva de Efectividad',
        category: 'Pólizas y Empresas',
        targetAudience: 'Directivos, Gerencias de Operaciones, Comités de Calidad y Personal',
        iconEmoji: '🤝',
        objective: 'Explicar con claridad técnica el funcionamiento del Manejo Integrado de Plagas (MIP), las etapas del tratamiento inicial y desmitificar la expectativa de erradicación inmediata. El control profesional es un proceso biológico progresivo y coordinado, no un acto de magia.',
        problemStatement: 'Existe la falsa expectativa de que con la primera aplicación los insectos "desaparecen al instante por arte de magia". En la realidad técnica, los insecticidas de choque y residuales provocan un "efecto de desalojo" (flushing) donde las plagas ocultas salen de sus refugios y se muestran más activas o aturdidas antes de morir. Asimismo, ningún producto químico destruye las cápsulas de huevecillos (ootecas); la erradicación total requiere romper el ciclo reproductivo mediante aplicaciones programadas y seguimiento técnico constante.',
        mandatoryRules: [
          'DÍAS 1 AL 3 - EFECTO DESALOJO (TOTALMENTE NORMAL): Es normal ver insectos salir desorientados o convulsionando. No significa que "haya más plaga", sino que el químico penetró sus nidos expulsándolos hacia el exterior para su muerte.',
          'PROHIBIDO APLICAR INSECTICIDAS CASEROS (AEROSOLES): Los insecticidas de supermercado tienen efecto repelente que arruina el tratamiento profesional, ahuyenta la plaga hacia otras áreas y neutraliza nuestros cebos.',
          'NO LAVAR NI TRAPEAR ZÓCALOS POR 5 DÍAS: No trapee con cloro ni desengrasante las orillas y zócalos donde se colocó la película insecticida para no retirar la barrera química de protección.',
          'DISPOSICIÓN HIGIÉNICA DE INSECTOS MUERTOS: Barrer diariamente los insectos caídos y depositarlos en bolsas de basura cerradas en contenedores exteriores para evitar contaminación.',
          'REPORTE DE INCIDENCIAS SIN ALARMA: Si observa insectos tras la aplicación, anote la zona exacta y compártala con nuestro técnico para focalizar el refuerzo en la siguiente visita programada.',
        ],
        facilityRecommendations: [
          'FASE 1 - CHOQUE Y DESALOJO (Semana 1): Eliminación masiva de adultos visibles y expulsión de refugios profundos.',
          'FASE 2 - ROMPIMIENTO DEL CICLO BIOLÓGICO (Semanas 2 y 3): Control progresivo de ninfas nacidas de huevecillos antes de su madurez reproductiva.',
          'FASE 3 - CONTROL TOTAL Y MANTENIMIENTO (Mes 2 en adelante): Mantenimiento del cordón sanitario y monitoreo mediante cebos y trampas.',
          'EL 50% DEL ÉXITO ES LA HIGIENE: Es indispensable reparar fugas de humedad, desechar cajas de cartón innecesarias y no dejar comida expuesta en cajones o escritorios.',
        ],
        technicalDisclaimer: 'El control profesional de plagas es una ciencia biológica, no magia. EJ Exterminadores le asegura que con el cumplimiento de las fechas de su póliza y el seguimiento a estas recomendaciones, su empresa alcanzará un estatus sanitario óptimo y libre de plagas.',
      ),

      // 2. PROTOCOLO DE VISITAS Y MONITOREO EN PÓLIZAS
      AdvisoryNoticeModel(
        id: 'protocolo_visitas_poliza',
        title: 'Protocolo de Visitas y Monitoreo: Dinámica de Servicio en Pólizas Comerciales',
        category: 'Pólizas y Empresas',
        targetAudience: 'Encargados de Mantenimiento, Seguridad Patrimonial y Recepción',
        iconEmoji: '📋',
        objective: 'Alinear la logística y los tiempos de cada visita técnica programada dentro de la póliza contratada para garantizar una cobertura total y bitácora sanitaria al día.',
        problemStatement: 'Las áreas cerradas bajo llave, falta de autorización de acceso en caseta o la reubicación no informada de trampas de monitoreo interrumpen la cadena de protección y dejan puntos ciegos susceptibles a plagas.',
        mandatoryRules: [
          'FACILITAR ACCESO A ZONAS CRÍTICAS: Cuartos de máquinas, subestaciones, almacenes, cocinas y registros de drenaje deben estar accesibles para la inspección del técnico.',
          'PROHIBIDO MOVER O MANIPULAR TRAMPAS: Las estaciones de cebado y trampas mecánicas están numeradas y geolocalizadas según el croquis técnico; no las mueva ni bloquee con cajas o tarimas.',
          'REVISIÓN Y FIRMA DE CONFORMIDAD: Al finalizar la visita, el responsable del inmueble debe validar las acciones realizadas y firmar el reporte digital de servicio.',
          'REPORTAR INCIDENCIAS AL TÉCNICO: Notificar si se detectaron roedores, insectos o si hubo ingresos recientes de mercancía sospechosa desde la última visita.',
        ],
        facilityRecommendations: [
          'Inspección física y reposición de cebos rodenticidas en todo el perímetro exterior en cada visita programada.',
          'Revisión de trampas de luz UV para insectos voladores y cambio periódico de láminas engomadas.',
          'Generación y entrega inmediata del reporte digital con folio oficial y certificación sanitaria.',
          'Monitoreo continuo de bitácora para auditorías de calidad o inspecciones de salubridad.',
        ],
        technicalDisclaimer: 'Una póliza de control de plagas es un escudo preventivo continuo. Cumplir puntualmente con cada visita programada en el cronograma evita que las plagas vuelvan a establecerse en sus instalaciones.',
      ),

      // 3. OFICINAS Y CAJONES DE COMIDA
      AdvisoryNoticeModel(
        id: 'oficinas_roedores',
        title: 'Buenas Prácticas e Higiene: Prevención de Roedores en Áreas de Oficina',
        category: 'Oficinas y Corporativos',
        targetAudience: 'Personal de Oficina, Gerencias y Recursos Humanos',
        iconEmoji: '🏢',
        objective: 'Establecer lineamientos obligatorios de higiene interna para eliminar fuentes de atracción de fauna nociva (ratones y cucarachas) dentro de estaciones de trabajo y cajoneras.',
        problemStatement: 'Se ha detectado la presencia de restos de comida, paquetes abiertos de galletas, panecillos, frituras y dulces almacenados en cajones y escritorios de empleados. El agudo olfato de los roedores detecta estos alimentos a gran distancia y un cajón de madera o metal no representa ninguna barrera hermética. Cuando el personal deja comida accesible, los roedores ignoran los cebos técnicos colocados por el servicio de fumigación.',
        mandatoryRules: [
          'PROHIBIDO almacenar alimentos abiertos, galletas, botanas o restos de comida en cajones, gavetas o archiveros.',
          'Si un empleado consume alimentos en su estación de trabajo, todo snack restante DEBE guardarse en recipientes de plástico rígido o vidrio con tapa hermética (tuppers).',
          'Los restos de comida, envolturas grasientas y cáscaras deben desecharse EXCLUSIVAMENTE en los botes de basura del comedor o cocina de la empresa (con bolsa y pedal).',
          'PROHIBIDO arrojar restos de comida o bebidas dulces en los botes de papelera debajo del escritorio.',
          'Al finalizar la jornada laboral, el escritorio debe quedar completamente libre de migajas, tazas de café sucias o envolturas.',
        ],
        facilityRecommendations: [
          'El personal de limpieza debe retirar diariamente y sin excepción las bolsas de basura de todas las áreas antes de cerrar las oficinas por la noche.',
          'Realizar inspecciones periódicas aleatorias de cajones y gavetas por parte de supervisión o Recursos Humanos.',
          'Sellar holguras y pasacables en pisos falsos o canaletas de red eléctrica por donde transitan los roedores.',
        ],
        technicalDisclaimer: 'El tratamiento químico y cebado profesional de EJ Exterminadores tiene una efectividad máxima, pero NO PUEDE competir contra fuentes constantes de alimento fácil dejadas por los usuarios. El éxito del programa de control de plagas es una RESPONSABILIDAD COMPARTIDA: el servicio técnico controla la plaga existente, y el personal de la empresa evita que regresen mediante buenos hábitos de higiene.',
      ),

      // 2. RESTAURANTES Y COCINAS
      AdvisoryNoticeModel(
        id: 'restaurantes_cocinas',
        title: 'Manejo Sanitario y Exclusión de Plagas en Restaurantes y Cocinas',
        category: 'Restaurantes y Cocinas',
        targetAudience: 'Chefs, Cocineros, Stewards y Gerentes de Alimentos y Bebidas',
        iconEmoji: '🍽️',
        objective: 'Prevenir la proliferación de cucaracha alemana, moscas y roedores en áreas de preparación de alimentos mediante el cumplimiento de la norma de inocuidad alimentaria.',
        problemStatement: 'Las cocinas comerciales representan el hábitat perfecto para plagas debido a la presencia constante de calor, humedad, grasa y vapor. La falta de limpieza en motores de equipos y acumulación de grasa debajo de planchas anula los efectos de cualquier tratamiento técnico.',
        mandatoryRules: [
          'Limpieza nocturna profunda: desengrasar motores de refrigeradores, freidoras, estufas y planchas después de cada turno.',
          'PROHIBIDO dejar vajilla sucia, ollas con agua o sartenes con grasa en remojo durante la noche.',
          'Elevar todos los insumos secos (harinas, granos, latería) sobre tarimas plásticas a un mínimo de 15 cm del piso.',
          'Inspeccionar minuciosamente cajas de cartón corrugado y arpillas de verdura al recibirlas; las ootecas de cucaracha ingresan comúnmente en cajas de huevo y cartón.',
          'Lavar y tallar diariamente las coladeras y registros con agua caliente y desengrasante para eliminar la biopelícula que alimenta a las moscas de drenaje.',
        ],
        facilityRecommendations: [
          'Instalar y mantener en funcionamiento cortinas de aire en accesos de proveedores y servicio.',
          'Sellar con silicón de grado alimenticio las juntas entre zócalos de azulejo y mesas de acero inoxidable.',
          'Mantener botes de basura de cocina con pedal y tapa abatible en todo momento.',
        ],
        technicalDisclaimer: 'En establecimientos de preparación de alimentos, el 70% del control de plagas depende de la higiene y exclusión física. Los productos químicos aplicados por EJ Exterminadores están autorizados ante COFEPRIS para la industria alimentaria, pero requieren un entorno con limpieza estricta para lograr cero presencia de fauna nociva.',
      ),

      // 3. ALMACENES Y BODEGAS
      AdvisoryNoticeModel(
        id: 'almacenes_bodegas',
        title: 'Protocolo de Exclusión Perimetral y Almacenamiento en Bodegas y CEDIS',
        category: 'Almacenes y Bodegas',
        targetAudience: 'Jefes de Almacén, Operadores de Montacargas y Personal de Mantenimiento',
        iconEmoji: '📦',
        objective: 'Evitar el anidamiento de roedores, alacranes y aves dentro de bodegas mediante el ordenamiento logístico de tarimas y sellado de accesos.',
        problemStatement: 'Las tarimas pegadas a los muros y cortinas metálicas con holguras en el suelo permiten el libre tránsito y reproducción oculta de roedores y alacranes entre la mercancía almacenada.',
        mandatoryRules: [
          'REGLA DE ORO DE 45 CM: Mantener un pasillo perimetral de inspección de al menos 45 cm libre entre las tarimas y cualquier pared perimetral.',
          'Rotación de inventarios estricta (PEPS: Primeras Entradas, Primeras Salidas) para evitar que mercancía quede estancada por meses en rincones.',
          'PROHIBIDO almacenar tarimas rotas, tarimas de madera húmeda o cartón de desecho dentro de la nave principal.',
          'No obstaculizar ni cubrir las estaciones de cebado o trampas mecánicas colocadas por EJ Exterminadores en las paredes.',
        ],
        facilityRecommendations: [
          'Instalar guardapolvos de cepillo industrial de alta densidad en la parte inferior de todas las cortinas metálicas de andén.',
          'Sellar orificios alrededor de tuberías de desagüe pluvial y canalizaciones eléctricas.',
          'Mantener podada la maleza y libre de escombros una franja de 1 metro alrededor de todo el exterior de la bodega.',
        ],
        technicalDisclaimer: 'Las estaciones de cebado y trampas perimetrales instaladas por EJ Exterminadores funcionan como anillos concéntricos de defensa. Si las cortinas quedan abiertas o las tarimas bloquean el acceso a las trampas, la protección se vulnera.',
      ),

      // 4. AVISO PRE-SERVICIO
      AdvisoryNoticeModel(
        id: 'aviso_pre_servicio',
        title: 'Aviso Pre-Servicio: Instrucciones de Preparación Previa a la Fumigación',
        category: 'Servicio Técnico',
        targetAudience: 'Clientes Residenciales, Comerciales y Encargados de Mantenimiento',
        iconEmoji: '⚠️',
        objective: 'Garantizar la máxima efectividad del tratamiento y la total seguridad de las personas y animales antes de la llegada del técnico aplicador.',
        problemStatement: 'Para que el producto insecticida llegue a los nidos y zonas de refugio de las plagas, los zócalos y áreas de aplicación deben estar accesibles y despejadas.',
        mandatoryRules: [
          'DESPEJAR ZÓCALOS Y ORILLAS: Retirar objetos, cajas o tapetes pegados a las paredes para permitir la aspersión perimetral.',
          'RESGUARDAR ALIMENTOS Y UTENSILIOS: Cubrir o guardar en alacenas cerradas toda comida, trastes, cafeteras y utensilios de cocina.',
          'MASCOTAS: Retirar perros, gatos y aves del área a tratar. Cubrir acuarios y peceras con plástico hermético y apagar el oxigenador de aire.',
          'En caso de tratamiento contra chinches o pulgas: lavar ropa de cama y cortinas con agua caliente a más de 60 °C antes del servicio.',
          'Garantizar el acceso al personal técnico a cuartos de máquinas, azoteas, registros y sótanos.',
        ],
        facilityRecommendations: [
          'Realizar una limpieza previa de polvo y pisos para que la película residual del insecticida se fije correctamente al suelo.',
          'Contar con una persona responsable en el inmueble para recibir al técnico y validar áreas con mayor presencia de plaga.',
        ],
        technicalDisclaimer: 'EJ Exterminadores utiliza productos químicos de grado profesional de la más baja toxicidad para humanos y mascotas autorizados por la SSA. Seguir estas sencillas instrucciones garantiza un servicio 100% seguro y de máxima duración.',
      ),

      // 5. AVISO POST-SERVICIO
      AdvisoryNoticeModel(
        id: 'aviso_post_servicio',
        title: 'Aviso Post-Servicio: Recomendaciones de Reingreso y Cuidados Posteriores',
        category: 'Servicio Técnico',
        targetAudience: 'Clientes Residenciales, Oficinas y Encargados de Inmuebles',
        iconEmoji: '📋',
        objective: 'Informar al cliente sobre los tiempos de ventilación, cuidados de limpieza y el comportamiento normal de las plagas tras concluir la fumigación.',
        problemStatement: 'Muchos clientes trapean las orillas inmediatamente después de fumigar, eliminando el producto activo, o se alarman al ver insectos salir aturdidos durante las primeras horas.',
        mandatoryRules: [
          'TIEMPO DE REINGRESO: Esperar un mínimo de 2 a 4 horas antes de reingresar al inmueble tratado para permitir que el producto seque y ventile.',
          'VENTILACIÓN: Al reingresar, abrir puertas y ventanas durante 20 minutos para renovar el aire.',
          'REGLA DE NO TRAPEAR ZÓCALOS: No trapear ni lavar con jabón/cloro las orillas de los muros durante los próximos 3 A 5 DÍAS. Puede limpiar el centro de las habitaciones con mopa húmeda, pero mantenga intacta la franja perimetral donde se depositó el producto residual.',
          'Limpiar superficies de contacto directo de alimentos (mesas y barras de cocina) con un paño húmedo antes de volver a cocinar.',
        ],
        facilityRecommendations: [
          'EFECTO DE DESALOJO (Totalmente Normal): Durante las primeras 24 a 72 horas es común observar cucarachas o insectos salir aturdidos, lentos o convulsionando. Esto indica que el producto penetró sus nidos y están muriendo por el efecto neurotóxico.',
          'Barrer y desechar en bolsa cerrada los insectos muertos que aparezcan.',
          'Si cuenta con póliza mensual o trimestral, mantenga sus fechas programadas para cortar ciclos de eclosión de huevecillos.',
        ],
        technicalDisclaimer: 'La garantía de efectividad de EJ Exterminadores depende de no remover el químico de las orillas. Si nota cualquier eventualidad extraordinaria, comuníquese de inmediato a nuestra línea de atención técnica: 813-175-9342.',
      ),
    ];
  }
}
