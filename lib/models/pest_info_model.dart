class PestInfoModel {
  final String id;
  final String name;
  final String scientificName;
  final String category; // 'Roedores', 'Arácnidos y Ponzoñosos', 'Cucarachas', 'Rastreros', 'Voladores', 'Estructurales'
  final String riskLevel; // 'Crítico / Venenoso', 'Alto / Salud Pública', 'Severo / Estructural', 'Moderado'
  final String iconEmoji;
  final String summary;
  final List<String> habitats;
  final List<String> habits;
  final List<String> healthRisks;
  final List<String> signs;
  final List<String> preventionTips;
  final String professionalTreatment;

  const PestInfoModel({
    required this.id,
    required this.name,
    required this.scientificName,
    required this.category,
    required this.riskLevel,
    required this.iconEmoji,
    required this.summary,
    required this.habitats,
    required this.habits,
    required this.healthRisks,
    required this.signs,
    required this.preventionTips,
    required this.professionalTreatment,
  });

  static List<PestInfoModel> getAllPests() {
    return const [
      // 1. ROEDORES
      PestInfoModel(
        id: 'roedores',
        name: 'Ratas y Ratones (Roedores Comensales)',
        scientificName: 'Rattus norvegicus, Rattus rattus, Mus musculus',
        category: 'Roedores',
        riskLevel: 'Crítico / Salud Pública',
        iconEmoji: '🐀',
        summary: 'Mamíferos altamente prolíficos y adaptables. Poseen dientes incisivos de crecimiento continuo que los obligan a roer constantemente cables, madera, plástico y tuberías.',
        habitats: [
          'Drenajes, alcantarillados y registros subterráneos (Rata de alcantarilla).',
          'Falsos plafones, techumbres, vigas y áticos (Rata de tejado).',
          'Detrás de tarimas, motores de refrigeración, alacenas y cajones de oficina (Ratón doméstico).',
        ],
        habits: [
          'Hábitos predominantemente nocturnos; si se observan de día indica alta población.',
          'Neofobia: desconfían de objetos nuevos en su entorno por varios días.',
          'Pueden comprimir su esqueleto para entrar por orificios de apenas 6 mm (ratones) a 12 mm (ratas).',
        ],
        healthRisks: [
          'Transmisores de Leptospirosis, Salmonelosis, Hantavirus y Tifus murino.',
          'Contaminación de alimentos y superficies a través de orina, saliva y pelos.',
          'Alto riesgo de cortocircuitos e incendios por roedura de instalaciones eléctricas.',
        ],
        signs: [
          'Heces fecales oscuras en forma de cápsula o grano de arroz cerca de muros o cajones.',
          'Marcas de grasa y fricción en zócalos o tuberías por donde transitan repetidamente.',
          'Empaques, cajas o galletas/alimentos roídos.',
          'Ruidos de rasguños en plafones o entreparedes durante la noche.',
        ],
        preventionTips: [
          'Almacenar todo alimento en recipientes herméticos de plástico duro o vidrio (nunca bolsas abiertas en cajones).',
          'Instalar guardapolvos metálicos en puertas y sellar con malla de acero cualquier abertura mayor a 6 mm.',
          'Eliminar fuentes de agua accesibles (fugas en tarjas, condensados de clima).',
          'Mantener un perímetro de 45 cm libre entre tarimas o muros en bodegas.',
        ],
        professionalTreatment: 'Programa Integral EJ: Inspección de rutas, cebado en estaciones de seguridad inviolables con rodenticidas anticoagulantes de segunda generación y trampas de impacto/captura mecánica en zonas sensibles.',
      ),

      // 2. ALACRÁN
      PestInfoModel(
        id: 'alacran',
        name: 'Alacrán de Corteza / Escorpión',
        scientificName: 'Centruroides spp.',
        category: 'Arácnidos y Ponzoñosos',
        riskLevel: 'Crítico / Venenoso',
        iconEmoji: '🦂',
        summary: 'Arácnido depredador de hábitos nocturnos con aguijón caudal conectado a glándulas de veneno neurotóxico. Capaz de trepar superficies rugosas verticales.',
        habitats: [
          'Grietas en muros de ladrillo o block, bajo zócalos y marcos de puertas.',
          'Pilas de escombro, madera, ladrillos, tabiques y leña en patios o perímetros.',
          'Plafones, clósets, cajoneras y dentro de calzado o ropa acumulada en el suelo.',
        ],
        habits: [
          'Caza nocturna guiada por vibraciones sensoriales; durante el día se refugia en sitios oscuros y estrechos.',
          'Su presencia está estrechamente ligada a la presencia de cucarachas y grillos (sus presas principales).',
          'Pueden sobrevivir meses sin alimento si tienen acceso a humedad.',
        ],
        healthRisks: [
          'Picadura potencialmente mortal en niños, adultos mayores o personas alérgicas.',
          'Efectos neurotóxicos: dolor intenso, adormecimiento, dificultad respiratoria, taquicardia y salivación.',
        ],
        signs: [
          'Avistamiento de ejemplares en paredes o pisos durante la noche o primeras horas del día.',
          'Detección mediante inspección con luz ultravioleta (fluorecen intensamente en color verde-azulado).',
        ],
        preventionTips: [
          'Eliminar cacharros, escombros, madera y maleza acumulada en el perímetro del inmueble.',
          'Revisar y sacudir calzado y prendas de vestir antes de usarlas.',
          'Sellar holguras bajo puertas principales con guardapolvos de cepillo o hule rígido.',
          'Controlar activamente las plagas de cucarachas para cortar su fuente de alimentación.',
        ],
        professionalTreatment: 'Programa Integral EJ: Aplicación perimetral e interior con insecticidas piretroides microencapsulados de alto poder de derribo y residualidad, espolvoreo en hendiduras y control exhaustivo de plagas presa.',
      ),

      // 3. CUCARACHA ALEMANA
      PestInfoModel(
        id: 'cucaracha_alemana',
        name: 'Cucaracha Alemana (De Cocina)',
        scientificName: 'Blattella germanica',
        category: 'Cucarachas',
        riskLevel: 'Alto / Salud Pública',
        iconEmoji: '🪳',
        summary: 'La especie de cucaracha más destructiva en interiores y cocinas. Color castaño claro con dos bandas longitudinales oscuras en el tórax. Extraordinaria tasa de reproducción.',
        habitats: [
          'Motores de refrigeradores, microondas, cafeteras, terminales de cobro y básculas.',
          'Hendiduras en azulejos, detrás de alacenas de madera y tarjas de lavado.',
          'Cajoneras de cocinas, comedores y escritorios donde se almacenan galletas o botanas.',
        ],
        habits: [
          'Gregarismo extremo: se congregan mediante feromonas de agregación en heces.',
          'La hembra carga la ooteca (cápsula con hasta 40 crías) casi hasta el momento de eclosión.',
          'Pueden desarrollar resistencia química si no se alternan grupos de insecticidas técnicos.',
        ],
        healthRisks: [
          'Portadoras de Salmonella, E. coli, Shigella y huevecillos de parásitos helmintos.',
          'Sus restos de muda y heces son potentes detonadores de asma y alergias severas.',
          'Causan clausuras sanitarias y graves pérdidas de reputación en restaurantes y comercios.',
        ],
        signs: [
          'Manchas puntiformes oscuras (semejantes a pimienta molida) en bisagras, contactos y esquinas.',
          'Olor fétido aceitoso y característico en áreas con alta infestación.',
          'Cápsulas de ootecas vacías en grietas o cajones.',
        ],
        preventionTips: [
          'Prohibir el consumo y almacenamiento de alimentos en escritorios y áreas no autorizadas.',
          'Limpieza diaria nocturna profunda de estufas, freidoras y debajo de refrigeradores.',
          'Inspeccionar minuciosamente cajas de cartón corrugado que ingresen con mercancía o insumos.',
          'Sellar con silicón hendiduras entre azulejos, muros y barras de cocina.',
        ],
        professionalTreatment: 'Programa Integral EJ: Desalojo focalizado, aplicación precisa de cebos en gel alimenticio con reguladores de crecimiento (IGR) para esterilizar a la colonia y aspersión dirigida sin contaminar alimentos.',
      ),

      // 4. CUCARACHA AMERICANA
      PestInfoModel(
        id: 'cucaracha_americana',
        name: 'Cucaracha Americana (De Drenaje)',
        scientificName: 'Periplaneta americana',
        category: 'Cucarachas',
        riskLevel: 'Alto / Salud Pública',
        iconEmoji: '🪳',
        summary: 'La cucaracha común más grande en zonas urbanas (hasta 5 cm de longitud). De color café rojizo, posee alas completamente desarrolladas y capacidad de planeo.',
        habitats: [
          'Registros de drenaje, redes de alcantarillado, fosas sépticas y cuartos de calderas.',
          'Sótanos húmedos, ductos de basura y cámaras subterráneas de tuberías.',
          'Tuberías de desagüe de baños, lavabos y coladeras sin trampa hidráulica.',
        ],
        habits: [
          'Prefiere ambientes muy cálidos y de alta humedad relativa.',
          'Ingresa a inmuebles a través de tuberías secas de desagüe o volando en noches calurosas.',
          'Omnívora: se alimenta de materia orgánica en descomposición, excremento y basura.',
        ],
        healthRisks: [
          'Contaminación mecánica masiva de gérmenes patógenos procedentes de aguas residuales.',
          'Bacterias de gastroenteritis, fiebre tifoidea y diarreas infantiles.',
        ],
        signs: [
          'Presencia de ejemplares grandes deambulando de noche en pisos de baños o bodegas.',
          'Ootecas oscuras de 8 a 10 mm pegadas en superficies protegidas cerca de fuentes de agua.',
        ],
        preventionTips: [
          'Verificar que todas las coladeras tengan trampa de agua (céspol) llena y rejilla con malla fina.',
          'Sellar herméticamente las tapas de registros sanitarios con sellador o silicón.',
          'Colocar guardapolvos rígidos en puertas de acceso que comuniquen a patios o pasillos de servicio.',
        ],
        professionalTreatment: 'Programa Integral EJ: Tratamiento termonebulizado o de aspersión residual profunda en registros de drenaje, cebado granular perimetral y colocación de barreras residuales de alta persistencia.',
      ),

      // 5. CIEMPIÉS Y MILPIÉS
      PestInfoModel(
        id: 'ciempies',
        name: 'Ciempiés y Milpiés',
        scientificName: 'Scolopendra spp. / Diplopoda',
        category: 'Rastreros',
        riskLevel: 'Moderado a Doloroso',
        iconEmoji: '🐛',
        summary: 'Miriápodos artrópodos terrestres. Los ciempiés son carnívoros rápidos con forcípulas venenosas; los milpiés son lentos, herbívoros y se enroscan en espiral como defensa.',
        habitats: [
          'Debajo de macetas, piedras, hojarasca húmeda, pasto alto y tierra de jardín.',
          'Sótanos, cuartos de lavado, zócalos de baños y áreas con filtraciones de agua.',
        ],
        habits: [
          'Buscan refugio en interiores durante épocas de lluvias torrenciales o sequías extremas.',
          'Ciempiés: cazadores nocturnos activos de otros insectos.',
          'Milpiés: pueden secretar líquidos defensivos con olor desagradable que manchan la piel.',
        ],
        healthRisks: [
          'La mordedura de ciempiés grandes causa dolor agudo intenso similar a picadura de avispa, hinchazón y enrojecimiento localizado.',
          'No transmiten enfermedades, pero generan gran alarma visual en clientes y huéspedes.',
        ],
        signs: [
          'Avistamiento de ejemplares deslizándose rápidamente por paredes o enroscados en esquinas de pisos húmedos.',
        ],
        preventionTips: [
          'Reducir el exceso de humedad y regar jardines en horarios matutinos.',
          'Retirar pilas de hojas secas, corteza vegetal o leña pegada a los muros del inmueble.',
          'Sellar holguras en puertas a nivel de piso y ventilas perimetrales.',
        ],
        professionalTreatment: 'Programa Integral EJ: Creación de cinturón químico de contención perimetral exterior y aplicación dirigida en puntos de acceso para impedir el ingreso a inmuebles.',
      ),

      // 6. ARAÑA VIOLINISTA
      PestInfoModel(
        id: 'arania_violinista',
        name: 'Araña Violinista (De Rincón)',
        scientificName: 'Loxosceles spp.',
        category: 'Arácnidos y Ponzoñosos',
        riskLevel: 'Crítico / Venenoso Necrótico',
        iconEmoji: '🕷️',
        summary: 'Araña café o parda de 1 a 3 cm con una marca característica en forma de violín sobre el cefalotórax. Su mordedura posee veneno dermonecrótico sumamente peligroso.',
        habitats: [
          'Detrás de cuadros, cabeceras de camas, libreros, estanterías y muebles que rara vez se mueven.',
          'Roperos, cajas de cartón con archivos muertos y bodegas oscuras con poco movimiento.',
        ],
        habits: [
          'Tímida y no agresiva; muerde solo como mecanismo de defensa si es presionada contra la piel.',
          'Teje telarañas algodonosas, irregulares y desordenadas en rincones oscuros.',
        ],
        healthRisks: [
          'Veneno con enzima esfingomielinasa D: causa loxoscelismo cutáneo (muerte y necrosis de tejido).',
          'En casos severos (loxoscelismo visceral) puede provocar insuficiencia renal aguda y ser fatal.',
        ],
        signs: [
          'Telarañas desordenadas y pegajosas en esquinas bajas de muebles o detrás de cuadros.',
          'Presencia de mudas de exoesqueleto traslúcidas en rincones.',
        ],
        preventionTips: [
          'Separar camas y cabeceras al menos 15 cm de la pared.',
          'Limpiar periódicamente con aspiradora detrás de muebles, cuadros y cortinas.',
          'Sacudir ropa de cama y prendas almacenadas por largo tiempo antes de utilizarlas.',
        ],
        professionalTreatment: 'Programa Integral EJ: Aspersión de insecticidas microencapsulados con alta capacidad de penetración en grietas y rincones oscuros, combinada con aspiración y trampas de monitoreo adhesivas.',
      ),

      // 7. ARAÑA VIUDA NEGRA
      PestInfoModel(
        id: 'viuda_negra',
        name: 'Araña Viuda Negra (Capulina)',
        scientificName: 'Latrodectus mactans',
        category: 'Arácnidos y Ponzoñosos',
        riskLevel: 'Crítico / Venenoso Neurotóxico',
        iconEmoji: '🕷️',
        summary: 'Hembra de color negro brillante con abdomen globoso y una mancha roja viva en forma de reloj de arena en la parte ventral. Veneno neurotóxico 15 veces más potente que el de una serpiente de cascabel.',
        habitats: [
          'Medidores de agua y luz, registros subterráneos de gas o riego.',
          'Bajo salientes de muros, techumbres exteriores, muebles de jardín y depósitos de basura.',
          'Almacenes poco transitados y pilas de llantas o blocks.',
        ],
        habits: [
          'Teje telas muy resistentes con hilos de resistencia semejante al acero proporcionalmente.',
          'Permanece colgada de cabeza en su telaraña esperando que caiga una presa.',
        ],
        healthRisks: [
          'Latrodectismo: dolor muscular espasmódico severo, rigidez abdominal, dificultad para respirar y sudoración profusa. Requiere atención médica urgente con faboterápico.',
        ],
        signs: [
          'Telarañas muy resistentes que crujen al ser rotas en registros o debajo de bancas exteriores.',
          'Sacos de huevecillos esféricos color beige de superficie papirácea suspendidos en la red.',
        ],
        preventionTips: [
          'Inspeccionar y mantener cerrados con candado registros de servicios públicos.',
          'Utilizar guantes de cuero para realizar labores de jardinería o remoción de materiales en patios.',
          'Eliminar telarañas exteriores con escobillón frecuentemente.',
        ],
        professionalTreatment: 'Programa Integral EJ: Tratamiento perimetral con derribo químico fulminante en registros exteriores, aspilleras y cavidades protegidas.',
      ),

      // 8. CHINCHES DE CAMA
      PestInfoModel(
        id: 'chinches',
        name: 'Chinches de Cama',
        scientificName: 'Cimex lectularius',
        category: 'Rastreros',
        riskLevel: 'Alto / Picadura Severa',
        iconEmoji: '🛏️',
        summary: 'Insectos parásitos hematófagos de cuerpo aplanado ovalado (tamaño semilla de manzana). Expertos en autostop: se transportan en maletas, ropa y colchones de hoteles o transporte.',
        habitats: [
          'Costuras, pliegues y etiquetas de colchones y bases de cama de madera.',
          'Hendiduras en cabeceras, enchufes eléctricos cercanos a camas y detrás de papel tapiz.',
          'Sillones, butacas de cines y salas de espera tapizadas.',
        ],
        habits: [
          'Se alimentan exclusivamente de sangre humana durante la noche mientras la persona duerme.',
          'Inyectan anestésico y anticoagulante con su saliva para que la picadura sea indolora en el momento.',
          'Pueden sobrevivir más de un año sin alimentarse en estado de diapausa.',
        ],
        healthRisks: [
          'Múltiples ronchas rojizas agrupadas en línea ("desayuno, comida y cena") con comezón intensa.',
          'Infecciones cutáneas secundarias por rascado constante e insomnio crónico severo.',
          'Enorme impacto económico y reputacional para hoteles y Airbnb.',
        ],
        signs: [
          'Pequeñas manchas de sangre o puntos negros fecales en sábanas y esquinas del colchón.',
          'Exuvias (pieles mudadas) de ninfas en las costuras del colchón.',
          'Olor dulce almendrado en habitaciones con infestación avanzada.',
        ],
        preventionTips: [
          'Inspeccionar minuciosamente colchones y cabeceras al hospedarse en hoteles antes de desempacar.',
          'No colocar maletas abiertas sobre la cama; usar portamaletas elevados de metal.',
          'Lavar sábanas y ropa de viaje con agua caliente a más de 60 °C.',
        ],
        professionalTreatment: 'Programa Integral EJ: Protocolo técnico intensivo con vapor seco a alta temperatura para eliminar huevecillos, aplicación combinada de insecticidas residuales con IGR y espolvoreo desecante en tomacorrientes.',
      ),

      // 9. TERMITAS
      PestInfoModel(
        id: 'termitas',
        name: 'Termitas (Comején de Madera)',
        scientificName: 'Reticulitermes spp., Cryptotermes spp.',
        category: 'Estructurales',
        riskLevel: 'Severo / Daño Estructural',
        iconEmoji: '🪵',
        summary: 'Insectos sociales xilófagos que se alimentan de la celulosa de maderas, libros, aglomerados y vigas estructurales. Operan en secreto durante años sin ser detectadas externamente.',
        habitats: [
          'Subsuelo y cimientos de inmuebles (Termita subterránea).',
          'Vigas de madera, marcos de puertas, muebles empotrados y pisos de duela (Madera seca).',
        ],
        habits: [
          'Viven en colonias organizadas por castas (reina, rey, obreras y soldados con mandíbulas reforzadas).',
          'Consumen la madera de adentro hacia afuera, dejando una capa exterior delgada que parece intacta.',
        ],
        healthRisks: [
          'Riesgo inminente de colapso de techumbres, vigas, escaleras o pisos de madera.',
          'Pérdidas económicas catastróficas en el patrimonio o mercancía de bodega.',
        ],
        signs: [
          'Tubos o túneles de barro construidos sobre cimientos o muros para protegerse de la luz.',
          'Madera que suena hueca al ser golpeada o se hunde fácilmente con la presión de un dedo.',
          'Enjambrazón: alas traslúcidas caídas cerca de ventanas en primavera tras vuelos nupciales.',
          'Pequeños gránulos fecales secos parecidos a arena debajo de marcos de puertas.',
        ],
        preventionTips: [
          'Evitar el contacto directo de madera estructural con el suelo o tierra de jardines.',
          'Corregir fugas de agua y humedad que ablanden maderas.',
          'Inspeccionar marcos de puertas y zócalos al menos una vez al año.',
        ],
        professionalTreatment: 'Programa Integral EJ: Perforación e inyección presurizada de termiticidas termales en cimientos, barreras químicas de exclusión perimetral y tratamiento profundo de maderas afectadas.',
      ),

      // 10. MOSCAS Y MOSQUITOS
      PestInfoModel(
        id: 'moscas_mosquitos',
        name: 'Moscas y Mosquitos Urbanos',
        scientificName: 'Musca domestica / Aedes aegypti / Culex spp.',
        category: 'Voladores',
        riskLevel: 'Alto / Vector de Enfermedades',
        iconEmoji: '🪰',
        summary: 'Insectos dípteros voladores de rápida dispersión. Las moscas regurgitan saliva sobre alimentos sólidos; los mosquitos hembra requieren sangre para madurar sus huevecillos.',
        habitats: [
          'Contenedores de basura, áreas de composta y estiércol (Moscas).',
          'Agua estancada en cubetas, llantas, canaletas obstruidas y floreros (Mosquitos).',
          'Drenajes de cocina donde se acumula biopelícula orgánica (Mosca de drenaje).',
        ],
        habits: [
          'Moscas: atraídas por olores de descomposición y azúcares fermentados.',
          'Mosquitos: vuelan al atardecer y amanecer, detectando calor corporal y dióxido de carbono exhalado.',
        ],
        healthRisks: [
          'Moscas transmiten cólera, disentería, fiebre tifoidea y parasitosis intestinal.',
          'Mosquitos son vectores de Dengue, Zika y Chikungunya.',
        ],
        signs: [
          'Presencia constante de moscas zumbando sobre mesas de preparación de alimentos.',
          'Larvas ("maromeros") retorciéndose en depósitos de agua estancada exterior.',
        ],
        preventionTips: [
          'Mantener botes de basura con bolsa plástica y tapadera hermética cerrada en todo momento.',
          'Eliminar cualquier cacharro o recipiente que acumule agua de lluvia en techos o patios.',
          'Instalar mosquiteros en ventanas y cortinas de aire en puertas de restaurantes.',
        ],
        professionalTreatment: 'Programa Integral EJ: Aplicación de cebos mosquicidas específicos, termonebulización espacial exterior y larvicidas biológicos en cuerpos de agua para romper el ciclo biológico.',
      ),
    ];
  }
}
