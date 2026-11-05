class NoticeDoDontItem {
  final String badPractice;
  final String goodPractice;

  const NoticeDoDontItem({
    required this.badPractice,
    required this.goodPractice,
  });
}

class NoticePhaseItem {
  final String phaseName;
  final String timeFrame;
  final String description;

  const NoticePhaseItem({
    required this.phaseName,
    required this.timeFrame,
    required this.description,
  });
}

class NoticeFaqItem {
  final String question;
  final String answer;

  const NoticeFaqItem({
    required this.question,
    required this.answer,
  });
}

class AdvisoryNoticeModel {
  final String id;
  final String title;
  final String category;
  final String targetAudience;
  final String iconEmoji;
  final String objective;
  final String problemStatement;
  final String regulatoryFramework;
  final List<NoticeDoDontItem> dosAndDonts;
  final List<String> mandatoryRules;
  final List<NoticePhaseItem> biologicalPhases;
  final List<String> facilityRecommendations;
  final List<NoticeFaqItem> faqs;
  final String technicalDisclaimer;

  const AdvisoryNoticeModel({
    required this.id,
    required this.title,
    required this.category,
    required this.targetAudience,
    required this.iconEmoji,
    required this.objective,
    required this.problemStatement,
    required this.regulatoryFramework,
    required this.dosAndDonts,
    required this.mandatoryRules,
    required this.biologicalPhases,
    required this.facilityRecommendations,
    required this.faqs,
    required this.technicalDisclaimer,
  });

