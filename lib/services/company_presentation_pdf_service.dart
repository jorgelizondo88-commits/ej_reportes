import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class CompanyPresentationPdfService {
  static const PdfColor primaryNavy = PdfColor.fromInt(0xFF0F2B48);
  static const PdfColor secondaryBlue = PdfColor.fromInt(0xFF1E6091);
  static const PdfColor accentGold = PdfColor.fromInt(0xFFD97706);
  static const PdfColor darkText = PdfColor.fromInt(0xFF1E293B);
  static const PdfColor lightBg = PdfColor.fromInt(0xFFF8FAFC);
  static const PdfColor cardBorder = PdfColor.fromInt(0xFFCBD5E1);
  static const PdfColor softBadgeBg = PdfColor.fromInt(0xFFEFF6FF);
  static const PdfColor alertRed = PdfColor.fromInt(0xFFB91C1C);

  static Future<Uint8List> generatePresentationPdf() async {
    final pdf = pw.Document();

    pw.ImageProvider? logoImage;
    pw.ImageProvider? technicianImage;
    pw.ImageProvider? inspectionImage;

    try {
      final logoBytes = await rootBundle.load('assets/images/logo.png');
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (_) {}

    try {
      final techBytes = await rootBundle.load('assets/images/presentation_technician_clean.jpg');
      technicianImage = pw.MemoryImage(techBytes.buffer.asUint8List());
    } catch (_) {}

    try {
      final inspectBytes = await rootBundle.load('assets/images/presentation_inspection_clean.jpg');
      inspectionImage = pw.MemoryImage(inspectBytes.buffer.asUint8List());
    } catch (_) {}

    final pageTheme = pw.PageTheme(
      pageFormat: PdfPageFormat.letter.landscape,
      margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      theme: pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
        italic: pw.Font.helveticaOblique(),
      ),
    );

    // ==========================================
    // DIAPOSITIVA 1: PORTADA EJECUTIVA Y CREDENCIALES
    // ==========================================
    pdf.addPage(
      pw.Page(
        pageTheme: pageTheme,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Encabezado Hero: Logo Grande + Nombre Imponente
              pw.Container(
                padding: const pw.EdgeInsets.only(bottom: 8),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(color: secondaryBlue, width: 2)),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    if (logoImage != null)
                      pw.Container(
                        height: 85,
                        width: 90,
                        child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                      ),
                    pw.SizedBox(width: 14),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'EJ EXTERMINADORES',
                            style: pw.TextStyle(
                              fontSize: 27,
                              fontWeight: pw.FontWeight.bold,
                              color: primaryNavy,
                              letterSpacing: 1.2,
                            ),
                          ),
                          pw.Text(
                            'MANEJO INTEGRADO DE PLAGAS URBANAS E INDUSTRIALES (MIP)',
                            style: pw.TextStyle(
                              fontSize: 10.5,
                              fontWeight: pw.FontWeight.bold,
                              color: secondaryBlue,
                              letterSpacing: 0.6,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'Servicios Profesionales de Bioseguridad Ambiental, Control Sanitario y Auditorias de Inocuidad',
                            style: pw.TextStyle(
                              fontSize: 8.5,
                              color: darkText,
                              fontStyle: pw.FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: pw.BoxDecoration(
                        color: const PdfColor.fromInt(0xFFFEF3C7),
                        borderRadius: pw.BorderRadius.circular(6),
                        border: pw.Border.all(color: const PdfColor.fromInt(0xFFFCD34D), width: 1),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Text('TRAYECTORIA OFICIAL', style: pw.TextStyle(fontSize: 7.0, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF92400E))),
                          pw.Text('9 ANOS', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF92400E))),
                          pw.Text('EN NUEVO LEON', style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF92400E))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),

              // Cuerpo de la Portada
              pw.Expanded(
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Columna Izquierda: Información de la Propuesta
                    pw.Expanded(
                      flex: 6,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Container(
                            width: double.infinity,
                            padding: const pw.EdgeInsets.all(10),
                            decoration: pw.BoxDecoration(
                              color: lightBg,
                              borderRadius: pw.BorderRadius.circular(6),
                              border: pw.Border.all(color: cardBorder, width: 0.8),
                            ),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  'DOSSIER CORPORATIVO Y PROPUESTA INTEGRAL DE SERVICIOS',
                                  style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: primaryNavy),
                                ),
                                pw.SizedBox(height: 4),
                                pw.Text(
                                  'En EJ Exterminadores brindamos blindaje sanitario y programas preventivos continuos de Manejo Integrado de Plagas para plantas de manufactura, centros de distribucion, naves logisticas, restaurantes, colegios, oficinas corporativas y residencias. Combinamos 9 anos de experiencia de campo en Monterrey con rigor de ingenieria y tecnologia movil para la entrega inmediata de reportes tecnicos foliados con evidencia fotografica.',
                                  style: const pw.TextStyle(fontSize: 8.0, color: darkText, lineSpacing: 1.18),
                                ),
                              ],
                            ),
                          ),
                          pw.SizedBox(height: 7),

                          // Cuadrícula de 4 Pilares / KPIs
                          pw.Row(
                            children: [
                              _buildKpiCard('9 ANOS', 'Trayectoria Comprobada', 'Liderazgo en el sector industrial, comercial y residencial en N.L.'),
                              pw.SizedBox(width: 6),
                              _buildKpiCard('100% COFEPRIS', 'Quimicos Certificados', 'Formulaciones microencapsuladas seguras y de baja toxicidad.'),
                            ],
                          ),
                          pw.SizedBox(height: 6),
                          pw.Row(
                            children: [
                              _buildKpiCard('NORMATIVIDAD', 'Apego NOM Oficial', 'Cumplimiento estricto con NOM-256-SSA1-2012 y NOM-251-SSA1-2009.'),
                              pw.SizedBox(width: 6),
                              _buildKpiCard('DIGITALIZACION', 'Reportes al Instante', 'Emision de reportes en PDF con fotos y firmas electronicas en sitio.'),
                            ],
                          ),
                          pw.SizedBox(height: 7),

                          // Sectores Atendidos
                          pw.Container(
                            width: double.infinity,
                            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
                            decoration: pw.BoxDecoration(
                              color: softBadgeBg,
                              borderRadius: pw.BorderRadius.circular(4),
                              border: pw.Border.all(color: const PdfColor.fromInt(0xFFBFDBFE), width: 0.7),
                            ),
                            child: pw.Text(
                              'COBERTURA: Parques Industriales  |  Plantas de Alimentos  |  Bodegas  |  Restaurantes  |  Colegios  |  Hospitales  |  Residencial',
                              style: pw.TextStyle(fontSize: 7.2, fontWeight: pw.FontWeight.bold, color: primaryNavy),
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 14),

                    // Columna Derecha: Fotografía Profesional + Ficha del Responsable
                    pw.Expanded(
                      flex: 4,
                      child: pw.Column(
                        children: [
                          pw.Expanded(
                            child: pw.Container(
                              decoration: pw.BoxDecoration(
                                borderRadius: pw.BorderRadius.circular(6),
                                border: pw.Border.all(color: primaryNavy, width: 1.5),
                              ),
                              child: pw.ClipRRect(
                                horizontalRadius: 5,
                                verticalRadius: 5,
                                child: technicianImage != null
                                    ? pw.Image(technicianImage, fit: pw.BoxFit.cover)
                                    : pw.Container(color: lightBg),
                              ),
                            ),
                          ),
                          pw.SizedBox(height: 6),
                          pw.Container(
                            width: double.infinity,
                            padding: const pw.EdgeInsets.all(8),
                            decoration: pw.BoxDecoration(
                              color: primaryNavy,
                              borderRadius: pw.BorderRadius.circular(6),
                            ),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  'DIRECCION TECNICA Y OPERATIVA:',
                                  style: pw.TextStyle(fontSize: 7.0, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFFFCD34D)),
                                ),
                                pw.SizedBox(height: 2),
                                pw.Text(
                                  'ING. JORGE ELIZONDO / REP. TECNICO',
                                  style: pw.TextStyle(fontSize: 9.0, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                                ),
                                pw.Text(
                                  'Responsable de Bioseguridad y Salud Ambiental',
                                  style: const pw.TextStyle(fontSize: 7.0, color: PdfColors.grey300),
                                ),
                                pw.SizedBox(height: 3),
                                pw.Text(
                                  'Tel. Directo / WhatsApp: 813-175-9342',
                                  style: pw.TextStyle(fontSize: 8.0, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFFFCD34D)),
                                ),
                                pw.Text(
                                  'www.ejexterminadores.com  |  Monterrey, N.L.',
                                  style: const pw.TextStyle(fontSize: 7.0, color: PdfColors.grey300),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 6),
              _buildSlideFooter(1, 5),
            ],
          );
        },
      ),
    );

    // ==========================================
    // DIAPOSITIVA 2: QUIÉNES SOMOS, MISIÓN Y VALORES
    // ==========================================
    pdf.addPage(
      pw.Page(
        pageTheme: pageTheme,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildSlideHeader(logoImage, 'QUIENES SOMOS, MISION Y PILARES CORPORATIVOS', '9 Anos de Experiencia Transformando el Control de Plagas en una Disciplina Cientifica'),
              pw.SizedBox(height: 8),
              pw.Expanded(
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Columna Izquierda: Historia y Marco Legal
                    pw.Expanded(
                      flex: 5,
                      child: pw.Column(
                        children: [
                          _buildSectionCard(
                            title: 'NUESTRA TRAYECTORIA (9 ANOS EN NUEVO LEON)',
                            iconColor: primaryNavy,
                            child: pw.Text(
                              'EJ Exterminadores nacio con la firme conviccion de erradicar la improvisacion en los servicios de fumigacion. Durante casi una decada de operaciones ininterrumpidas en Monterrey y municipios conurbados, hemos desarrollado metodologias avanzadas de Manejo Integrado de Plagas (MIP) que combinan la inspeccion biologica de instalaciones, correccion de habitos higienicos, exclusion fisica estructural y la aplicacion precisa de quimicos microencapsulados de bajo impacto ambiental.',
                              style: const pw.TextStyle(fontSize: 7.8, color: darkText, lineSpacing: 1.18),
                            ),
                          ),
                          pw.SizedBox(height: 6),
                          _buildSectionCard(
                            title: 'MARCO NORMATIVO Y AUDITORIAS SANITARIAS',
                            iconColor: secondaryBlue,
                            child: pw.Text(
                              'Todos nuestros protocolos estan estrictamente alineados con la NOM-256-SSA1-2012 (Servicios urbanos de control de plagas) y la NOM-251-SSA1-2009 (Practicas de higiene en alimentos y bebidas). Proveemos carpetas tecnicas foliadas, planos de reubicacion de estaciones cebaderas y Hojas de Datos de Seguridad (HDS) exigidas en auditorias de calidad como Distintivo H, Buenas Practicas de Manufactura (BPM) y certificaciones ISO.',
                              style: const pw.TextStyle(fontSize: 7.8, color: darkText, lineSpacing: 1.18),
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 12),

                    // Columna Derecha: Misión, Visión y Valores
                    pw.Expanded(
                      flex: 5,
                      child: pw.Column(
                        children: [
                          _buildSectionCard(
                            title: 'NUESTRA MISION',
                            iconColor: primaryNavy,
                            child: pw.Text(
                              'Salvaguardar la salud publica, la continuidad operativa y los estandares de inocuidad de nuestros clientes mediante tratamientos de vanguardia, seguros para las personas, inocuos para los alimentos y con estricto respeto al medio ambiente.',
                              style: const pw.TextStyle(fontSize: 7.8, color: darkText, lineSpacing: 1.18),
                            ),
                          ),
                          pw.SizedBox(height: 6),
                          _buildSectionCard(
                            title: 'NUESTRA VISION',
                            iconColor: secondaryBlue,
                            child: pw.Text(
                              'Consolidarnos como el socio estrategico de referencia en el norte de Mexico en gestion sanitaria y prevencion biologica, siendo reconocidos por nuestra capacidad tecnica de ingenieria, cumplimiento normativo y etica profesional inquebrantable.',
                              style: const pw.TextStyle(fontSize: 7.8, color: darkText, lineSpacing: 1.18),
                            ),
                          ),
                          pw.SizedBox(height: 6),
                          pw.Container(
                            width: double.infinity,
                            padding: const pw.EdgeInsets.all(7),
                            decoration: pw.BoxDecoration(
                              color: const PdfColor.fromInt(0xFFFEF3C7),
                              borderRadius: pw.BorderRadius.circular(6),
                              border: pw.Border.all(color: const PdfColor.fromInt(0xFFFCD34D), width: 0.8),
                            ),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  'NUESTROS 5 VALORES:',
                                  style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF92400E)),
                                ),
                                pw.SizedBox(height: 2),
                                pw.Text(
                                  '1. Rigor Cientifico  |  2. Honestidad Sanitaria  |  3. Puntualidad en Polizas  |  4. Bioproteccion Integral  |  5. Alianza Bilateral',
                                  style: pw.TextStyle(fontSize: 7.2, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF78350F)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 6),
              _buildSlideFooter(2, 5),
            ],
          );
        },
      ),
    );

    // ==========================================
    // DIAPOSITIVA 3: CATÁLOGO COMPLETO POR SECTOR
    // ==========================================
    pdf.addPage(
      pw.Page(
        pageTheme: pageTheme,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildSlideHeader(logoImage, 'CATALOGO DE SOLUCIONES ESPECIALIZADAS POR SECTOR', 'Programas Integrales Disenados para Responder a las Exigencias de Cada Giro'),
              pw.SizedBox(height: 8),
              pw.Expanded(
                child: pw.Row(
                  children: [
                    // Columna 1
                    pw.Expanded(
                      child: pw.Column(
                        children: [
                          _buildSectorCard(
                            tag: '[INDUSTRIA]',
                            sectorTitle: 'Sector Industrial, Naves & Parques Logisticos',
                            features: [
                              'Polizas periodicas mensuales y bimestrales bajo contrato legal formal.',
                              'Cordones de bioseguridad perimetral exterior y estaciones cebaderas de alta seguridad.',
                              'Carpetas tecnicas y bitacoras para auditorias (Distintivo H, BPM, AIB, ISO 22000).',
                              'Control de fauna nociva en andenes, cuartos de maquinas y almacenes de producto.',
                              'Plagas objetivo: Roedores (ratas/ratones), cucarachas, alacranes, cienpies y arañas.',
                            ],
                          ),
                          pw.SizedBox(height: 6),
                          _buildSectorCard(
                            tag: '[ALIMENTOS]',
                            sectorTitle: 'Sector Restaurantero, Cocinas & Alimentos',
                            features: [
                              'Erradicacion de cucaracha alemana con cebos en gel de microdosis sin suspender labores.',
                              'Cero contaminacion cruzada en cubiertas de preparacion de alimentos y camaras frias.',
                              'Instalacion y monitoreo de trampas de luz ultravioleta (UV) para insectos voladores.',
                              'Certificado oficial de servicio para inspecciones sanitarias municipales y de salubridad.',
                              'Mapeo de puntos criticos de grasa y recomendaciones de exclusion estructural.',
                            ],
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 10),

                    // Columna 2
                    pw.Expanded(
                      child: pw.Column(
                        children: [
                          _buildSectorCard(
                            tag: '[EDUCATIVO]',
                            sectorTitle: 'Sector Educativo, Colegios & Guarderias',
                            features: [
                              'Aplicaciones programadas en contraturno, fines de semana o periodos vacacionales.',
                              'Formulaciones inodoras de grado hospitalario, sin solventes agresivos ni vapores.',
                              'Control perimetral de alacranes, cienpies, arañas y mosquitos vectores de dengue.',
                              'Seguridad comprobada para el alumnado infantil, personal docente y administrativo.',
                              'Desinfeccion patogena y sanitizacion preventiva en salones, comedores y banos.',
                            ],
                          ),
                          pw.SizedBox(height: 6),
                          _buildSectorCard(
                            tag: '[RESIDENCIAL]',
                            sectorTitle: 'Sector Residencial, Quintas & Fraccionamientos',
                            features: [
                              'Blindaje de choque y barrera residual perimetral contra fauna nociva silvestre.',
                              'Tratamientos especializados para termitas subterraneas y de madera seca con garantia.',
                              'Protocolos seguros para mascotas (pet-friendly), areas verdes y plantas familiares.',
                              'Erradicacion de chinches de cama y pulgas con tecnicas de aspersion y nebulizacion.',
                              'Inspeccion y sellado de accesos en bardas perimetrales, jardines y registros.',
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 6),
              _buildSlideFooter(3, 5),
            ],
          );
        },
      ),
    );

    // ==========================================
    // DIAPOSITIVA 4: METODOLOGÍA "MIP" Y TECNOLOGÍA
    // ==========================================
    pdf.addPage(
      pw.Page(
        pageTheme: pageTheme,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildSlideHeader(logoImage, 'METODOLOGIA CIENTIFICA "MIP" Y TECNOLOGIA DIGITAL EN CAMPO', '4 Fases de Precision Tecnica que Garantizan Resultados Cientificos Duraderos'),
              pw.SizedBox(height: 8),
              pw.Expanded(
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Columna Izquierda: Las 4 Fases
                    pw.Expanded(
                      flex: 6,
                      child: pw.Column(
                        children: [
                          _buildStepItem(
                            stepNumber: '1',
                            stepTitle: 'Inspeccion & Diagnostico Estructural',
                            description: 'Evaluacion exhaustiva de instalaciones: deteccion de especies, focos de humedad, fuentes de alimento, grietas y vias de acceso biologico antes de aplicar quimicos.',
                          ),
                          pw.SizedBox(height: 5),
                          _buildStepItem(
                            stepNumber: '2',
                            stepTitle: 'Intervencion Tactica Focalizada & Exclusion',
                            description: 'Uso de formulaciones microencapsuladas y cebos parafinados aprobados por COFEPRIS en areas de refugio. Recomendaciones de exclusion fisica (guardapolvos, sellos en tuberias).',
                          ),
                          pw.SizedBox(height: 5),
                          _buildStepItem(
                            stepNumber: '3',
                            stepTitle: 'Trazabilidad & Reportes Digitales en Tiempo Real',
                            description: 'Con nuestra plataforma movil propia, entregamos reportes inmediatos en PDF con fotografias antes/despues del servicio, consumo de cebaderos y firmas electronicas (S-Pen).',
                          ),
                          pw.SizedBox(height: 5),
                          _buildStepItem(
                            stepNumber: '4',
                            stepTitle: 'Garantia por Poliza & Blindaje Continuo',
                            description: 'Respaldo legal por escrito mediante contrato. Monitoreo regular de estaciones cebaderas y refuerzos tecnicos sin costo adicional ante cualquier eventualidad extraordinaria.',
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 12),

                    // Columna Derecha: Fotografía y Respaldo Normativo
                    pw.Expanded(
                      flex: 4,
                      child: pw.Column(
                        children: [
                          pw.Expanded(
                            child: pw.Container(
                              decoration: pw.BoxDecoration(
                                borderRadius: pw.BorderRadius.circular(6),
                                border: pw.Border.all(color: primaryNavy, width: 1.5),
                              ),
                              child: pw.ClipRRect(
                                horizontalRadius: 5,
                                verticalRadius: 5,
                                child: inspectionImage != null
                                    ? pw.Image(inspectionImage, fit: pw.BoxFit.cover)
                                    : pw.Container(color: lightBg),
                              ),
                            ),
                          ),
                          pw.SizedBox(height: 6),
                          pw.Container(
                            width: double.infinity,
                            padding: const pw.EdgeInsets.all(8),
                            decoration: pw.BoxDecoration(
                              color: const PdfColor.fromInt(0xFFEEF2FF),
                              borderRadius: pw.BorderRadius.circular(6),
                              border: pw.Border.all(color: const PdfColor.fromInt(0xFFA5B4FC), width: 0.8),
                            ),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  'CUMPLIMIENTO Y BIOSEGURIDAD OFICIAL:',
                                  style: pw.TextStyle(fontSize: 7.8, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF3730A3)),
                                ),
                                pw.SizedBox(height: 2),
                                pw.Text(
                                  'Operamos bajo la NOM-256-SSA1-2012 y NOM-251-SSA1-2009. Fichas tecnicas de seguridad (HDS) disponibles para cada ingrediente activo aplicado en sus instalaciones.',
                                  style: const pw.TextStyle(fontSize: 7.2, color: darkText, lineSpacing: 1.15),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 6),
              _buildSlideFooter(4, 5),
            ],
          );
        },
      ),
    );

    // ==========================================
    // DIAPOSITIVA 5: POR QUÉ ELEGIRNOS Y CONTACTO
    // ==========================================
    pdf.addPage(
      pw.Page(
        pageTheme: pageTheme,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildSlideHeader(logoImage, 'POR QUE ELEGIR A EJ EXTERMINADORES?', 'Confianza, Respaldo Tecnico y Atencion Directa en Todo Nuevo Leon'),
              pw.SizedBox(height: 8),
              pw.Expanded(
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Columna Izquierda: 6 Ventajas Diferenciadoras
                    pw.Expanded(
                      flex: 6,
                      child: pw.Column(
                        children: [
                          pw.Row(
                            children: [
                              _buildAdvantageCard('9 Anos de Experiencia', 'Trayectoria solida y comprobada en Monterrey y su zona metropolitana.'),
                              pw.SizedBox(width: 6),
                              _buildAdvantageCard('Supervision de Ingenieria', 'Asesoria tecnica directa por el Ing. Jorge Elizondo / Rep. Tecnico.'),
                            ],
                          ),
                          pw.SizedBox(height: 6),
                          pw.Row(
                            children: [
                              _buildAdvantageCard('Reportes Digitales al Instante', 'Generacion inmediata de reportes con fotos y firmas electronicas.'),
                              pw.SizedBox(width: 6),
                              _buildAdvantageCard('Formulaciones Autorizadas', 'Ingredientes activos grado industrial registrados ante COFEPRIS.'),
                            ],
                          ),
                          pw.SizedBox(height: 6),
                          pw.Row(
                            children: [
                              _buildAdvantageCard('Polizas y Credito Comercial', 'Contratos formales digitales con facilidades de pago (credito 15 o 30 dias).'),
                              pw.SizedBox(width: 6),
                              _buildAdvantageCard('Garantia Total por Escrito', 'Refuerzos tecnicos sin costo ante cualquier eventualidad extraordinaria.'),
                            ],
                          ),
                          pw.SizedBox(height: 6),
                          pw.Container(
                            width: double.infinity,
                            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            decoration: pw.BoxDecoration(
                              color: softBadgeBg,
                              borderRadius: pw.BorderRadius.circular(6),
                              border: pw.Border.all(color: const PdfColor.fromInt(0xFFBFDBFE), width: 0.8),
                            ),
                            child: pw.Row(
                              children: [
                                pw.Text('COBERTURA METROPOLITANA: ', style: pw.TextStyle(fontSize: 7.2, fontWeight: pw.FontWeight.bold, color: primaryNavy)),
                                pw.Expanded(
                                  child: pw.Text(
                                    'Monterrey, San Pedro, Santa Catarina, Guadalupe, San Nicolas, Apodaca, Escobedo y Garcia.',
                                    style: const pw.TextStyle(fontSize: 7.0, color: darkText),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 12),

                    // Columna Derecha: Tarjeta de Contacto Directo
                    pw.Expanded(
                      flex: 4,
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(12),
                        decoration: pw.BoxDecoration(
                          color: primaryNavy,
                          borderRadius: pw.BorderRadius.circular(8),
                          boxShadow: const [
                            pw.BoxShadow(color: PdfColors.grey400, blurRadius: 4, offset: PdfPoint(0, 2)),
                          ],
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  'SOLICITE SU INSPECCION Y COTIZACION',
                                  style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFFFCD34D)),
                                ),
                                pw.SizedBox(height: 3),
                                pw.Text(
                                  'Atencion Inmediata a Empresas, Colegios y Comercios:',
                                  style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.white),
                                ),
                                pw.SizedBox(height: 8),
                                _buildContactLine('Telefono / WhatsApp:', '813-175-9342 (Atencion Inmediata)'),
                                _buildContactLine('Responsable Tecnico:', 'Ing. Jorge Elizondo / Rep. Tecnico'),
                                _buildContactLine('Correo Electronico:', 'contacto@ejexterminadores.com'),
                                _buildContactLine('Sitio Web Oficial:', 'www.ejexterminadores.com'),
                                _buildContactLine('Horario de Atencion:', 'Lunes a Sabado de 8:00 a 19:00 hrs'),
                              ],
                            ),
                            pw.Container(
                              width: double.infinity,
                              padding: const pw.EdgeInsets.symmetric(vertical: 6),
                              decoration: pw.BoxDecoration(
                                color: secondaryBlue,
                                borderRadius: pw.BorderRadius.circular(4),
                              ),
                              child: pw.Text(
                                'VISITA DE DIAGNOSTICO SIN COMPROMISO',
                                textAlign: pw.TextAlign.center,
                                style: pw.TextStyle(fontSize: 8.0, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 6),
              _buildSlideFooter(5, 5),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // ==========================================
  // WIDGETS AUXILIARES DE DISEÑO
  // ==========================================
  static pw.Widget _buildSlideHeader(pw.ImageProvider? logoImage, String title, String subtitle) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 5),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: secondaryBlue, width: 1.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                title,
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: primaryNavy),
              ),
              pw.SizedBox(height: 1.5),
              pw.Text(
                subtitle,
                style: pw.TextStyle(fontSize: 8.0, color: secondaryBlue, fontStyle: pw.FontStyle.italic),
              ),
            ],
          ),
          if (logoImage != null)
            pw.Container(height: 28, child: pw.Image(logoImage, fit: pw.BoxFit.contain)),
        ],
      ),
    );
  }

  static pw.Widget _buildSlideFooter(int currentPage, int totalPages) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 4),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: cardBorder, width: 0.8)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'EJ Exterminadores | Manejo Integrado de Plagas | Monterrey, N.L. | Tel: 813-175-9342',
            style: const pw.TextStyle(fontSize: 7.2, color: PdfColors.grey700),
          ),
          pw.Text(
            'Pagina $currentPage de $totalPages',
            style: pw.TextStyle(fontSize: 7.2, fontWeight: pw.FontWeight.bold, color: primaryNavy),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildKpiCard(String metric, String title, String description) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(6),
        decoration: pw.BoxDecoration(
          color: lightBg,
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: cardBorder, width: 0.8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(metric, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: primaryNavy)),
            pw.Text(title, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: secondaryBlue)),
            pw.SizedBox(height: 1.5),
            pw.Text(description, style: const pw.TextStyle(fontSize: 6.8, color: darkText, lineSpacing: 1.1)),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildSectionCard({required String title, required PdfColor iconColor, required pw.Widget child}) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: lightBg,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: cardBorder, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 8.2, fontWeight: pw.FontWeight.bold, color: iconColor),
          ),
          pw.SizedBox(height: 3),
          child,
        ],
      ),
    );
  }

  static pw.Widget _buildSectorCard({required String tag, required String sectorTitle, required List<String> features}) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(7),
      decoration: pw.BoxDecoration(
        color: lightBg,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: cardBorder, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: const pw.BoxDecoration(color: primaryNavy),
                child: pw.Text(tag, style: pw.TextStyle(fontSize: 6.8, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
              ),
              pw.SizedBox(width: 5),
              pw.Expanded(
                child: pw.Text(
                  sectorTitle,
                  style: pw.TextStyle(fontSize: 8.2, fontWeight: pw.FontWeight.bold, color: primaryNavy),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 3.5),
          ...features.map((feat) {
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 2),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('- ', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: secondaryBlue)),
                  pw.Expanded(
                    child: pw.Text(feat, style: const pw.TextStyle(fontSize: 7.2, color: darkText, lineSpacing: 1.1)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  static pw.Widget _buildStepItem({required String stepNumber, required String stepTitle, required String description}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6.5),
      decoration: pw.BoxDecoration(
        color: lightBg,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: cardBorder, width: 0.8),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 18,
            height: 18,
            alignment: pw.Alignment.center,
            decoration: const pw.BoxDecoration(color: primaryNavy, shape: pw.BoxShape.circle),
            child: pw.Text(stepNumber, style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(stepTitle, style: pw.TextStyle(fontSize: 8.2, fontWeight: pw.FontWeight.bold, color: primaryNavy)),
                pw.SizedBox(height: 1.5),
                pw.Text(description, style: const pw.TextStyle(fontSize: 7.2, color: darkText, lineSpacing: 1.1)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildAdvantageCard(String title, String desc) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(6),
        decoration: pw.BoxDecoration(
          color: lightBg,
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: cardBorder, width: 0.8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title, style: pw.TextStyle(fontSize: 7.8, fontWeight: pw.FontWeight.bold, color: secondaryBlue)),
            pw.SizedBox(height: 2),
            pw.Text(desc, style: const pw.TextStyle(fontSize: 7.0, color: darkText, lineSpacing: 1.1)),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildContactLine(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3.5),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 7.0, color: PdfColors.grey300)),
          pw.Text(value, style: pw.TextStyle(fontSize: 8.0, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
        ],
      ),
    );
  }
}
