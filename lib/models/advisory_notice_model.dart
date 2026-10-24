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
      // 1. INDUSTRIA Y GRANDES COMEDORES (TRABAJO EN EQUIPO Y CURVA DEL 4TO MES)
      AdvisoryNoticeModel(
        id: 'industria_comedores',
        title: 'Protocolo Industrial: Comedores, Trabajo en Equipo y Curva del 4º Mes',
        category: 'Pólizas e Industria',
        targetAudience: 'Gerencias de Planta, Recursos Humanos, Comité de Seguridad y Personal de Comedor',
        iconEmoji: '🏭',
        objective: 'Establecer la corresponsabilidad obligatoria entre la empresa y EJ Exterminadores. Si el personal no cumple con la higiene en comedores y áreas operativas, la erradicación total es biológicamente imposible.',
        problemStatement: 'Los comedores industriales y líneas de producción son focos críticos: migajas en pisos, mesas sin limpiar, comida en lockers y basura sin tapa alimentan a miles de insectos. Asimismo, suele ocurrir que durante los primeros 3 meses no se observa ninguna plaga gracias al tratamiento inicial, pero al 4º o 5º mes el personal relaja la higiene o el clima cambia (lluvias/calor), reapareciendo cucarachas, ciempiés o alacranes. La empresa suele asumir erróneamente que "el fumigador falló", cuando en realidad se reactivaron las fuentes de comida y se rompieron las barreras físicas.',
        mandatoryRules: [
          'COMEDORES: LIMPIEZA INMEDIATA: Retirar migajas, limpiar mesas tras cada turno y vaciar botes de basura antes del cierre nocturno; un solo gramo de comida sustenta a decenas de cucarachas.',
          'PROHIBIDO COMER FUERA DEL COMEDOR: Cero alimentos en líneas de producción, lockers o estaciones de trabajo. Los roedores y cucarachas tienen olfato hiperdesarrollado y viajarán hasta donde haya comida.',
          'EL MITO DEL 4º MES (POR QUÉ REAPARECEN): Si tras meses sin plagas nota insectos, NO es ineficacia del químico: se debe a ingresos en tarimas nuevas, relajamiento de limpieza o cambios de clima (calor/lluvias que empujan alacranes y ciempiés al interior buscando refugio).',
          'PROHIBIDO EL USO DE AEROSOLES CASEROS: Los insecticidas de supermercado actúan como repelentes que dispersan los insectos a áreas limpias y anulan la residualidad de los productos profesionales.',
          'NO LAVAR ZÓCALOS PERIMETRALES: No tallar con cloro ni desengrasante la franja inferior de muros durante 5 días posteriores a la visita; ahí reside la barrera química protectora.',
        ],
        facilityRecommendations: [
          'GUARDAPOLVOS HERMÉTICOS: Instalar cepillos o hules bajo todas las puertas exteriores; los alacranes y ciempiés ingresan caminando desde jardines y patios por rendijas de menos de 3 milímetros.',
          'CONTROL DE TARIMAS Y EMBALAJES: Inspeccionar tarimas de madera y cajas de cartón que entran de proveedores; el 80% de reinfestaciones industriales ingresan por transporte pasivo de mercancía.',
          'SELLADO DE PASACABLES Y GRIETAS: Tapar con silicón o espuma expansiva las perforaciones eléctricas y tuberías donde se ocultan nidos.',
          'TRABAJO EN EQUIPO VITAL: El servicio químico aporta el 50% del éxito; el restante 50% depende de la higiene del personal y la exclusión física del inmueble.',
        ],
        technicalDisclaimer: 'EJ Exterminadores garantiza el uso de ingredientes activos de grado industrial autorizados ante COFEPRIS y el monitoreo puntual en cada visita. Sin embargo, ningún químico puede sustituir los hábitos de limpieza del personal. El control de plagas es una alianza bilateral: nosotros aplicamos la ciencia y la empresa mantiene el orden sanitario.',
      ),

      // 2. COMERCIOS, TIENDAS DE ROPA Y LOCALES
      AdvisoryNoticeModel(
        id: 'locales_comerciales_ropa',
        title: 'Protocolo Comercial: Exclusión en Mercancía, Ropa, Cajas y Trastiendas',
        category: 'Comercios y Locales',
        targetAudience: 'Dueños de Negocios, Encargados de Tienda, Vendedores y Cajeros',
        iconEmoji: '🛍️',
        objective: 'Blindar los locales comerciales contra el ingreso accidental de plagas en cajas de mercancía y concientizar a los empleados sobre el consumo de comida en mostrador y trastienda.',
        problemStatement: 'En boutiques, zapaterías y locales de ropa, la plaga casi nunca se origina en el local, sino que llega "viajando" dentro de cajas de cartón corrugado donde las cucarachas depositan sus huevecillos (ootecas). Además, los empleados suelen comer tacos, tortas o galletas en el mostrador o bodega, dejando envoltorios en papeleras que atraen ratones y cucarachas entre la mercancía.',
        mandatoryRules: [
          'DESEMPAQUE Y DESECHO INMEDIATO DE CARTÓN: Desarmar y sacar las cajas de cartón de proveedores el mismo día. No almacenar cartón corrugado viejo en la trastienda.',
          'PROHIBIDO COMIDA EN MOSTRADOR Y VESTIDORES: Los empleados deben comer en un área designada. Los restos de comida jamás deben arrojarse a los botes papeleros del piso de venta.',
          'RESGUARDAR BOTANAS EN TUPPERS HERMÉTICOS: Si el personal guarda alimentos o café en la trastienda, deben estar en recipientes rígidos sellados; las bolsas de plástico y cajones son roídas fácilmente.',
          'ORDEN Y ELEVACIÓN DE MERCANCÍA: Mantener la ropa y mercancía en estantes elevados a 15 cm del suelo; nunca apilar prendas directamente sobre el piso en rincones oscuros.',
          'LIMPIEZA DE BODEGA Y ZÓCALOS: Barrer pelusa y polvo periódicamente para que el insecticida residual se adhiera al suelo sin ser absorbido por la suciedad.',
        ],
        facilityRecommendations: [
          'Colocar burletes o guardapolvos en puertas de acceso principal y salidas de emergencia que den a banquetas o pasillos de plaza.',
          'Inspeccionar con linterna las esquinas de estanterías y detrás de espejos de probadores.',
          'No aplicar insecticidas caseros que puedan manchar prendas, calzado o telas de exhibición.',
          'En caso de detectar un insecto muerto o desorientado en los primeros días, desecharlo con pala y escoba; es el resultado del efecto desalojo.',
        ],
        technicalDisclaimer: 'Un local comercial impecable protege el valor de su inventario y la reputación de su marca. La combinación del servicio preventivo de EJ Exterminadores con el desecho puntual de cajas de cartón asegura una tienda 100% libre de plagas.',
      ),

      // 3. CASA HABITACIÓN Y RESIDENCIAL
      AdvisoryNoticeModel(
        id: 'residencial_casa_habitacion',
        title: 'Guía Familiar: Trabajo en Equipo y Buenas Prácticas en el Hogar',
        category: 'Casa Habitación y Residencial',
        targetAudience: 'Familias, Propietarios de Vivienda y Personal de Apoyo Doméstico',
        iconEmoji: '🏡',
        objective: 'Informar a la familia cómo evitar fuentes de atracción de plagas en el hogar, el manejo de alimentos de mascotas y las medidas de prevención contra alacranes, ciempiés y arañas.',
        problemStatement: 'Muchos hogares creen que con una sola fumigación ya no debe verse ningún insecto jamás. Sin embargo, platos con comida de mascotas en el suelo por la noche, botes de basura sin tapar, acumulación de cajas en clósets y la falta de guardapolvos en puertas permiten que insectos exteriores (alacranes, cucarachas de drenaje, ciempiés) entren desde la calle o jardines vecinos.',
        mandatoryRules: [
          'ALIMENTO DE MASCOTAS (REGLA DE ORO): NUNCA deje platos con croquetas o comida de perro/gato en el piso durante la noche. Las croquetas son el alimento preferido de ratones y cucarachas.',
          'CERO PLATOS SUCIOS EN EL FREGADERO: No dejar platos con restos de comida ni sartenes remojando en la noche; el agua y la grasa son un banquete para las cucarachas.',
          'NO TRAPEAR ZÓCALOS CON CLORO EN 5 DÍAS: Puede trapear el centro de las habitaciones, pero NO talle las orillas y zócalos para que el producto químico siga matando a los insectos que salgan.',
          'PRIMEROS DÍAS: EFECTO DESALOJO NORMAL: Durante las primeras 72 horas es normal ver insectos salir aturdidos de sus escondites. Es la prueba de que el veneno los está expulsando para morir.',
          'PROHIBIDO EL AEROSOL DE SUPERMERCADO: Los insecticidas de lata apestan, manchan paredes y neutralizan el producto profesional expulsando a las plagas a otras recámaras.',
        ],
        facilityRecommendations: [
          'ALACRANES Y CIEMPIÉS: Vienen de jardines, piedras, escombros o leña. Instale guardapolvos de cepillo en todas las puertas que den a patios, cocheras o calle.',
          'COLADERAS CON TRAMPA O MALLA: Colocar rejillas anti-cucarachas en coladeras de patios, regaderas y baños para impedir su ascenso desde la red de drenaje municipal.',
          'DESPEJAR CLÓSETS Y BAJO CAMAS: No acumular cajas de cartón con ropa vieja o zapatos en el suelo; use cajas organizadoras de plástico con tapa.',
          'PODA Y JARDÍN: Mantener el césped corto y no regar en exceso pegado a los muros de la casa para evitar crear humedad atractiva para insectos rastreros.',
        ],
        technicalDisclaimer: 'Los productos aplicados por EJ Exterminadores son seguros para su familia y mascotas una vez secos (tras el tiempo de reingreso de 2 a 4 horas). La salud de su hogar es un esfuerzo conjunto: nuestro químico protege su casa y los buenos hábitos familiares evitan que la plaga encuentre sustento.',
      ),

      // 4. RESTAURANTES Y COCINAS COMERCIALES
      AdvisoryNoticeModel(
        id: 'restaurantes_cocinas',
        title: 'Protocolo Gastronómico: Inocuidad, Grasa y Manejo Integral en Cocinas',
        category: 'Restaurantes y Alimentos',
        targetAudience: 'Dueños, Gerentes de A&B, Chefs, Cocineros y Personal de Limpieza/Steward',
        iconEmoji: '🍳',
        objective: 'Concientizar al equipo de cocina sobre el impacto letal de la grasa y la humedad acumulada en el control de plagas, y establecer el trabajo mutuo para aprobar auditorías sanitarias.',
        problemStatement: 'La grasa acumulada detrás de estufas, freidoras y motores descompone químicamente los insecticidas en cuestión de días. Ningún producto profesional, por potente que sea, puede erradicar cucarachas o moscas si existen restos de comida caliente debajo de planchas o si se ingresan cajas de huevo y verdura con huevecillos sin previa inspección.',
        mandatoryRules: [
          'DESENGRASAR DIARIAMENTE DETRÁS DE EQUIPOS: Mover mesas y freidoras cada noche para retirar la grasa acumulada; la grasa satura las superficies y neutraliza los insecticidas.',
          'INSPECCIÓN DE VERDURAS Y CAJAS DE HUEVO: Prohibido ingresar cajas de cartón de proveedores directamente a la cocina caliente; trasvasar insumos a taras plásticas lavables.',
          'CERO AGUA ESTANCADA NI PLATOS EN REMOJO: Secar tarjas y pisos al cierre; las cucarachas pueden vivir un mes sin comida, pero mueren en días sin agua.',
          'TALLAR COLADERAS Y TRAMPAS DE GRASA: Aplicar agua caliente y desengrasante en coladeras para romper la biopelícula donde nacen las moscas de drenaje.',
          'ROTACIÓN PEPS Y ELEVACIÓN: Mantener abarrotes a 15 cm del suelo en anaqueles de alambre o plástico; nunca pegar costales a las paredes.',
        ],
        facilityRecommendations: [
          'CORTINAS DE AIRE ACTIVAS: Mantener encendidas las cortinas de aire en accesos de proveedores y comensales en todo momento operativo.',
          'SELLADO DE AZULEJOS Y MESAS: Rellenar con silicón sanitario antihongos las juntas rotas entre azulejos, zócalos y mesas de acero inoxidable.',
          'MANTENIMIENTO DE TRAMPAS DE LUZ UV: No desconectar los equipos de luz ultravioleta para moscas y permitir el reemplazo de placas pegajosas en cada servicio.',
          'EL 70% DE LA INOCUIDAD ES LIMPIEZA: EJ Exterminadores controla la plaga existente con químicos de grado alimenticio autorizados por COFEPRIS, pero el restaurante debe garantizar la higiene diaria.',
        ],
        technicalDisclaimer: 'En la industria restaurantera, el control de plagas es una auditoría diaria. EJ Exterminadores y el personal de cocina forman un solo equipo de defensa para garantizar platillos 100% seguros y proteger la reputación de su negocio.',
      ),

      // 5. INICIO DE PÓLIZA Y CURVA DE CONTROL
      AdvisoryNoticeModel(
        id: 'induccion_nueva_poliza',
        title: 'Inicio de Póliza: Inducción al Control de Plagas y Curva de Efectividad',
        category: 'Pólizas e Industria',
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

      // 6. PROTOCOLO DE VISITAS Y MONITOREO EN PÓLIZAS
      AdvisoryNoticeModel(
        id: 'protocolo_visitas_poliza',
        title: 'Protocolo de Visitas y Monitoreo: Dinámica de Servicio en Pólizas Comerciales',
        category: 'Pólizas e Industria',
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

      // 7. OFICINAS Y CAJONES DE COMIDA
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

      // 8. ALMACENES Y BODEGAS
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

      // 9. AVISO PRE-SERVICIO
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

      // 10. AVISO POST-SERVICIO
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