  static List<AdvisoryNoticeModel> getAllNotices() {
    return const [
      // 1. INDUSTRIA Y GRANDES COMEDORES
      AdvisoryNoticeModel(
        id: 'industria_comedores',
        title: 'Protocolo Industrial: Comedores, Trabajo en Equipo y Curva del 4º Mes',
        category: 'Pólizas e Industria',
        targetAudience: 'Gerencias de Planta, Recursos Humanos, Comité de Seguridad y Personal de Comedor',
        iconEmoji: '🏭',
        objective: 'Establecer la corresponsabilidad obligatoria entre la empresa y EJ Exterminadores. Si el personal no cumple con la higiene en comedores y áreas operativas, la erradicación total es biológicamente imposible.',
        regulatoryFramework: 'Cumplimiento con NOM-251-SSA1-2009 (Higiene en alimentos), NOM-256-SSA1-2012 (Control de plagas) y Buenas Prácticas de Manufactura (BPM).',
        problemStatement: 'Los comedores industriales y líneas de producción son focos críticos: migajas en pisos, mesas sin limpiar, comida en lockers y basura sin tapa alimentan a miles de insectos. Asimismo, suele ocurrir que durante los primeros 3 meses no se observa ninguna plaga gracias al tratamiento inicial, pero al 4º o 5º mes el personal relaja la higiene o el clima cambia (lluvias/calor), reapareciendo cucarachas, ciempiés o alacranes. La empresa suele asumir erróneamente que "el fumigador falló", cuando en realidad se reactivaron las fuentes de comida y se rompieron las barreras físicas.',
        dosAndDonts: [
          NoticeDoDontItem(
            badPractice: 'Dejar migajas o platos con residuos en mesas y pisos tras los turnos.',
            goodPractice: 'Limpieza exhaustiva inmediata de mesas y vaciado de botes al término de cada turno.',
          ),
          NoticeDoDontItem(
            badPractice: 'Permitir consumir alimentos o guardar botanas en lockers y líneas operativas.',
            goodPractice: 'Consumo exclusivo en comedor autorizado; los roedores tienen olfato hiperdesarrollado.',
          ),
          NoticeDoDontItem(
            badPractice: 'Asumir falla del servicio si surgen insectos al 4º mes sin auditar causas.',
            goodPractice: 'Inspeccionar tarimas nuevas de proveedores, sellos perimetrales y lluvias de temporada.',
          ),
          NoticeDoDontItem(
            badPractice: 'Rociar insecticidas comerciales de lata en áreas de trabajo o comedores.',
            goodPractice: 'Reportar puntos de avistamiento a EJ Exterminadores para aplicar refuerzo focalizado.',
          ),
        ],
        mandatoryRules: [
          'COMEDORES: LIMPIEZA INMEDIATA: Retirar migajas, limpiar mesas tras cada turno y vaciar botes de basura antes del cierre nocturno; un solo gramo de comida sustenta a decenas de cucarachas.',
          'PROHIBIDO COMER FUERA DEL COMEDOR: Cero alimentos en líneas de producción, lockers o estaciones de trabajo. Los roedores y cucarachas tienen olfato hiperdesarrollado y viajarán hasta donde haya comida.',
          'EL MITO DEL 4º MES (POR QUÉ REAPARECEN): Si tras meses sin plagas nota insectos, NO es ineficacia del químico: se debe a ingresos en tarimas nuevas, relajamiento de limpieza o cambios de clima (calor/lluvias que empujan alacranes y ciempiés al interior buscando refugio).',
          'PROHIBIDO EL USO DE AEROSOLES CASEROS: Los insecticidas de supermercado actúan como repelentes que dispersan los insectos a áreas limpias y anulan la residualidad de los productos profesionales.',
          'NO LAVAR ZÓCALOS PERIMETRALES: No tallar con cloro ni desengrasante la franja inferior de muros durante 5 días posteriores a la visita; ahí reside la barrera química protectora.',
        ],
        biologicalPhases: [
          NoticePhaseItem(
            phaseName: 'Fase 1: Choque y Desalojo',
            timeFrame: 'Días 1 a 7',
            description: 'Aplicación de choque que penetra grietas profundas, motores y registros. Los insectos adultos salen desorientados para morir en campo abierto.',
          ),
          NoticePhaseItem(
            phaseName: 'Fase 2: Corte de Ciclo Reproductivo',
            timeFrame: 'Semanas 2 a 4',
            description: 'La película química residual perimetral y los cebos reguladores de crecimiento eliminan a las ninfas que nacen de huevecillos (ootecas).',
          ),
          NoticePhaseItem(
            phaseName: 'Fase 3: Estabilidad y Umbral Cero',
            timeFrame: 'Meses 2 y 3',
            description: 'Población abatida al 100%. Las estaciones cebaderas y trampas de monitoreo mantienen el cordón de bioseguridad activo.',
          ),
          NoticePhaseItem(
            phaseName: 'Fase 4: Punto Crítico del 4º Mes',
            timeFrame: 'Mes 4 en adelante',
            description: 'Riesgo de relajamiento higiénico o ingreso pasivo en tarimas de proveedores. Requiere reforzar la inspección y rotación de químicos.',
          ),
        ],
        facilityRecommendations: [
          'GUARDAPOLVOS HERMÉTICOS: Instalar cepillos o hules bajo todas las puertas exteriores; los alacranes y ciempiés ingresan caminando desde jardines y patios por rendijas de menos de 3 mm.',
          'CONTROL DE TARIMAS Y EMBALAJES: Inspeccionar tarimas de madera y cajas de cartón que entran de proveedores; el 80% de reinfestaciones industriales ingresan por transporte pasivo de mercancía.',
          'SELLADO DE PASACABLES Y GRIETAS: Tapar con silicón o espuma expansiva las perforaciones eléctricas y tuberías donde se ocultan nidos.',
          'TRABAJO EN EQUIPO VITAL: El servicio químico aporta el 50% del éxito; el restante 50% depende de la higiene del personal y la exclusión física del inmueble.',
        ],
        faqs: [
          NoticeFaqItem(
            question: '¿Por qué al 4º mes volvieron a aparecer insectos si todo iba perfecto?',
            answer: 'En los primeros 3 meses el químico abatió la población local. Al 4º mes suele coincidir el ingreso de tarimas de madera contaminadas de proveedores externos, acumulación de cartón o lluvias/calor extremo que desplazan fauna silvestre (alacranes, ciempiés) hacia el interior de la planta. No es falla química, sino nueva introducción externa.',
          ),
          NoticeFaqItem(
            question: '¿Por qué no podemos aplicar insecticida de lata (Raid, H24) en el comedor?',
            answer: 'Los aerosoles de supermercado contienen solventes repelentes que dispersan las plagas hacia ductos y plafones, neutralizan la residualidad de los productos profesionales y provocan que las cucarachas rechacen los cebos en gel de alta apetencia.',
          ),
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
        regulatoryFramework: 'Cumplimiento de la NOM-256-SSA1-2012 y Normas de Calidad de Inventario y Almacenaje Comercial.',
        problemStatement: 'En boutiques, zapaterías y locales de ropa, la plaga casi nunca se origina en el local, sino que llega "viajando" dentro de cajas de cartón corrugado donde las cucarachas depositan sus huevecillos (ootecas). Además, los empleados suelen comer tacos, tortas o galletas en el mostrador o bodega, dejando envoltorios en papeleras que atraen ratones y cucarachas entre la mercancía.',
        dosAndDonts: [
          NoticeDoDontItem(
            badPractice: 'Acumular cajas de cartón corrugado viejas en trastienda o probadores.',
            goodPractice: 'Desempacar y desechar el cartón de proveedores el mismo día de su llegada.',
          ),
          NoticeDoDontItem(
            badPractice: 'Comer botanas o dejar tazas de café sobre mostradores y cajas de cobro.',
            goodPractice: 'Comer en área designada y depositar basura en contenedores con tapa y bolsa.',
          ),
          NoticeDoDontItem(
            badPractice: 'Tener ropa o mercancía estibada directamente sobre el suelo en rincones.',
            goodPractice: 'Elevar mercancía al menos 15 cm del piso en anaqueles o tarimas plásticas.',
          ),
          NoticeDoDontItem(
            badPractice: 'Rociar insecticida doméstico que pueda manchar prendas de exhibición.',
            goodPractice: 'Permitir la acción del gel cucarachicida inodoro y no manchante de EJ Exterminadores.',
          ),
        ],
        mandatoryRules: [
          'DESEMPAQUE Y DESECHO INMEDIATO DE CARTÓN: Desarmar y sacar las cajas de cartón de proveedores el mismo día. No almacenar cartón corrugado viejo en la trastienda.',
          'PROHIBIDO COMIDA EN MOSTRADOR Y VESTIDORES: Los empleados deben comer en un área designada. Los restos de comida jamás deben arrojarse a los botes papeleros del piso de venta.',
          'RESGUARDAR BOTANAS EN TUPPERS HERMÉTICOS: Si el personal guarda alimentos o café en la trastienda, deben estar en recipientes rígidos sellados; las bolsas de plástico y cajones son roídas fácilmente.',
          'ORDEN Y ELEVACIÓN DE MERCANCÍA: Mantener la ropa y mercancía en estantes elevados a 15 cm del suelo; nunca apilar prendas directamente sobre el piso en rincones oscuros.',
          'LIMPIEZA DE BODEGA Y ZÓCALOS: Barrer pelusa y polvo periódicamente para que el insecticida residual se adhiera al suelo sin ser absorbido por la suciedad.',
        ],
        biologicalPhases: [
          NoticePhaseItem(
            phaseName: 'Fase 1: Diagnóstico de Ingresos',
            timeFrame: 'Semana 1',
            description: 'Inspección de trastienda, probadores y áreas de empaque. Colocación de gel cucarachicida en bisagras y zócalos sin manchar telas.',
          ),
          NoticePhaseItem(
            phaseName: 'Fase 2: Trampeo y Monitoreo',
            timeFrame: 'Semanas 2 y 3',
            description: 'Instalación de trampas de goma con atrayente feromonal para capturar cualquier insecto introducido en cajas de paquetería.',
          ),
          NoticePhaseItem(
            phaseName: 'Fase 3: Protección Continua',
            timeFrame: 'Mantenimiento Mensual',
            description: 'Blindaje inodoro y discreto que protege el inventario sin interrumpir la atención a clientes.',
          ),
        ],
        facilityRecommendations: [
          'Colocar burletes o guardapolvos en puertas de acceso principal y salidas de emergencia que den a banquetas o pasillos de plaza.',
          'Inspeccionar con linterna las esquinas de estanterías y detrás de espejos de probadores.',
          'No aplicar insecticidas caseros que puedan manchar prendas, calzado o telas de exhibición.',
          'En caso de detectar un insecto muerto o desorientado en los primeros días, desecharlo con pala y escoba; es el resultado del efecto desalojo.',
        ],
        faqs: [
          NoticeFaqItem(
            question: '¿Por qué tenemos cucarachas si no vendemos alimentos?',
            answer: 'Las cucarachas alemanas adoran el almidón y pegamento del cartón corrugado, y depositan allí sus cápsulas de huevecillos. El 90% de las infestaciones en tiendas de ropa llegan como polizones dentro de las cajas de paquetería y proveedores.',
          ),
          NoticeFaqItem(
            question: '¿El químico puede manchar la ropa o dejar olor desagradable para los clientes?',
            answer: 'No. En tiendas comerciales usamos geles técnicos inodoros y microencapsulados que no manchan telas, calzado ni exhibidores, manteniendo un ambiente limpio y profesional.',
          ),
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
        regulatoryFramework: 'Cumplimiento con NOM-256-SSA1-2012 y Criterios Sanitarios de Bioseguridad en Hogares de COFEPRIS.',
        problemStatement: 'Muchos hogares creen que con una sola fumigación ya no debe verse ningún insecto jamás. Sin embargo, platos con comida de mascotas en el suelo por la noche, botes de basura sin tapar, acumulación de cajas en clósets y la falta de guardapolvos en puertas permiten que insectos exteriores (alacranes, cucarachas de drenaje, ciempiés) entren desde la calle o jardines vecinos.',
        dosAndDonts: [
          NoticeDoDontItem(
            badPractice: 'Dejar platos de croquetas de perro o gato en el piso durante la noche.',
            goodPractice: 'Levantar y tapar la comida de mascotas antes de dormir; es el imán #1 de roedores.',
          ),
          NoticeDoDontItem(
            badPractice: 'Dejar sartenes grasosos o platos sucios remojando toda la noche.',
            goodPractice: 'Lavar los trastes y secar el fregadero al terminar la cena; las plagas buscan humedad.',
          ),
          NoticeDoDontItem(
            badPractice: 'Trapear zócalos con cloro y pinol al día siguiente de la fumigación.',
            goodPractice: 'Trapear solo el centro de habitaciones; dejar 5 días intacta la orilla perimetral.',
          ),
          NoticeDoDontItem(
            badPractice: 'Dejar rendijas bajo puertas que dan a cocheras, patios o jardines.',
            goodPractice: 'Instalar guardapolvos de cepillo; los alacranes entran por rendijas de 3 milímetros.',
          ),
        ],
        mandatoryRules: [
          'ALIMENTO DE MASCOTAS (REGLA DE ORO): NUNCA deje platos con croquetas o comida de perro/gato en el piso durante la noche. Las croquetas son el alimento preferido de ratones y cucarachas.',
          'CERO PLATOS SUCIOS EN EL FREGADERO: No dejar platos con restos de comida ni sartenes remojando en la noche; el agua y la grasa son un banquete para las cucarachas.',
          'NO TRAPEAR ZÓCALOS CON CLORO EN 5 DÍAS: Puede trapear el centro de las habitaciones, pero NO talle las orillas y zócalos para que el producto químico siga matando a los insectos que salgan.',
          'PRIMEROS DÍAS: EFECTO DESALOJO NORMAL: Durante las primeras 72 horas es normal ver insectos salir aturdidos de sus escondites. Es la prueba de que el veneno los está expulsando para morir.',
          'PROHIBIDO EL AEROSOL DE SUPERMERCADO: Los insecticidas de lata apestan, manchan paredes y neutralizan el producto profesional expulsando a las plagas a otras recámaras.',
        ],
        biologicalPhases: [
          NoticePhaseItem(
            phaseName: 'Fase 1: Efecto Desalojo Inmediato',
            timeFrame: 'Primeras 72 horas',
            description: 'El insecticida estimula el sistema nervioso de plagas ocultas tras estufas, clósets y baños, obligándolas a salir aturdidas a campo abierto.',
          ),
          NoticePhaseItem(
            phaseName: 'Fase 2: Acción Residual Protectora',
            timeFrame: 'Días 4 a 21',
            description: 'La película activa en zócalos elimina a las ninfas jóvenes recién nacidas de huevecillos antes de que alcancen madurez reproductiva.',
          ),
          NoticePhaseItem(
            phaseName: 'Fase 3: Hogar Blindado y Confort',
            timeFrame: 'Día 22 en adelante',
            description: 'Espacio bioseguro para su familia. Las barreras perimetrales impiden que alacranes o cucarachas del drenaje municipal colonicen su hogar.',
          ),
        ],
        facilityRecommendations: [
          'ALACRANES Y CIEMPIÉS: Vienen de jardines, piedras, escombros o leña. Instale guardapolvos de cepillo en todas las puertas que den a patios, cocheras o calle.',
          'COLADERAS CON TRAMPA O MALLA: Colocar rejillas anti-cucarachas en coladeras de patios, regaderas y baños para impedir su ascenso desde la red de drenaje municipal.',
          'DESPEJAR CLÓSETS Y BAJO CAMAS: No acumular cajas de cartón con ropa vieja o zapatos en el suelo; use cajas organizadoras de plástico con tapa.',
          'PODA Y JARDÍN: Mantener el césped corto y no regar en exceso pegado a los muros de la casa para evitar crear humedad atractiva para insectos rastreros.',
        ],
        faqs: [
          NoticeFaqItem(
            question: '¿Es peligroso para mis niños o mascotas el producto aplicado?',
            answer: 'Una vez que el producto seca (tras el tiempo de reingreso de 2 a 4 horas), se adhiere a nivel molecular a las superficies. Es seguro para niños y mascotas porque está formulado específicamente para el metabolismo de sangre fría de los insectos.',
          ),
          NoticeFaqItem(
            question: '¿Por qué vi insectos vivos a los dos días de haber fumigado?',
            answer: 'Es el esperado "efecto desalojo". El químico penetra los nidos profundos y los insectos salen drogados o desorientados hacia el centro del cuarto para morir en cuestión de horas. Basta con barrerlos y desecharlos.',
          ),
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
        regulatoryFramework: 'Cumplimiento estricto con NOM-251-SSA1-2009 (Prácticas de higiene en A&B), Distintivo H y Auditorías COFEPRIS.',
        problemStatement: 'La grasa acumulada detrás de estufas, freidoras y motores descompone químicamente los insecticidas en cuestión de días. Ningún producto profesional, por potente que sea, puede erradicar cucarachas o moscas si existen restos de comida caliente debajo de planchas o si se ingresan cajas de huevo y verdura con huevecillos sin previa inspección.',
        dosAndDonts: [
          NoticeDoDontItem(
            badPractice: 'Permitir acumulación de cochambre y grasa detrás de freidoras y planchas.',
            goodPractice: 'Mover equipos y desengrasar a fondo a diario; la grasa neutraliza los químicos.',
          ),
          NoticeDoDontItem(
            badPractice: 'Ingresar cajas de huevo o cartón de verdura directo a la línea de cocina.',
            goodPractice: 'Trasvasar insumos a taras plásticas lavables en la zona de recepción exterior.',
          ),
          NoticeDoDontItem(
            badPractice: 'Dejar charcos de agua estancada o pisos empapados en el cierre nocturno.',
            goodPractice: 'Secar tarjas y pisos al cierre; las plagas mueren en pocos días sin agua.',
          ),
          NoticeDoDontItem(
            badPractice: 'Apagar o desenchufar las trampas de luz UV para moscas durante la noche.',
            goodPractice: 'Mantener lámparas UV encendidas 24/7 y reemplazar láminas adhesivas puntualmente.',
          ),
        ],
        mandatoryRules: [
          'DESENGRASAR DIARIAMENTE DETRÁS DE EQUIPOS: Mover mesas y freidoras cada noche para retirar la grasa acumulada; la grasa satura las superficies y neutraliza los insecticidas.',
          'INSPECCIÓN DE VERDURAS Y CAJAS DE HUEVO: Prohibido ingresar cajas de cartón de proveedores directamente a la cocina caliente; trasvasar insumos a taras plásticas lavables.',
          'CERO AGUA ESTANCADA NI PLATOS EN REMOJO: Secar tarjas y pisos al cierre; las cucarachas pueden vivir un mes sin comida, pero mueren en días sin agua.',
          'TALLAR COLADERAS Y TRAMPAS DE GRASA: Aplicar agua caliente y desengrasante en coladeras para romper la biopelícula donde nacen las moscas de drenaje.',
          'ROTACIÓN PEPS Y ELEVACIÓN: Mantener abarrotes a 15 cm del suelo en anaqueles de alambre o plástico; nunca pegar costales a las paredes.',
        ],
        biologicalPhases: [
          NoticePhaseItem(
            phaseName: 'Fase 1: Saneamiento de Focos Críticos',
            timeFrame: 'Semanas 1 y 2',
            description: 'Tratamiento profundo con geles de alta apetencia en motores de refrigeradores, campanas y ductos de extracción.',
          ),
          NoticePhaseItem(
            phaseName: 'Fase 2: Quiebre Poblacional',
            timeFrame: 'Semanas 3 y 4',
            description: 'Monitoreo de ninfas recién nacidas y desinfección biológica en trampas de grasa para erradicar moscas phoridae.',
          ),
          NoticePhaseItem(
            phaseName: 'Fase 3: Mantenimiento Distintivo H',
            timeFrame: 'Continuo',
            description: 'Inspecciones periódicas, hojas de seguridad COFEPRIS al día y bitácoras sanitarias listas para cualquier auditoría.',
          ),
        ],
        facilityRecommendations: [
          'CORTINAS DE AIRE ACTIVAS: Mantener encendidas las cortinas de aire en accesos de proveedores y comensales en todo momento operativo.',
          'SELLADO DE AZULEJOS Y MESAS: Rellenar con silicón sanitario antihongos las juntas rotas entre azulejos, zócalos y mesas de acero inoxidable.',
          'MANTENIMIENTO DE TRAMPAS DE LUZ UV: No desconectar los equipos de luz ultravioleta para moscas y permitir el reemplazo de placas pegajosas en cada servicio.',
          'EL 70% DE LA INOCUIDAD ES LIMPIEZA: EJ Exterminadores controla la plaga existente con químicos de grado alimenticio autorizados por COFEPRIS, pero el restaurante debe garantizar la higiene diaria.',
        ],
        faqs: [
          NoticeFaqItem(
            question: '¿Por qué la grasa acumulada arruina la fumigación profesional?',
            answer: 'La grasa caliente forma una capa aceitosa impermeable que recubre el insecticida y lo desactiva químicamente en menos de 48 horas. Además, emite olores que saturan el ambiente y hacen que las cucarachas ignoren los cebos técnicos.',
          ),
          NoticeFaqItem(
            question: '¿Podemos usar aerosoles de supermercado si vemos una cucaracha en el turno?',
            answer: 'Jamás. En cocinas comerciales está estrictamente prohibido por la NOM-251 por riesgo grave de contaminación química de alimentos y clausura por salubridad.',
          ),
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
        regulatoryFramework: 'Protocolo sustentado en la NOM-256-SSA1-2012 y principios científicos del Manejo Integrado de Plagas (MIP).',
        problemStatement: 'Existe la falsa expectativa de que con la primera aplicación los insectos "desaparecen al instante por arte de magia". En la realidad técnica, los insecticidas de choque y residuales provocan un "efecto de desalojo" (flushing) donde las plagas ocultas salen de sus refugios y se muestran más activas o aturdidas antes de morir. Asimismo, ningún producto químico destruye las cápsulas de huevecillos (ootecas); la erradicación total requiere romper el ciclo reproductivo mediante aplicaciones programadas y seguimiento técnico constante.',
        dosAndDonts: [
          NoticeDoDontItem(
            badPractice: 'Esperar erradicación total milagrosa en las primeras 24 horas.',
            goodPractice: 'Entender que el proceso biológico de corte reproductivo toma de 2 a 3 semanas.',
          ),
          NoticeDoDontItem(
            badPractice: 'Alarmarse o pensar que "hay más plaga" al ver insectos salir los primeros días.',
            goodPractice: 'Barrer y desechar los insectos aturdidos; es la señal del efecto desalojo activo.',
          ),
          NoticeDoDontItem(
            badPractice: 'Cancelar o posponer visitas programadas si ya no se observa plaga.',
            goodPractice: 'Mantener las fechas calendarizadas para cortar la eclosión de nuevos huevecillos.',
          ),
          NoticeDoDontItem(
            badPractice: 'Aplicar insecticidas caseros creyendo que ayudan al tratamiento profesional.',
            goodPractice: 'Cero aerosoles; neutralizan la química profesional y ahuyentan las plagas a otras áreas.',
          ),
        ],
        mandatoryRules: [
          'DÍAS 1 AL 3 - EFECTO DESALOJO (TOTALMENTE NORMAL): Es normal ver insectos salir desorientados o convulsionando. No significa que "haya más plaga", sino que el químico penetró sus nidos expulsándolos hacia el exterior para su muerte.',
          'PROHIBIDO APLICAR INSECTICIDAS CASEROS (AEROSOLES): Los insecticidas de supermercado tienen efecto repelente que arruina el tratamiento profesional, ahuyenta la plaga hacia otras áreas y neutraliza nuestros cebos.',
          'NO LAVAR NI TRAPEAR ZÓCALOS POR 5 DÍAS: No trapee con cloro ni desengrasante las orillas y zócalos donde se colocó la película insecticida para no retirar la barrera química de protección.',
          'DISPOSICIÓN HIGIÉNICA DE INSECTOS MUERTOS: Barrer diariamente los insectos caídos y depositarlos en bolsas de basura cerradas en contenedores exteriores para evitar contaminación.',
          'REPORTE DE INCIDENCIAS SIN ALARMA: Si observa insectos tras la aplicación, anote la zona exacta y compártala con nuestro técnico para focalizar el refuerzo en la siguiente visita programada.',
        ],
        biologicalPhases: [
          NoticePhaseItem(
            phaseName: 'Fase 1: Choque y Desalojo',
            timeFrame: 'Días 1 a 3',
            description: 'Penetración en microrefugios. Los insecticidas excitan el sistema nervioso de adultos forzándolos a abandonar nidos y morir en el piso.',
          ),
          NoticePhaseItem(
            phaseName: 'Fase 2: Quiebre de Generación',
            timeFrame: 'Días 4 a 21',
            description: 'Acción de la película residual y reguladores de crecimiento (IGR) sobre ninfas recién nacidas, impidiendo que alcancen la madurez reproductiva.',
          ),
          NoticePhaseItem(
            phaseName: 'Fase 3: Umbral Cero y Monitoreo',
            timeFrame: 'Mes 2 en adelante',
            description: 'Población abatida. Inspecciones periódicas y cebado preventivo para mantener un blindaje higiénico continuo.',
          ),
          NoticePhaseItem(
            phaseName: 'Fase 4: Curva Estacional y Refuerzos',
            timeFrame: 'Mes 4 a 6',
            description: 'Vigilancia ante cambios de clima (calor/lluvias) e ingreso de nuevos proveedores para evitar reinfestaciones pasivas.',
          ),
        ],
        facilityRecommendations: [
          'FASE 1 - CHOQUE Y DESALOJO (Semana 1): Eliminación masiva de adultos visibles y expulsión de refugios profundos.',
          'FASE 2 - ROMPIMIENTO DEL CICLO BIOLÓGICO (Semanas 2 y 3): Control progresivo de ninfas nacidas de huevecillos antes de su madurez reproductiva.',
          'FASE 3 - CONTROL TOTAL Y MANTENIMIENTO (Mes 2 en adelante): Mantenimiento del cordón sanitario y monitoreo mediante cebos y trampas.',
          'EL 50% DEL ÉXITO ES LA HIGIENE: Es indispensable reparar fugas de humedad, desechar cajas de cartón innecesarias y no dejar comida expuesta en cajones o escritorios.',
        ],
        faqs: [
          NoticeFaqItem(
            question: '¿Por qué los químicos no matan los huevecillos de las cucarachas?',
            answer: 'Las cucarachas protegen sus huevecillos en estuches queratinosos llamados ootecas, los cuales son impermeables a los insecticidas. Por eso es indispensable la póliza periódica: para eliminar a las ninfas jóvenes en cuanto eclosionan, antes de que puedan poner nuevos huevecillos.',
          ),
          NoticeFaqItem(
            question: '¿Qué significa que el control de plagas no es magia sino ciencia?',
            answer: 'Significa que los químicos eliminan insectos, pero no sellan puertas ni lavan platos. Si el inmueble mantiene comida al alcance y puertas abiertas, seguirán entrando plagas desde el exterior. El control efectivo requiere técnica profesional más disciplina de limpieza del cliente.',
          ),
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
        regulatoryFramework: 'Cumplimiento con NOM-256-SSA1-2012 y Lineamientos de Auditoría de Sanidad y Bitácoras Técnicas.',
        problemStatement: 'Las áreas cerradas bajo llave, falta de autorización de acceso en caseta o la reubicación no informada de trampas de monitoreo interrumpen la cadena de protección y dejan puntos ciegos susceptibles a plagas.',
        dosAndDonts: [
          NoticeDoDontItem(
            badPractice: 'Dejar cuartos de máquinas, subestaciones o almacenes cerrados con llave.',
            goodPractice: 'Contar con llaves o personal asignado para permitir acceso total al técnico.',
          ),
          NoticeDoDontItem(
            badPractice: 'Mover, patear o cubrir las trampas y cebaderos colocados en muros.',
            goodPractice: 'Respetar la ubicación de cada trampa numerada y geolocalizada en el croquis.',
          ),
          NoticeDoDontItem(
            badPractice: 'Firmar el reporte de servicio con prisas sin validar las acciones realizadas.',
            goodPractice: 'Acompañar al técnico, validar áreas tratadas y firmar en pantalla con S-Pen.',
          ),
          NoticeDoDontItem(
            badPractice: 'Guardarse avistamientos de plagas hasta la siguiente visita rutinaria.',
            goodPractice: 'Avisar de inmediato vía WhatsApp para programar refuerzos oportunos si se requiere.',
          ),
        ],
        mandatoryRules: [
          'FACILITAR ACCESO A ZONAS CRÍTICAS: Cuartos de máquinas, subestaciones, almacenes, cocinas y registros de drenaje deben estar accesibles para la inspección del técnico.',
          'PROHIBIDO MOVER O MANIPULAR TRAMPAS: Las estaciones de cebado y trampas mecánicas están numeradas y geolocalizadas según el croquis técnico; no las mueva ni bloquee con cajas o tarimas.',
          'REVISIÓN Y FIRMA DE CONFORMIDAD: Al finalizar la visita, el responsable del inmueble debe validar las acciones realizadas y firmar el reporte digital de servicio.',
          'REPORTAR INCIDENCIAS AL TÉCNICO: Notificar si se detectaron roedores, insectos o si hubo ingresos recientes de mercancía sospechosa desde la última visita.',
        ],
        biologicalPhases: [
          NoticePhaseItem(
            phaseName: 'Paso 1: Inspección y Diagnóstico',
            timeFrame: 'Inicio de visita',
            description: 'Revisión física de estaciones cebaderas, consumo de raticida, trampas de luz UV y detección de nuevas vulnerabilidades físicas.',
          ),
          NoticePhaseItem(
            phaseName: 'Paso 2: Aplicación y Rotación Química',
            timeFrame: 'Desarrollo',
            description: 'Aspersión perimetral y cebado focalizado utilizando rotación de familias químicas para evitar resistencia genética de plagas.',
          ),
          NoticePhaseItem(
            phaseName: 'Paso 3: Emisión de Certificado y Reporte',
            timeFrame: 'Cierre',
            description: 'Generación instantánea de reporte foliado en PDF con firma autógrafa digital, dosis aplicadas y recomendaciones de mejora.',
          ),
        ],
        facilityRecommendations: [
          'Inspección física y reposición de cebos rodenticidas en todo el perímetro exterior en cada visita programada.',
          'Revisión de trampas de luz UV para insectos voladores y cambio periódico de láminas engomadas.',
          'Generación y entrega inmediata del reporte digital con folio oficial y certificación sanitaria.',
          'Monitoreo continuo de bitácora para auditorías de calidad o inspecciones de salubridad.',
        ],
        faqs: [
          NoticeFaqItem(
            question: '¿Por qué rotan los productos químicos en las visitas programadas?',
            answer: 'La rotación entre piretroides, neonicotinoides e inhibidores de síntesis de quitina evita que las plagas desarrollen inmunidad biológica, garantizando efectividad letal prolongada.',
          ),
          NoticeFaqItem(
            question: '¿Cómo demuestro el servicio ante una inspección de salubridad o auditoría?',
            answer: 'Cada visita genera un reporte técnico digital con folio único, fecha, lista de químicos COFEPRIS y firma electrónica, el cual cuenta con plena validez legal y probatoria.',
          ),
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
        regulatoryFramework: 'Norma Oficial Mexicana NOM-256-SSA1-2012 y Normas de Higiene en Centros de Trabajo (STPS).',
        problemStatement: 'Se ha detectado la presencia de restos de comida, paquetes abiertos de galletas, panecillos, frituras y dulces almacenados en cajones y escritorios de empleados. El agudo olfato de los roedores detecta estos alimentos a gran distancia y un cajón de madera o metal no representa ninguna barrera hermética. Cuando el personal deja comida accesible, los roedores ignoran los cebos técnicos colocados por el servicio de fumigación.',
        dosAndDonts: [
          NoticeDoDontItem(
            badPractice: 'Guardar galletas, papitas, fruta o dulces abiertos en cajones o archiveros.',
            goodPractice: 'Snacks guardados en tuppers plásticos rígidos con cierre hermético.',
          ),
          NoticeDoDontItem(
            badPractice: 'Tirar cáscaras, restos de comida o vasos con café en botes papeleros de escritorio.',
            goodPractice: 'Desechar todo residuo orgánico EXCLUSIVAMENTE en botes de cocina con bolsa y pedal.',
          ),
          NoticeDoDontItem(
            badPractice: 'Dejar migajas o platos sucios sobre el teclado y escritorio al terminar la jornada.',
            goodPractice: 'Limpiar el escritorio con toallita húmeda al retirarse por la tarde.',
          ),
          NoticeDoDontItem(
            badPractice: 'Tener cajas de archivo muerto o mochilas en el piso pegadas a ductos.',
            goodPractice: 'Mantener canaletas y pasajes despejados para que actúen las trampas de monitoreo.',
          ),
        ],
        mandatoryRules: [
          'PROHIBIDO almacenar alimentos abiertos, galletas, botanas o restos de comida en cajones, gavetas o archiveros.',
          'Si un empleado consume alimentos en su estación de trabajo, todo snack restante DEBE guardarse en recipientes de plástico rígido o vidrio con tapa hermética (tuppers).',
          'Los restos de comida, envolturas grasientas y cáscaras deben desecharse EXCLUSIVAMENTE en los botes de basura del comedor o cocina de la empresa (con bolsa y pedal).',
          'PROHIBIDO arrojar restos de comida o bebidas dulces en los botes de papelera debajo del escritorio.',
          'Al finalizar la jornada laboral, el escritorio debe quedar completamente libre de migajas, tazas de café sucias o envolturas.',
        ],
        biologicalPhases: [
          NoticePhaseItem(
            phaseName: 'Fase 1: Bloqueo de Rutas',
            timeFrame: 'Días 1 a 5',
            description: 'Inspección de plafones falsos y canaletas eléctricas. Instalación de trampas de impacto y gomas en rutas de tránsito ocultas.',
          ),
          NoticePhaseItem(
            phaseName: 'Fase 2: Cebado de Seguridad',
            timeFrame: 'Días 6 a 15',
            description: 'Colocación de cebos rodenticidas de segunda generación en estaciones cerradas inviolables en cuartos de servidores y archivos.',
          ),
          NoticePhaseItem(
            phaseName: 'Fase 3: Mantenimiento Preventivo',
            timeFrame: 'Continuo',
            description: 'Inspecciones periódicas para garantizar que los roedores no aniden ni dañen cables de red o equipos de cómputo.',
          ),
        ],
        facilityRecommendations: [
          'El personal de limpieza debe retirar diariamente y sin excepción las bolsas de basura de todas las áreas antes de cerrar las oficinas por la noche.',
          'Realizar inspecciones periódicas aleatorias de cajones y gavetas por parte de supervisión o Recursos Humanos.',
          'Sellar holguras y pasacables en pisos falsos o canaletas de red eléctrica por donde transitan los roedores.',
        ],
        faqs: [
          NoticeFaqItem(
            question: '¿Cómo suben los ratones a pisos altos de un edificio corporativo?',
            answer: 'Los roedores trepan tuberías verticales, ductos de cableado estructurado y canaletas de aire acondicionado con gran facilidad. Se desplazan de noche en total silencio buscando escritorios con restos de comida.',
          ),
          NoticeFaqItem(
            question: '¿Por qué no caen en las trampas si hay trampas puestas?',
            answer: 'Los roedores desconfían por instinto de objetos nuevos (neofobia). Si encuentran galletas o pan dulce en un cajón, comerán su alimento preferido y jamás se acercarán a una trampa de control.',
          ),
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
        regulatoryFramework: 'NOM-256-SSA1-2012, Estándares de Almacenamiento AIB International y Criterios de Protección Civil.',
        problemStatement: 'Las tarimas pegadas a los muros y cortinas metálicas con holguras en el suelo permiten el libre tránsito y reproducción oculta de roedores y alacranes entre la mercancía almacenada.',
        dosAndDonts: [
          NoticeDoDontItem(
            badPractice: 'Pegar racks y tarimas de madera directamente contra los muros perimetrales.',
            goodPractice: 'Mantener un pasillo perimetral de inspección de al menos 45 cm libre y pintado.',
          ),
          NoticeDoDontItem(
            badPractice: 'Dejar cortinas de andén abiertas cuando no se esté realizando maniobra de carga.',
            goodPractice: 'Cortinas cerradas con guardapolvos de cepillo industrial ajustados al piso.',
          ),
          NoticeDoDontItem(
            badPractice: 'Acumular tarimas rotas, madera húmeda o cartón viejo dentro de la nave.',
            goodPractice: 'Área de mermas y reciclaje delimitada en patio exterior fuera de la nave principal.',
          ),
          NoticeDoDontItem(
            badPractice: 'Tapar o bloquear las estaciones cebaderas con tarimas o cajas estibadas.',
            goodPractice: 'Dejar libre acceso a cada estación cebadera numerada para revisión quincenal.',
          ),
        ],
        mandatoryRules: [
          'REGLA DE ORO DE 45 CM: Mantener un pasillo perimetral de inspección de al menos 45 cm libre entre las tarimas y cualquier pared perimetral.',
          'Rotación de inventarios estricta (PEPS: Primeras Entradas, Primeras Salidas) para evitar que mercancía quede estancada por meses en rincones.',
          'PROHIBIDO almacenar tarimas rotas, tarimas de madera húmeda o cartón de desecho dentro de la nave principal.',
          'No obstaculizar ni cubrir las estaciones de cebado o trampas mecánicas colocadas por EJ Exterminadores en las paredes.',
        ],
        biologicalPhases: [
          NoticePhaseItem(
            phaseName: 'Anillo 1: Cerco Perimetral Exterior',
            timeFrame: 'Continuo',
            description: 'Cebaderos de alta resistencia anclados en bardas perimetrales para abatir roedores de predios vecinos antes de que lleguen a la nave.',
          ),
          NoticePhaseItem(
            phaseName: 'Anillo 2: Andenes y Exclusión',
            timeFrame: 'Continuo',
            description: 'Guardapolvos de cepillo en cortinas metálicas y trampas de golpe en zonas de carga y descarga de camiones.',
          ),
          NoticePhaseItem(
            phaseName: 'Anillo 3: Nave y Racks Interiores',
            timeFrame: 'Continuo',
            description: 'Trampas mecánicas de captura viva y láminas adhesivas sin químicos tóxicos expuestos en zona de producto terminado.',
          ),
        ],
        facilityRecommendations: [
          'Instalar guardapolvos de cepillo industrial de alta densidad en la parte inferior de todas las cortinas metálicas de andén.',
          'Sellar orificios alrededor de tuberías de desagüe pluvial y canalizaciones eléctricas.',
          'Mantener podada la maleza y libre de escombros una franja de 1 metro alrededor de todo el exterior de la bodega.',
        ],
        faqs: [
          NoticeFaqItem(
            question: '¿Por qué es indispensable la franja de 45 cm entre tarimas y paredes?',
            answer: 'Los roedores y alacranes se mueven guiados por el contacto de sus bigotes con las paredes (tigmotaxis). Si las tarimas están pegadas al muro, encuentran túneles perfectos para anidar sin ser vistos. El pasillo libre los expone directamente a las trampas.',
          ),
          NoticeFaqItem(
            question: '¿Se puede usar veneno suelto dentro de una nave de materias primas o alimentos?',
            answer: 'No. Las normativas de inocuidad prohíben estrictamente cebos tóxicos expuestos en naves interiores. Por eso se utilizan cebos anclados en estaciones exteriores y trampas mecánicas de captura en el interior.',
          ),
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
        regulatoryFramework: 'Cumplimiento con NOM-256-SSA1-2012 (Condiciones Sanitarias y de Seguridad en Aplicación de Plaguicidas).',
        problemStatement: 'Para que el producto insecticida llegue a los nidos y zonas de refugio de las plagas, los zócalos y áreas de aplicación deben estar accesibles y despejadas.',
        dosAndDonts: [
          NoticeDoDontItem(
            badPractice: 'Tener cajas, tapetes y objetos pegados a las paredes al llegar el técnico.',
            goodPractice: 'Despejar orillas y zócalos al menos 30 cm de la pared para permitir aspersión.',
          ),
          NoticeDoDontItem(
            badPractice: 'Dejar alimentos, fruta, cafeteras o trastes expuestos sobre cubiertas.',
            goodPractice: 'Guardar comida en refrigerador o alacenas selladas antes de la fumigación.',
          ),
          NoticeDoDontItem(
            badPractice: 'Dejar mascotas (perros, gatos, aves) dentro del área durante la aplicación.',
            goodPractice: 'Llevar mascotas a patio exterior; tapar peceras y apagar la bomba de oxígeno.',
          ),
          NoticeDoDontItem(
            badPractice: 'Realizar limpieza profunda con agua y jabón inmediatamente después de fumigar.',
            goodPractice: 'Hacer el aseo profundo ANTES del servicio para que el químico se fije en seco.',
          ),
        ],
        mandatoryRules: [
          'DESPEJAR ZÓCALOS Y ORILLAS: Retirar objetos, cajas o tapetes pegados a las paredes para permitir la aspersión perimetral.',
          'RESGUARDAR ALIMENTOS Y UTENSILIOS: Cubrir o guardar en alacenas cerradas toda comida, trastes, cafeteras y utensilios de cocina.',
          'MASCOTAS: Retirar perros, gatos y aves del área a tratar. Cubrir acuarios y peceras con plástico hermético y apagar el oxigenador de aire.',
          'En caso de tratamiento contra chinches o pulgas: lavar ropa de cama y cortinas con agua caliente a más de 60 °C antes del servicio.',
          'Garantizar el acceso al personal técnico a cuartos de máquinas, azoteas, registros y sótanos.',
        ],
        biologicalPhases: [
          NoticePhaseItem(
            phaseName: 'Paso 1: Aseo Previo de Superficies',
            timeFrame: 'Horas previas',
            description: 'Barrer y sacudir el polvo de orillas. El químico debe fijarse en piso limpio para no ser absorbido por la mugre.',
          ),
          NoticePhaseItem(
            phaseName: 'Paso 2: Aplicación Especializada',
            timeFrame: 'Durante el servicio',
            description: 'El técnico aplica microaspersión perimetral, geles en hendiduras y nebulización en frío según las plagas objetivo.',
          ),
          NoticePhaseItem(
            phaseName: 'Paso 3: Tiempo de Reingreso Seguro',
            timeFrame: '2 a 4 horas después',
            description: 'Tiempo necesario para que la microniebla se asiente y el químico seque por completo en zócalos.',
          ),
        ],
        facilityRecommendations: [
          'Realizar una limpieza previa de polvo y pisos para que la película residual del insecticida se fije correctamente al suelo.',
          'Contar con una persona responsable en el inmueble para recibir al técnico y validar áreas con mayor presencia de plaga.',
        ],
        faqs: [
          NoticeFaqItem(
            question: '¿Por qué debo barrer y limpiar antes de que llegue el fumigador y no después?',
            answer: 'El insecticida residual necesita fijarse directamente en la superficie del piso o azulejo. Si hay tierra, el producto se adhiere al polvo y se pierde al barrer; y si trapea después, retira la película activa.',
          ),
          NoticeFaqItem(
            question: '¿Qué cuidados especiales requieren los peces y acuarios?',
            answer: 'Los peces son extremadamente sensibles a los piretroides acuáticos. Debe apagarse la bomba de aire y cubrir la pecera con una toalla húmeda o plástico sellado durante el servicio y las 3 horas posteriores.',
          ),
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
        regulatoryFramework: 'Cumplimiento con NOM-256-SSA1-2012 y Criterios Sanitarios Oficiales de Reingreso y Bioseguridad.',
        problemStatement: 'Muchos clientes trapean las orillas inmediatamente después de fumigar, eliminando el producto activo, o se alarman al ver insectos salir aturdidos durante las primeras horas.',
        dosAndDonts: [
          NoticeDoDontItem(
            badPractice: 'Entrar antes del tiempo indicado de 2 a 4 horas por querer adelantar labores.',
            goodPractice: 'Respetar el tiempo de secado; al reingresar, abrir ventanas 20 minutos para ventilar.',
          ),
          NoticeDoDontItem(
            badPractice: 'Trapear con cloro, pinol o agua jabonosa las orillas durante los próximos 5 días.',
            goodPractice: 'Trapear solo el centro; mantener intacta la franja de 15 cm de los zócalos perimetrales.',
          ),
          NoticeDoDontItem(
            badPractice: 'Alarmarse al ver cucarachas salir lentas o convulsionando las primeras 48 horas.',
            goodPractice: 'Barrerlas y tirarlas en bolsa cerrada; es prueba de que el veneno las expulsó de su nido.',
          ),
          NoticeDoDontItem(
            badPractice: 'Aplicar insecticidas de supermercado sobre insectos moribundos.',
            goodPractice: 'Dejar que el insecto haga contacto con el suelo tratado; morirá en cuestión de minutos.',
          ),
        ],
        mandatoryRules: [
          'TIEMPO DE REINGRESO: Esperar un mínimo de 2 a 4 horas antes de reingresar al inmueble tratado para permitir que el producto seque y ventile.',
          'VENTILACIÓN: Al reingresar, abrir puertas y ventanas durante 20 minutos para renovar el aire.',
          'REGLA DE NO TRAPEAR ZÓCALOS: No trapear ni lavar con jabón/cloro las orillas de los muros durante los próximos 3 A 5 DÍAS. Puede limpiar el centro de las habitaciones con mopa húmeda, pero mantenga intacta la franja perimetral donde se depositó el producto residual.',
          'Limpiar superficies de contacto directo de alimentos (mesas y barras de cocina) con un paño húmedo antes de volver a cocinar.',
        ],
        biologicalPhases: [
          NoticePhaseItem(
            phaseName: 'Horas 0 a 4: Secado y Fijación',
            timeFrame: 'Tiempo de reingreso',
            description: 'El insecticida se adhiere a nivel microscópico sobre pisos y zócalos formando una barrera cristalina no volátil.',
          ),
          NoticePhaseItem(
            phaseName: 'Horas 4 a 72: Efecto Desalojo Activo',
            timeFrame: 'Primeros 3 días',
            description: 'Las plagas expuestas presentan descoordinación motriz, salen de fisuras y mueren por colapso neurotóxico.',
          ),
          NoticePhaseItem(
            phaseName: 'Días 4 a 30: Barrera Residual Activa',
            timeFrame: 'Primer mes',
            description: 'Cualquier ninfa que nazca de huevecillos o insecto que intente entrar desde el exterior muere al pisar la franja perimetral.',
          ),
        ],
        facilityRecommendations: [
          'EFECTO DE DESALOJO (Totalmente Normal): Durante las primeras 24 a 72 horas es común observar cucarachas o insectos salir aturdidos, lentos o convulsionando. Esto indica que el producto penetró sus nidos y están muriendo por el efecto neurotóxico.',
          'Barrer y desechar en bolsa cerrada los insectos muertos que aparezcan.',
          'Si cuenta con póliza mensual o trimestral, mantenga sus fechas programadas para cortar ciclos de eclosión de huevecillos.',
        ],
        faqs: [
          NoticeFaqItem(
            question: '¿Puedo limpiar las mesas donde comemos al regresar al inmueble?',
            answer: 'Sí. Las mesas, cubiertas de cocina y escritorios pueden limpiarse con un trapo húmedo antes de usarse. Lo único que NO debe tallarse con agua ni cloro son los zócalos y orillas del suelo.',
          ),
          NoticeFaqItem(
            question: '¿Qué hago si mi perro o gato huele o lame el zócalo después de las 4 horas?',
            answer: 'Una vez seco, el producto se fija a nivel molecular y no se desprende. No hay riesgo de intoxicación por contacto incidental para animales de sangre caliente.',
          ),
        ],
        technicalDisclaimer: 'La garantía de efectividad de EJ Exterminadores depende de no remover el químico de las orillas. Si nota cualquier eventualidad extraordinaria, comuníquese de inmediato a nuestra línea de atención técnica: 813-175-9342.',
      ),

      // 11. PRESENCIA DE INSECTOS: DINÁMICA DE RESIDUALIDAD, CLIMA Y TIEMPO DE DERRIBO
      AdvisoryNoticeModel(
        id: 'dinamica_insectos_residualidad',
        title: 'Presencia de Insectos y Artrópodos: Dinámica de Residualidad, Clima y Tiempo de Derribo',
        category: 'Dinámica de Plagas',
        targetAudience: 'Empresas, Parques Industriales, Colegios, Comercios y Residencias',
        iconEmoji: '🔬',
        objective: 'Establecer los factores biológicos y ambientales por los cuales es normal el avistamiento eventual de insectos, y fundamentar técnicamente cómo opera la residualidad química (tiempo de derribo de minutos a horas) para brindar certeza al cliente.',
        regulatoryFramework: 'Cumplimiento con NOM-256-SSA1-2012 (Control de plagas urbanas y plaguicidas autorizados por COFEPRIS) y lineamientos de Bioseguridad en Inmuebles.',
        problemStatement: 'En cualquier época del año es biológicamente normal observar avistamientos esporádicos de insectos rastreros (cucarachas de drenaje, alacranes, ciempiés, arañas o tijerillas) en accesos y pasillos. Este fenómeno no representa una deficiencia del servicio químico, sino la respuesta a factores del entorno: temporales de lluvia que saturan madrigueras y drenajes, olas de calor extremo que obligan a las plagas a buscar humedad y sombra al interior, transporte pasivo en cajas y tarimas de proveedores, obras vecinas o predios contiguos. Ante un avistamiento, suele existir la falsa expectativa de que el químico debe "desintegrar al insecto al vuelo", cuando en realidad el tratamiento profesional opera mediante una barrera residual de absorción progresiva.',
        dosAndDonts: [
          NoticeDoDontItem(
            badPractice: 'Asumir falla del servicio al ver un insecto caminando o cruzando una entrada.',
            goodPractice: 'Comprender que el insecto ya pisó la barrera perimetral y está en proceso de intoxicación letal.',
          ),
          NoticeDoDontItem(
            badPractice: 'Exigir químicos que "maten en el aire al instante" o aplicar insecticidas comerciales de lata (Raid).',
            goodPractice: 'Dejar que el producto profesional actúe; los sprays caseros repelen y dispersan nidos hacia techos.',
          ),
          NoticeDoDontItem(
            badPractice: 'Trapear con cloro, pinol o desengrasante los zócalos tras lluvias o limpiezas exhaustivas.',
            goodPractice: 'Trapear únicamente el centro de las salas; mantener intacta la franja perimetral de 15 cm con producto residual.',
          ),
          NoticeDoDontItem(
            badPractice: 'Dejar puertas exteriores abiertas en andenes, patios o jardines por ventilación o descuido.',
            goodPractice: 'Mantener cerradas las puertas perimetrales y verificar que los guardapolvos de hule o cepillo sellen bien.',
          ),
        ],
        mandatoryRules: [
          'LOS PLAGUICIDAS COFEPRIS NO SON MAGIA INSTANTÁNEA: Las formulaciones autorizadas para zonas urbanas e industriales actúan por contacto e ingestión; no forman un domo espacial invisible ni vaporizan insectos al vuelo.',
          'TIEMPO DE DERRIBO (15 MINUTOS A VARIAS HORAS): Cuando el insecto que ingresa del exterior pisa la superficie tratada, el activo penetra su cutícula cerosa. El colapso neurotóxico toma de 15 minutos a varias horas. Si observa un insecto desorientado, lento o temblando, está muriendo.',
          'FACTORES EXTERNOS DESENCADENANTES: Lluvias intensas, calor canicular, obras de construcción vecinas o cajas de proveedores provocan ingresos pasivos que son neutralizados al cruzar la barrera.',
          'PROHIBIDO EL TRAPEADO ABRASIVO DE ZÓCALOS: No tallar con cloro ni desengrasantes la orilla inferior de los muros durante los 5 días posteriores a la aplicación; ahí reside la residualidad activa.',
          'PROHIBIDO EL USO DE SPRAYS CASEROS: Los aerosoles de supermercado contienen solventes repelentes que anulan la residualidad profesional y dispersan las plagas a zonas limpias.',
        ],
        facilityRecommendations: [
          'GUARDAPOLVOS HERMÉTICOS EN PUERTAS: Alacranes y ciempiés entran caminando desde jardines y banquetas por ranuras de apenas 2 a 3 mm. Calibrar cepillos inferiores en todas las puertas exteriores.',
          'MALLAS Y SELLOS EN DRENAJES: Colocar malla mosquitera metálica en coladeras y rejillas pluviales para bloquear la subida de cucarachas procedentes del drenaje de la vía pública.',
          'DESMALEZADO Y ORDEN EXTERIOR: Mantener corto el pasto perimetral y retirar escombros, hojarasca húmeda o maderas acumuladas pegadas a muros exteriores que sirvan de refugio.',
          'REPORTE Y MONITOREO TÉCNICO: Si detecta avistamientos repetidos en un punto específico, repórtelo a EJ Exterminadores para aplicar refuerzos focalizados en registros o tuberías.',
        ],
        biologicalPhases: [
          NoticePhaseItem(
            phaseName: 'Fase 1: Presión Externa e Ingreso Casual',
            timeFrame: 'Fenómeno dinámico anual',
            description: 'Plagas forzadas por clima (lluvias/calor), obras o mercancía exploran accesos y cruzan el umbral perimetral.',
          ),
          NoticePhaseItem(
            phaseName: 'Fase 2: Contacto y Absorción Cuticular',
            timeFrame: 'Minutos tras el cruce',
            description: 'El insecto camina sobre la franja tratada; los microcristales del insecticida penetran sus patas y cutícula.',
          ),
          NoticePhaseItem(
            phaseName: 'Fase 3: Parálisis y Derribo Progresivo',
            timeFrame: '15 min a 4 horas',
            description: 'El activo ataca el sistema nervioso central; el insecto pierde control motriz, convulsiona y muere en campo abierto.',
          ),
          NoticePhaseItem(
            phaseName: 'Fase 4: Blindaje Residual Permanente',
            timeFrame: 'Residualidad activa de la póliza',
            description: 'La película cristalina invisible impide la formación de nidos internos y protege las instalaciones contra infestaciones.',
          ),
        ],
        faqs: [
          NoticeFaqItem(
            question: '¿Por qué vi una cucaracha o ciempiés caminando si acaban de fumigar?',
            answer: 'Porque el insecto acaba de ingresar desde la calle, jardín o drenaje por factores de clima o transporte, y ya pisó la franja residual. Los químicos modernos no son campos de fuerza instantáneos: requieren de minutos a horas para actuar. Verlo desorientado o errático es la prueba científica de que el químico está surtiendo efecto letal.',
          ),
          NoticeFaqItem(
            question: '¿Las lluvias, el calor intenso o la humedad desactivan el insecticida?',
            answer: 'No en interiores ni en áreas perimetrales protegidas. Las formulaciones microencapsuladas de grado industrial se fijan a nivel microscópico al piso y resisten la temperatura y la humedad ambiental. Lo único que remueve el producto es el lavado físico agresivo con cloro o desengrasante.',
          ),
        ],
        technicalDisclaimer: 'EJ Exterminadores garantiza formulaciones de residualidad prolongada aprobadas ante COFEPRIS. Los avistamientos esporádicos son inevitables ante la presión biológica del entorno exterior; nuestro tratamiento garantiza que ningún insecto que ingrese logre sobrevivir, anidar o convertirse en una plaga dentro de sus instalaciones.',
      ),

      // 12. CONTROL DE ROEDORES: PRESIÓN EXTERNA REGIONAL, DESPLAZAMIENTO Y CEBO RETARDADO
      AdvisoryNoticeModel(
        id: 'dinamica_roedores_cebo_retardado',
        title: 'Control de Roedores: Presión Externa Regional, Desplazamiento y Ciencia del Cebo Retardado',
        category: 'Dinámica de Plagas',
        targetAudience: 'Comités de Seguridad, Mantenimiento, Dirección Escolar y Gerencias de Planta',
        iconEmoji: '🐀',
        objective: 'Explicar científicamente los factores de desplazamiento regional de roedores en cualquier época del año y fundamentar el mecanismo de acción retardada de las estaciones cebaderas para evitar falsas alarmas y preservar la efectividad del tratamiento.',
        regulatoryFramework: 'Cumplimiento con NOM-256-SSA1-2012, directrices de Manejo Integrado de Plagas (MIP) y normas de Salud y Bioseguridad.',
        problemStatement: 'En cualquier momento del año es factible el avistamiento ocasional de roedores (rata de alcantarilla Rattus norvegicus, rata de tejado Rattus rattus o ratón casero Mus musculus) en patios, andenes o perímetros exteriores. Este fenómeno es resultado de la presión biológica de la zona: redes municipales de alcantarillado con sobrepoblación, lotes baldíos contiguos, obras civiles que destruyen madrigueras silvestres, o cambios estacionales extremos (lluvias que inundan cloacas, olas de calor donde buscan agua o temporadas frías donde buscan cobijo). Un avistamiento no significa que el sistema preventivo haya fallado; los roedores del exterior continuamente exploran nuevos territorios y el tratamiento profesional está diseñado para interceptarlos y abatirlos mediante cebos de acción retardada.',
        dosAndDonts: [
          NoticeDoDontItem(
            badPractice: 'Creer que un veneno profesional debe fulminar a la rata en segundos frente a las personas.',
            goodPractice: 'Comprender que la acción retardada de 3 a 5 días es indispensable para que toda la colonia consuma el cebo.',
          ),
          NoticeDoDontItem(
            badPractice: 'Manipular, reubicar o abrir las estaciones cebaderas de plástico de EJ Exterminadores.',
            goodPractice: 'Mantener las estaciones fijas y cerradas; están ancladas en rutas biológicas estratégicas con llave de seguridad.',
          ),
          NoticeDoDontItem(
            badPractice: 'Dejar basura con restos orgánicos destapada o comida en escritorios y aulas por la noche.',
            goodPractice: 'Sellar botes de basura herméticamente antes de las 18:00 hrs para obligar al roedor a alimentarse del cebo.',
          ),
          NoticeDoDontItem(
            badPractice: 'Pensar que las trampas impiden físicamente que un ratón camine sobre el patio o la banqueta.',
            goodPractice: 'Sellar rendijas estructurales en puertas y ductos: la exclusión física bloquea el acceso; el cebo elimina la población.',
          ),
        ],
        mandatoryRules: [
          'LA CIENCIA DEL CEBO RETARDADO (NEOFOBIA): Los roedores son animales gregarios con alta inteligencia biológica. Si un cebo matara a una rata al instante, las demás del clan asocian la comida con muerte inmediata y NUNCA vuelven a probarla (recelo al cebo).',
          'MORTALIDAD SILENCIOSA EN 3 A 5 DÍAS: Nuestros cebos anticoagulantes de segunda generación producen somnolencia natural y deshidratación progresiva. El roedor busca instintivamente su madriguera subterránea para expirar, reduciendo riesgos de malos olores en áreas de trabajo.',
          'PRESIÓN POBLACIONAL DEL ENTORNO: Si en la colonia, drenajes públicos o terrenos vecinos existen cientos de roedores, el control es una tarea permanente de intercepción y monitoreo, no una barrera mágica instantánea.',
          'DISCIPLINA DE BASURA Y ALIMENTOS: Los roedores tienen un olfato hiperdesarrollado. Si encuentran comida fácil en botes abiertos o lockers, ignorarán los cebos. La higiene de la empresa representa el 50% del éxito.',
        ],
        facilityRecommendations: [
          'REGLA DE EXCLUSIÓN DE LOS 6 MILÍMETROS: Un ratón juvenil cabe por una ranura de tan solo 6 mm (el diámetro de una pluma). Ajustar cepillos y guardapolvos inferiores en todas las puertas perimetrales.',
          'SELLADO DE DUCTOS Y PASACABLES: Bloquear con malla de acero inoxidable y sellador de poliuretano todas las perforaciones de tuberías hidrosanitarias, cables y aires acondicionados hacia el exterior.',
          'DESPEJE DE RAMAS Y TECHUMBRES: La rata de tejado trepa árboles y cables para ingresar por falsos plafones y techos de lámina. Podar ramas a mínimo 1.5 metros de distancia de muros y techos.',
          'REPOSICIÓN Y MANTENIMIENTO EN PÓLIZA: Permitir la inspección, limpieza y reposición periódica de cebos por parte de EJ Exterminadores en cada visita programada para mantener el blindaje activo.',
        ],
        biologicalPhases: [
          NoticePhaseItem(
            phaseName: 'Fase 1: Presión Regional e Incursión Exploratoria',
            timeFrame: 'Fenómeno continuo anual',
            description: 'Roedores desplazados por drenajes, obras o clima buscan comida y refugio en perímetros.',
          ),
          NoticePhaseItem(
            phaseName: 'Fase 2: Consumo Seguro en Cebaderos',
            timeFrame: 'Días 2 a 5',
            description: 'Ingesta de bloques parafinados profesionales dentro de estaciones cebaderas sin sospecha colectiva.',
          ),
          NoticePhaseItem(
            phaseName: 'Fase 3: Mortalidad Retardada en Madriguera',
            timeFrame: 'Días 3 a 7',
            description: 'Efecto anticoagulante progresivo; los roedores regresan a sus nidos subterráneos para morir sin agonía ruidosa.',
          ),
          NoticePhaseItem(
            phaseName: 'Fase 4: Abatimiento y Cordón Sanitario Continuo',
            timeFrame: 'Monitoreo regular en póliza',
            description: 'Reposición de bloques consumidos e intercepción preventiva de nuevos ejemplares migrantes.',
          ),
        ],
        faqs: [
          NoticeFaqItem(
            question: '¿Por qué no usamos un veneno de efecto fulminante instantáneo?',
            answer: 'Porque biológicamente causaría el fracaso del tratamiento. Las ratas envían ejemplares a probar comida desconocida: si la rata muere al instante, la colonia emite señales de alarma y rechaza el cebo de por vida. El anticoagulante retardado permite que toda la colonia coma confiadamente hasta su erradicación total.',
          ),
          NoticeFaqItem(
            question: '¿Por qué vemos roedores en el patio si ya tenemos estaciones cebaderas instaladas?',
            answer: 'Las estaciones cebaderas son puntos de consumo e intercepción, no muros físicos que detengan sus patas en el patio exterior. La presencia externa obedece a la sobrepoblación en la zona urbana (drenajes, baldíos o arroyos). Al ingresar, los roedores consumen los cebos y el ciclo de eliminación se activa.',
          ),
        ],
        technicalDisclaimer: 'EJ Exterminadores utiliza rodenticidas anticoagulantes de última generación formulados en cebos parafinados de alta palatabilidad, resguardados en estaciones inviolables con llave de seguridad. El control total es un esfuerzo conjunto entre la reposición técnica de cebos y el sellado físico de accesos por parte de la empresa.',
      ),

      // 13. CUCARACHA ALEMANA: FIPRONIL Y CEBO EN GEL
      AdvisoryNoticeModel(
        id: 'cucaracha_fiprax_gel',
        title: 'Tratamiento con Fipronil y Cebo en Gel: Dinámica del Nido y Efecto Cascada',
        category: 'Dinámica de Plagas',
        targetAudience: 'Administradores de Oficina, Encargados de Cocineta y Clientes en Tratamiento de Cucaracha Alemana',
        iconEmoji: '🪳',
        objective: 'Explicar el funcionamiento científico del tratamiento no repelente (Fipronil) y cebo en gel contra la cucaracha alemana, la importancia del efecto cascada en el nido y las fases esperadas durante el proceso de erradicación.',
        problemStatement: 'La cucaracha alemana (Blattella germanica) es una plaga gregaria que anida en grietas profundas, motores y bisagras. Usar insecticidas comerciales de lata o productos con olor provoca su dispersión a escritorios y computadoras. Nuestro tratamiento especializado no las ahuyenta: las infecta para que lleven el principio activo al corazón del nido.',
        regulatoryFramework: 'NOM-256-SSA1-2012 (Control y Manejo de Plagas Urbanas), Registros Sanitarios COFEPRIS y Principios de Manejo Integrado de Plagas (MIP).',
        dosAndDonts: [
          NoticeDoDontItem(
            badPractice: 'Rociar insecticidas en aerosol (Raid, H24) sobre las cucarachas o muebles tratados.',
            goodPractice: 'Dejar que las cucarachas caminen libremente sobre las zonas tratadas para que contagien a las demás en el nido.',
          ),
          NoticeDoDontItem(
            badPractice: 'Limpiar o retirar con trapo húmedo los puntos de gel aplicados en bisagras y muebles.',
            goodPractice: 'Respetar las gotas de gel; son alimento tóxico letal que las ninfas y hembras consumirán durante días.',
          ),
          NoticeDoDontItem(
            badPractice: 'Trapear con cloro y desengrasante los zoclos y bases de muebles en las primeras 48 horas.',
            goodPractice: 'Trapear solo el centro de pisos; mantener intacta la película residual de Fipronil en orillas y partes bajas.',
          ),
          NoticeDoDontItem(
            badPractice: 'Dejar café, azúcar, pan o galletas expuestos en cajones y estantes de cocineta.',
            goodPractice: 'Guardar todo alimento en recipientes herméticos rígidos; si no hay comida disponible, el consumo de cebo se multiplica.',
          ),
        ],
        mandatoryRules: [
          'EFECTO CASCADA ACTIVO: Las cucarachas son coprófagas y necrófagas; las heces y el cuerpo de una cucaracha que pisó Fipronil envenenan a 10 más dentro de la pared o estantería.',
          'PROHIBIDO EL USO DE AEROSOLES: Cualquier insecticida de lata anula el efecto del Fipronil, repele a la plaga y la dispersa a computadoras y escritorios limpios.',
          'RESIDUALIDAD Y NO LAVADO: No lave con químicos desinfectantes las esquinas, bisagras ni zoclos donde se colocó el producto durante al menos 5 días.',
          'LIMPIEZA DE GRASA Y MIGAJAS: La grasa de la cocineta degrada el insecticida. Limpie derrames de grasa antes de la aplicación y mantenga cajones sin residuos de alimentos.',
          'CICLO BIOLÓGICO Y SEGUNDO MES: La cáscara del huevo (ooteca) es impenetrable. Las crías que nazcan en 15-20 días morirán al pisar el producto; el seguimiento mensual es indispensable.',
        ],
        facilityRecommendations: [
          'SELLADO DE GRIETAS EN ESTANTERÍAS: Sellar con silicón o acrilastic las uniones entre azulejos, fórmica y marcos de estantes para eliminar refugios térmicos.',
          'REVISIÓN DE EMPAQUES DE REFRIGERADOR Y MICROONDAS: Limpiar con regularidad la parte trasera de motores y sellos de goma, donde el calor atrae a las ninfas.',
          'DESPEJE TEMPORAL DE ALACENAS: Durante la aplicación, despejar insumos alimenticios y vajillas en cajas cerradas para permitir acceso total a esquinas.',
          'ELIMINACIÓN DE HUMEDAD: Reparar fugas en llaves y secar el fregadero al terminar la jornada; las cucarachas resisten semanas sin comida pero solo días sin agua.',
        ],
        biologicalPhases: [
          NoticePhaseItem(
            phaseName: 'Fase 1: Desalojo e Intoxicación del Nido',
            timeFrame: 'Días 1 a 3',
            description: 'Cucarachas salen descoordinadas y aturdidas a la vista. Es señal de que el sistema nervioso fue afectado y el químico está trabajando.',
          ),
          NoticePhaseItem(
            phaseName: 'Fase 2: Quiebre de la Población Adulta',
            timeFrame: 'Días 4 a 14',
            description: 'Mortalidad masiva (80-90%). Las cucarachas mueren dentro de sus refugios contagiando a ninfas que nunca salieron a la superficie.',
          ),
          NoticePhaseItem(
            phaseName: 'Fase 3: Eclosión de Ninfas y Control Total',
            timeFrame: 'Día 15 a 45',
            description: 'Nacen crías diminutas de los huevecillos residuales. Al comer el gel fresco o caminar sobre el Fipronil, mueren sin llegar a reproducirse.',
          ),
        ],
        faqs: [
          NoticeFaqItem(
            question: '¿Por qué sigo viendo cucarachas vivas después de la fumigación?',
            answer: 'Fipronil no mata de golpe porque necesita tiempo para que la cucaracha vuelva al nido viva y contagie al resto de la colonia. La muerte retardada es exactamente lo que garantiza la erradicación total.',
          ),
          NoticeFaqItem(
            question: '¿El Fiprax y el gel manchan o huelen mal en la oficina?',
            answer: 'No. Es una fórmula en suspensión concentrada base agua y geles específicos, inodoros, que no emiten vapores tóxicos ni manchan muebles, aptos para áreas de trabajo y preparación de alimentos.',
          ),
        ],
        technicalDisclaimer: 'El tratamiento con Fipronil y cebo en gel de EJ Exterminadores es la tecnología de mayor precisión para cucaracha alemana. La efectividad depende de evitar el uso de insecticidas comerciales que repelan a la plaga y mantener estrictas medidas de higiene en cocinetas y escritorios.',
      ),

      // 14. PROTOCOLO GENERAL EN OFICINAS Y ÁREAS CORPORATIVAS
      AdvisoryNoticeModel(
        id: 'oficinas_corporativo_general',
        title: 'Protocolo de Fumigación en Oficinas: Bioseguridad y Buenas Prácticas Corporativas',
        category: 'Oficinas y Corporativos',
        targetAudience: 'Dirección Administrativa, Recursos Humanos, Seguridad Operativa y Personal de Oficina',
        iconEmoji: '🏢',
        objective: 'Establecer los lineamientos de preparación previa, cuidados de equipo electrónico y dinámica post-servicio para fumigaciones seguras y discretas en oficinas corporativas.',
        problemStatement: 'En entornos de oficina conviven cableados estructurados, servidores, alfombras y áreas de café. Una fumigación improvisada con productos de olor fuerte o aspersión descuidada puede dañar equipos electrónicos o incomodar al personal. Se requiere un protocolo técnico estandarizado de bajo impacto ambiental y alta residualidad.',
        regulatoryFramework: 'NOM-256-SSA1-2012, Ley General de Salud, Estándares de Inocuidad y Bioseguridad en Espacios Cerrados de Trabajo.',
        dosAndDonts: [
          NoticeDoDontItem(
            badPractice: 'Dejar tazas de café, cubiertos, fruta o botanas destapadas sobre escritorios antes del servicio.',
            goodPractice: 'Guardar tazas, termos y alimentos en bolsas cerradas o dentro de gavetas durante la noche de aplicación.',
          ),
          NoticeDoDontItem(
            badPractice: 'Dejar cerros de papeles, carpetas y cajas amontonados pegados a los zoclos del suelo.',
            goodPractice: 'Despejar los perímetros del piso 10 cm para permitir el paso uniforme del aplicador técnico.',
          ),
          NoticeDoDontItem(
            badPractice: 'Rociar líquidos directamente sobre contactos, teclados, switches de red o pantallas.',
            goodPractice: 'Tratar áreas electrónicas exclusivamente con cebos no conductores o trampas adhesivas de monitoreo.',
          ),
          NoticeDoDontItem(
            badPractice: 'Lavar a fondo alfombras o zoclos al día siguiente de la fumigación.',
            goodPractice: 'Aspirar con regularidad el centro de las alfombras pero evitar trapear las orillas tratadas en 72 horas.',
          ),
        ],
        mandatoryRules: [
          'DESPEJE DE ÁREAS PERIMETRALES: Retirar mochilas, papelería y cajas del suelo junto a las paredes para garantizar una franja perimetral de aplicación continua.',
          'ALIMENTOS Y COCINETA DESPEJADA: Todos los insumos de café, galletas, azúcar y vajilla deben guardarse protegidos o retirarse de la cocineta durante el servicio.',
          'TIEMPO DE REINGRESO SEGURO: El personal puede reingresar tras un periodo mínimo de ventilación de 60 a 90 minutos después de concluida la aplicación.',
          'EQUIPOS ELECTRÓNICOS PROTEGIDOS: No se aplican líquidos sobre computadoras ni cableados. Estas zonas se protegen con geles discretos y trampas de monitoreo.',
          'PROHIBIDO GUARDAR COMIDA ABIERTA EN CAJONES: Los escritorios no son alacenas. La comida abierta en cajones es la causa #1 de plagas en oficinas corporativas.',
        ],
        facilityRecommendations: [
          'ORDEN Y LIMPIEZA DE CABLEADO: Emplear canaletas cerradas para cables de red y luz, evitando marañas en el suelo donde los insectos encuentran refugio.',
          'MANEJO DIARIO DE BASURA: Retirar la basura con restos de comida (orgánica) al final de cada jornada laboral; no dejar botes con restos durante el fin de semana.',
          'MANTENIMIENTO DE MINISPLITS: Sellar las perforaciones en muros y zoclos por donde entran las mangueras de condensación y tuberías de gas.',
          'PLAFONES Y FALSOS TECHOS: Revisar periódicamente el entretecho para asegurar que no haya filtraciones de humedad ni acumulación de polvo.',
        ],
        biologicalPhases: [
          NoticePhaseItem(
            phaseName: 'Fase 1: Barrera Perimetral e Inactivación',
            timeFrame: 'Días 1 a 3',
            description: 'Fijación de la película residual en zoclos y colocación de cebos discretos en cocinetas y áreas de archivo.',
          ),
          NoticePhaseItem(
            phaseName: 'Fase 2: Quiebre de Focos Ocultos',
            timeFrame: 'Días 4 a 15',
            description: 'Eliminación de plagas que intenten colonizar desde naves contiguas, ductos de clima o plafones.',
          ),
          NoticePhaseItem(
            phaseName: 'Fase 3: Protección Continua y Monitoreo',
            timeFrame: 'Día 16 a 30',
            description: 'Mantenimiento de la bioseguridad en las instalaciones, con inspección preventiva programada en la siguiente visita.',
          ),
        ],
        faqs: [
          NoticeFaqItem(
            question: '¿Nuestras computadoras o documentos corren algún riesgo?',
            answer: 'Ninguno. EJ Exterminadores utiliza aspersores de precisión con gota controlada en zoclos bajos y cebo en gel en áreas sensibles. No se mojan escritorios, pantallas ni equipos eléctricos.',
          ),
          NoticeFaqItem(
            question: '¿El producto deja olor o manchas en alfombras y muros?',
            answer: 'No. Los productos seleccionados para oficinas corporativas son microencapsulados o suspensiones concentradas base agua, inodoros y que no dejan residuos visibles ni manchan.',
          ),
        ],
        technicalDisclaimer: 'Las formulaciones aplicadas por EJ Exterminadores cuentan con registro COFEPRIS para uso en interiores comerciales e industriales, con nula volatilidad y máxima seguridad para el personal corporativo una vez respetado el tiempo de reingreso.',
      ),
    ];
  }
}
