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
      margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
                  border: pw.Border(bottom: pw.BorderSide(color: secondaryBlue, width: 2.5)),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    if (logoImage != null)
                      pw.Container(
                        height: 90,
                        width: 95,
                        child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                      ),
                    pw.SizedBox(width: 16),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'EJ EXTERMINADORES',
                            style: pw.TextStyle(
                              fontSize: 32,
                              fontWeight: pw.FontWeight.bold,
                              color: primaryNavy,
                              letterSpacing: 1.2,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'MANEJO INTEGRADO DE PLAGAS URBANAS E INDUSTRIALES (MIP)',
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              color: secondaryBlue,
                              letterSpacing: 0.6,
                            ),
                          ),
                          pw.SizedBox(height: 3),
                          pw.Text(
                            'Servicios Profesionales de Bioseguridad Ambiental, Control Sanitario y Auditorías de Inocuidad',
                            style: pw.TextStyle(
                              fontSize: 10,
                              color: darkText,
                              fontStyle: pw.FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: pw.BoxDecoration(
                        color: const PdfColor.fromInt(0xFFFEF3C7),
                        borderRadius: pw.BorderRadius.circular(8),
                        border: pw.Border.all(color: const PdfColor.fromInt(0xFFFCD34D), width: 1.2),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Text('TRAYECTORIA', style: pw.TextStyle(fontSize: 8.0, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF92400E))),
                          pw.Text('9 AÑOS', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF92400E))),
                          pw.Text('EN NUEVO LEÓN', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF92400E))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),

              // Cuerpo de la Portada: Expandido para ocupar toda la altura
              pw.Expanded(
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    // Columna Izquierda: Información de la Propuesta
                    pw.Expanded(
                      flex: 6,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Container(
                            width: double.infinity,
                            padding: const pw.EdgeInsets.all(12),
                            decoration: pw.BoxDecoration(
                              color: lightBg,
                              borderRadius: pw.BorderRadius.circular(8),
                              border: pw.Border.all(color: cardBorder, width: 1.0),
                            ),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  'DOSSIER CORPORATIVO Y PROPUESTA INTEGRAL DE SERVICIOS',
                                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: primaryNavy),
                                ),
                                pw.SizedBox(height: 6),
                                pw.Text(
                                  'En EJ Exterminadores brindamos blindaje sanitario y programas preventivos continuos de Manejo Integrado de Plagas para plantas de manufactura, centros de distribución, naves logísticas, restaurantes, colegios, oficinas corporativas y residencias. Combinamos 9 años de experiencia de campo en Monterrey con rigor de ingeniería y tecnología móvil para la entrega inmediata de reportes técnicos foliados con evidencia fotográfica.',
                                  style: const pw.TextStyle(fontSize: 10, color: darkText, lineSpacing: 1.35),
                                ),
                              ],
                            ),
                          ),
                          pw.SizedBox(height: 10),

                          // Cuadrícula de 4 Pilares / KPIs con Expanded vertical
                          pw.Expanded(
                            child: pw.Column(
                              children: [
                                pw.Expanded(
                                  child: pw.Row(
                                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                                    children: [
                                      _buildKpiCard('9 AÑOS', 'Trayectoria Comprobada', 'Liderazgo consolidado en el sector industrial, comercial y residencial en Nuevo León.'),
                                      pw.SizedBox(width: 8),
                                      _buildKpiCard('100% COFEPRIS', 'Químicos Certificados', 'Formulaciones microencapsuladas seguras, inodoras y de baja toxicidad humana.'),
                                    ],
                                  ),
                                ),
                                pw.SizedBox(height: 8),
                                pw.Expanded(
                                  child: pw.Row(
                                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                                    children: [
                                      _buildKpiCard('NORMATIVIDAD NOM', 'Apego Oficial Estricto', 'Cumplimiento cabal con NOM-256-SSA1-2012 y NOM-251-SSA1-2009 para auditorías.'),
                                      pw.SizedBox(width: 8),
                                      _buildKpiCard('DIGITALIZACIÓN', 'Reportes al Instante', 'Emisión de reportes en PDF con fotos de evidencia y firmas electrónicas en sitio.'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          pw.SizedBox(height: 10),

                          // Sectores Atendidos
                          pw.Container(
                            width: double.infinity,
                            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: pw.BoxDecoration(
                              color: softBadgeBg,
                              borderRadius: pw.BorderRadius.circular(6),
                              border: pw.Border.all(color: const PdfColor.fromInt(0xFFBFDBFE), width: 1.0),
                            ),
                            child: pw.Text(
                              'COBERTURA: Parques Industriales  |  Plantas de Alimentos  |  Bodegas  |  Restaurantes  |  Colegios  |  Hospitales  |  Residencial',
                              style: pw.TextStyle(fontSize: 9.0, fontWeight: pw.FontWeight.bold, color: primaryNavy),
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
                                borderRadius: pw.BorderRadius.circular(8),
                                border: pw.Border.all(color: primaryNavy, width: 1.5),
                              ),
                              child: pw.ClipRRect(
                                horizontalRadius: 7,
                                verticalRadius: 7,
                                child: technicianImage != null
                                    ? pw.Image(technicianImage, fit: pw.BoxFit.cover)
                                    : pw.Container(color: lightBg),
                              ),
                            ),
                          ),
                          pw.SizedBox(height: 8),
                          pw.Container(
                            width: double.infinity,
                            padding: const pw.EdgeInsets.all(12),
                            decoration: pw.BoxDecoration(
                              color: primaryNavy,
                              borderRadius: pw.BorderRadius.circular(8),
                            ),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  'DIRECCIÓN TÉCNICA Y OPERATIVA:',
                                  style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFFFCD34D)),
                                ),
                                pw.SizedBox(height: 3),
                                pw.Text(
                                  'ING. JORGE ELIZONDO / REP. TÉCNICO',
                                  style: pw.TextStyle(fontSize: 11.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                                ),
                                pw.Text(
                                  'Responsable de Bioseguridad y Salud Ambiental',
                                  style: const pw.TextStyle(fontSize: 9.0, color: PdfColors.grey300),
                                ),
                                pw.SizedBox(height: 5),
                                pw.Text(
                                  'Tel. Directo / WhatsApp: 813-175-9342',
                                  style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFFFCD34D)),
                                ),
                                pw.Text(
                                  'www.ejexterminadores.com  |  Monterrey, N.L.',
                                  style: const pw.TextStyle(fontSize: 9.0, color: PdfColors.grey300),
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
              pw.SizedBox(height: 8),
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
              _buildSlideHeader(logoImage, 'QUIÉNES SOMOS, MISIÓN Y PILARES CORPORATIVOS', '9 Años de Experiencia Transformando el Control de Plagas en una Disciplina Científica'),
              pw.SizedBox(height: 10),
              pw.Expanded(
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    // Columna Izquierda: Historia y Marco Legal (2 tarjetas que llenan la altura)
                    pw.Expanded(
                      flex: 5,
                      child: pw.Column(
                        children: [
                          pw.Expanded(
                            child: _buildSectionCard(
                              title: 'NUESTRA TRAYECTORIA (9 AÑOS EN NUEVO LEÓN)',
                              iconColor: primaryNavy,
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                                children: [
                                  pw.Text(
                                    'EJ Exterminadores nació con la firme convicción de erradicar la improvisación en los servicios de control de plagas en Monterrey y municipios conurbados de Nuevo León.',
                                    style: const pw.TextStyle(fontSize: 10.2, color: darkText, lineSpacing: 1.35),
                                  ),
                                  pw.Text(
                                    'Durante 9 años ininterrumpidos en el mercado, hemos perfeccionado programas de Manejo Integrado de Plagas (MIP) sustentados en biología aplicada, exclusión física estructural y productos de última generación con residualidad prolongada.',
                                    style: const pw.TextStyle(fontSize: 10.2, color: darkText, lineSpacing: 1.35),
                                  ),
                                  pw.Text(
                                    'Nuestro compromiso es brindar tranquilidad total y continuidad operativa a su negocio, garantizando instalaciones libres de fauna nociva con estándares que superan cualquier inspección sanitaria.',
                                    style: const pw.TextStyle(fontSize: 10.2, color: darkText, lineSpacing: 1.35),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          pw.SizedBox(height: 10),
                          pw.Expanded(
                            child: _buildSectionCard(
                              title: 'MARCO NORMATIVO Y AUDITORÍAS SANITARIAS',
                              iconColor: secondaryBlue,
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                                children: [
                                  pw.Text(
                                    'Operamos bajo riguroso cumplimiento de las Normas Oficiales Mexicanas de la Secretaría de Salud:',
                                    style: pw.TextStyle(fontSize: 10.2, fontWeight: pw.FontWeight.bold, color: primaryNavy),
                                  ),
                                  pw.Text(
                                    '- NOM-256-SSA1-2012: Condiciones sanitarias que deben cumplir los establecimientos y servicios urbanos de control de plagas.',
                                    style: const pw.TextStyle(fontSize: 9.8, color: darkText, lineSpacing: 1.3),
                                  ),
                                  pw.Text(
                                    '- NOM-251-SSA1-2009: Prácticas de higiene para el proceso de alimentos, bebidas o suplementos alimenticios.',
                                    style: const pw.TextStyle(fontSize: 9.8, color: darkText, lineSpacing: 1.3),
                                  ),
                                  pw.Text(
                                    'Entregamos carpetas técnicas completas con bitácoras foliadas, planos de estaciones cebaderas y Hojas de Datos de Seguridad (HDS) exigidas en auditorías Distintivo H, BPM, AIB e ISO 22000.',
                                    style: const pw.TextStyle(fontSize: 9.8, color: darkText, lineSpacing: 1.3),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 14),

                    // Columna Derecha: Misión, Visión y Valores (llenan toda la altura)
                    pw.Expanded(
                      flex: 5,
                      child: pw.Column(
                        children: [
                          pw.Expanded(
                            flex: 3,
                            child: _buildSectionCard(
                              title: 'NUESTRA MISIÓN',
                              iconColor: primaryNavy,
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                mainAxisAlignment: pw.MainAxisAlignment.center,
                                children: [
                                  pw.Text(
                                    'Salvaguardar la salud pública, la inocuidad de los alimentos y la continuidad operativa de nuestros clientes industriales, comerciales y residenciales mediante intervenciones técnicas de vanguardia, seguras para las personas, inocuas para los alimentos y con estricto respeto al medio ambiente.',
                                    style: const pw.TextStyle(fontSize: 10.2, color: darkText, lineSpacing: 1.35),
                                  ),
                                  pw.SizedBox(height: 6),
                                  pw.Text(
                                    '- Cero contaminación cruzada y máxima protección en cada servicio.\n- Atención técnica inmediata y asesoría post-servicio continua.',
                                    style: pw.TextStyle(fontSize: 9.5, color: secondaryBlue, fontStyle: pw.FontStyle.italic, lineSpacing: 1.25),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          pw.SizedBox(height: 8),
                          pw.Expanded(
                            flex: 3,
                            child: _buildSectionCard(
                              title: 'NUESTRA VISIÓN',
                              iconColor: secondaryBlue,
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                mainAxisAlignment: pw.MainAxisAlignment.center,
                                children: [
                                  pw.Text(
                                    'Consolidarnos como la empresa referente y de mayor prestigio técnico en Monterrey y el norte de México en gestión sanitaria y Manejo Integrado de Plagas, distinguiéndonos por nuestra puntualidad, rigor de ingeniería, trazabilidad digital y honestidad profesional inquebrantable.',
                                    style: const pw.TextStyle(fontSize: 10.2, color: darkText, lineSpacing: 1.35),
                                  ),
                                  pw.SizedBox(height: 6),
                                  pw.Text(
                                    'Aliados estratégicos de confianza para su empresa e infraestructura.',
                                    style: pw.TextStyle(fontSize: 9.5, color: primaryNavy, fontWeight: pw.FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          pw.SizedBox(height: 8),
                          pw.Expanded(
                            flex: 4,
                            child: pw.Container(
                              width: double.infinity,
                              padding: const pw.EdgeInsets.all(12),
                              decoration: pw.BoxDecoration(
                                color: const PdfColor.fromInt(0xFFFEF3C7),
                                borderRadius: pw.BorderRadius.circular(8),
                                border: pw.Border.all(color: const PdfColor.fromInt(0xFFFCD34D), width: 1.0),
                              ),
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                                children: [
                                  pw.Text(
                                    'NUESTROS 5 VALORES FUNDAMENTALES:',
                                    style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF92400E)),
                                  ),
                                  _buildValueRow('1. Rigor Científico', 'Diagnóstico biológico exhaustivo previo a cualquier aplicación.'),
                                  _buildValueRow('2. Honestidad Sanitaria', 'Dosis exactas y formulaciones 100% autorizadas ante COFEPRIS.'),
                                  _buildValueRow('3. Puntualidad en Pólizas', 'Cumplimiento irrestricto de calendarios y horarios pactados.'),
                                  _buildValueRow('4. Bioprotección Integral', 'Cero contaminación cruzada y seguridad total para el personal.'),
                                  _buildValueRow('5. Alianza Bilateral', 'Comunicación transparente, asesoría preventiva y garantía de respuesta.'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),
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
              _buildSlideHeader(logoImage, 'CATÁLOGO DE SOLUCIONES ESPECIALIZADAS POR SECTOR', 'Programas Integrales Diseñados para Responder a las Exigencias de Cada Giro'),
              pw.SizedBox(height: 10),
              pw.Expanded(
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    // Columna 1: Industria y Alimentos (llenan el 100% de la altura)
                    pw.Expanded(
                      child: pw.Column(
                        children: [
                          pw.Expanded(
                            child: _buildSectorCard(
                              tag: '[INDUSTRIA]',
                              sectorTitle: 'Sector Industrial, Naves & Parques Logísticos',
                              subtitle: 'Plantas de manufactura, centros de distribución (CEDIS), naves y almacenes.',
                              features: [
                                'Pólizas periódicas mensuales y bimestrales bajo contrato legal formal.',
                                'Cordones de bioseguridad perimetral exterior y estaciones cebaderas de alta seguridad.',
                                'Carpetas técnicas y bitácoras para auditorías (Distintivo H, BPM, AIB, ISO 22000).',
                                'Control focalizado de fauna nociva en andenes, cuartos de máquinas y producto terminado.',
                                'Plagas objetivo: Roedores (ratas/ratones), cucarachas, alacranes, ciempiés y arañas.',
                              ],
                            ),
                          ),
                          pw.SizedBox(height: 10),
                          pw.Expanded(
                            child: _buildSectorCard(
                              tag: '[ALIMENTOS]',
                              sectorTitle: 'Sector Restaurantero, Cocinas & Alimentos',
                              subtitle: 'Restaurantes, cafeterías, comedores industriales, comisariatos y procesadoras.',
                              features: [
                                'Erradicación de cucaracha alemana con cebos en gel de microdosis sin suspender labores.',
                                'Cero contaminación cruzada en cubiertas de preparación de alimentos y cámaras frías.',
                                'Instalación y monitoreo de trampas de luz ultravioleta (UV) para insectos voladores.',
                                'Certificado oficial de servicio para inspecciones sanitarias municipales y de salubridad.',
                                'Mapeo de puntos críticos de grasa y recomendaciones de exclusión estructural.',
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 12),

                    // Columna 2: Educativo y Residencial (llenan el 100% de la altura)
                    pw.Expanded(
                      child: pw.Column(
                        children: [
                          pw.Expanded(
                            child: _buildSectorCard(
                              tag: '[EDUCATIVO]',
                              sectorTitle: 'Sector Educativo, Colegios & Guarderías',
                              subtitle: 'Colegios particulares, universidades, estancias infantiles, guarderías y academias.',
                              features: [
                                'Aplicaciones programadas en contraturno escolar, fines de semana o vacaciones.',
                                'Formulaciones inodoras de grado hospitalario, sin solventes agresivos ni vapores.',
                                'Control perimetral de alacranes, ciempiés, arañas y mosquitos vectores de dengue.',
                                'Seguridad comprobada para el alumnado infantil, personal docente y administrativo.',
                                'Desinfección patógena y sanitización preventiva en salones, comedores y baños.',
                              ],
                            ),
                          ),
                          pw.SizedBox(height: 10),
                          pw.Expanded(
                            child: _buildSectorCard(
                              tag: '[RESIDENCIAL]',
                              sectorTitle: 'Sector Residencial, Quintas & Fraccionamientos',
                              subtitle: 'Residencias particulares, privadas, quintas campestres y torres de departamentos.',
                              features: [
                                'Blindaje de choque y barrera residual perimetral contra fauna nociva y plagas silvestres.',
                                'Tratamientos especializados para termitas subterráneas y de madera con póliza de garantía.',
                                'Protocolos seguros para mascotas (pet-friendly), áreas verdes y plantas familiares.',
                                'Erradicación de chinches de cama y pulgas con técnicas de aspersión y nebulización.',
                                'Inspección y sellado de accesos en bardas perimetrales, jardines y registros sanitarios.',
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),
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
              _buildSlideHeader(logoImage, 'METODOLOGÍA CIENTÍFICA "MIP" Y TECNOLOGÍA DIGITAL EN CAMPO', '4 Fases de Precisión Técnica que Garantizan Resultados Científicos Duraderos'),
              pw.SizedBox(height: 10),
              pw.Expanded(
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    // Columna Izquierda: Las 4 Fases (llenan toda la altura en 4 bloques Expanded)
                    pw.Expanded(
                      flex: 6,
                      child: pw.Column(
                        children: [
                          pw.Expanded(
                            child: _buildStepItem(
                              stepNumber: '1',
                              stepTitle: 'Fase 1: Inspección & Diagnóstico Estructural',
                              description: 'Evaluación exhaustiva de instalaciones: detección de especies, focos de humedad, fuentes de alimento, grietas y vías de acceso biológico antes de aplicar químicos.',
                              subtext: 'Herramientas: Mapeo de puntos críticos, detección de accesos y diagnóstico inicial.',
                            ),
                          ),
                          pw.SizedBox(height: 8),
                          pw.Expanded(
                            child: _buildStepItem(
                              stepNumber: '2',
                              stepTitle: 'Fase 2: Intervención Táctica Focalizada & Exclusión',
                              description: 'Aplicación dirigida de formulaciones microencapsuladas seguras y cebos parafinados COFEPRIS en sitios específicos de anidación, complementado con sellado físico.',
                              subtext: 'Acciones: Colocación de guardapolvos, sellos en tuberías y recomendaciones de higiene.',
                            ),
                          ),
                          pw.SizedBox(height: 8),
                          pw.Expanded(
                            child: _buildStepItem(
                              stepNumber: '3',
                              stepTitle: 'Fase 3: Trazabilidad & Reportes Digitales en Tiempo Real',
                              description: 'Entrega inmediata en PDF con fotos antes/después, evidencia del consumo en estaciones cebaderas, químicos aplicados con dosis exactas y firmas electrónicas en sitio.',
                              subtext: 'Beneficio: Archivo digital inmediato enviado por WhatsApp y correo para soporte de auditorías.',
                            ),
                          ),
                          pw.SizedBox(height: 8),
                          pw.Expanded(
                            child: _buildStepItem(
                              stepNumber: '4',
                              stepTitle: 'Fase 4: Garantía por Póliza & Blindaje Continuo',
                              description: 'Respaldo legal por contrato formal. Monitoreo regular de estaciones cebaderas y refuerzos técnicos correctivos sin costo adicional ante cualquier eventualidad.',
                              subtext: 'Garantía EJ: Visitas de refuerzo sin cargo adicional ante reincidencias extraordinarias.',
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 14),

                    // Columna Derecha: Fotografía y Respaldo Normativo (llenan toda la altura)
                    pw.Expanded(
                      flex: 4,
                      child: pw.Column(
                        children: [
                          pw.Expanded(
                            flex: 6,
                            child: pw.Container(
                              decoration: pw.BoxDecoration(
                                borderRadius: pw.BorderRadius.circular(8),
                                border: pw.Border.all(color: primaryNavy, width: 1.5),
                              ),
                              child: pw.ClipRRect(
                                horizontalRadius: 7,
                                verticalRadius: 7,
                                child: inspectionImage != null
                                    ? pw.Image(inspectionImage, fit: pw.BoxFit.cover)
                                    : pw.Container(color: lightBg),
                              ),
                            ),
                          ),
                          pw.SizedBox(height: 8),
                          pw.Expanded(
                            flex: 4,
                            child: pw.Container(
                              width: double.infinity,
                              padding: const pw.EdgeInsets.all(12),
                              decoration: pw.BoxDecoration(
                                color: const PdfColor.fromInt(0xFFEEF2FF),
                                borderRadius: pw.BorderRadius.circular(8),
                                border: pw.Border.all(color: const PdfColor.fromInt(0xFFA5B4FC), width: 1.0),
                              ),
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                                children: [
                                  pw.Text(
                                    'CUMPLIMIENTO Y BIOSEGURIDAD OFICIAL:',
                                    style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF3730A3)),
                                  ),
                                  pw.Text(
                                    'Operamos bajo NOM-256-SSA1-2012 y NOM-251-SSA1-2009. Fichas técnicas y Hojas de Datos de Seguridad (HDS) disponibles para cada ingrediente activo aplicado en sus instalaciones para soportar sus auditorías.',
                                    style: const pw.TextStyle(fontSize: 9.2, color: darkText, lineSpacing: 1.3),
                                  ),
                                  pw.Text(
                                    'Seguridad garantizada para personal operativo, alimentos y medio ambiente.',
                                    style: pw.TextStyle(fontSize: 8.8, fontWeight: pw.FontWeight.bold, color: primaryNavy),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),
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
              _buildSlideHeader(logoImage, '¿POR QUÉ ELEGIR A EJ EXTERMINADORES?', 'Confianza, Respaldo Técnico y Atención Directa en Todo Nuevo León'),
              pw.SizedBox(height: 10),
              pw.Expanded(
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    // Columna Izquierda: 6 Ventajas Diferenciadoras (llenan la altura)
                    pw.Expanded(
                      flex: 6,
                      child: pw.Column(
                        children: [
                          pw.Expanded(
                            flex: 3,
                            child: pw.Row(
                              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                              children: [
                                _buildAdvantageCard(
                                  '9 Años de Trayectoria y Solidez',
                                  'Casi una década de experiencia en Monterrey y su área metropolitana resolviendo incidencias complejas en industria, comercio y hogares.',
                                  subtext: 'Efectividad comprobada en más de 1,200 servicios técnicos realizados.',
                                ),
                                pw.SizedBox(width: 8),
                                _buildAdvantageCard(
                                  'Supervisión de Ingeniería',
                                  'Asesoría y diseño directo por el Ing. Jorge Elizondo / Rep. Técnico, aplicando rigor científico y análisis biológico a cada caso.',
                                  subtext: 'Metodología de ingeniería que supera métodos tradicionales.',
                                ),
                              ],
                            ),
                          ),
                          pw.SizedBox(height: 8),
                          pw.Expanded(
                            flex: 3,
                            child: pw.Row(
                              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                              children: [
                                _buildAdvantageCard(
                                  'Reportes Digitales al Instante',
                                  'Generación inmediata de carpetas y reportes técnicos foliados en PDF con fotos de evidencia antes/después y firmas electrónicas en sitio.',
                                  subtext: 'Entrega automática vía WhatsApp y correo para auditorías.',
                                ),
                                pw.SizedBox(width: 8),
                                _buildAdvantageCard(
                                  'Formulaciones Autorizadas',
                                  'Uso exclusivo de ingredientes activos con registro ante COFEPRIS: formulaciones inodoras, microencapsuladas y con amplio efecto residual.',
                                  subtext: 'Seguridad garantizada para personas, mascotas e instalaciones.',
                                ),
                              ],
                            ),
                          ),
                          pw.SizedBox(height: 8),
                          pw.Expanded(
                            flex: 3,
                            child: pw.Row(
                              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                              children: [
                                _buildAdvantageCard(
                                  'Pólizas Flexibles & Crédito',
                                  'Contratos formales digitales con planes mensuales, bimestrales o anuales, facturación fiscal CFDI y facilidades de crédito comercial a 15 y 30 días.',
                                  subtext: 'Atención corporativa personalizada adaptada a su operación.',
                                ),
                                pw.SizedBox(width: 8),
                                _buildAdvantageCard(
                                  'Garantía Total por Escrito',
                                  'Compromiso formal de respaldo: ante cualquier actividad imprevista de plagas entre servicios programados, reforzamos sin costo adicional.',
                                  subtext: 'Blindaje continuo que protege su reputación y bienestar.',
                                ),
                              ],
                            ),
                          ),
                          pw.SizedBox(height: 8),
                          pw.Container(
                            width: double.infinity,
                            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: pw.BoxDecoration(
                              color: softBadgeBg,
                              borderRadius: pw.BorderRadius.circular(6),
                              border: pw.Border.all(color: const PdfColor.fromInt(0xFFBFDBFE), width: 1.0),
                            ),
                            child: pw.Row(
                              children: [
                                pw.Text('COBERTURA METROPOLITANA: ', style: pw.TextStyle(fontSize: 8.8, fontWeight: pw.FontWeight.bold, color: primaryNavy)),
                                pw.Expanded(
                                  child: pw.Text(
                                    'Monterrey, San Pedro, Santa Catarina, Guadalupe, San Nicolás, Apodaca, Escobedo y García.',
                                    style: const pw.TextStyle(fontSize: 8.5, color: darkText),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 14),

                    // Columna Derecha: Tarjeta de Contacto Directo (llena toda la altura)
                    pw.Expanded(
                      flex: 4,
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(14),
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
                                  'SOLICITE SU INSPECCIÓN Y COTIZACIÓN',
                                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFFFCD34D)),
                                ),
                                pw.SizedBox(height: 3),
                                pw.Text(
                                  'Atención Inmediata para Empresas, Colegios, Naves y Residencias:',
                                  style: const pw.TextStyle(fontSize: 9.0, color: PdfColors.white),
                                ),
                                pw.SizedBox(height: 8),
                                _buildContactLine('Teléfono / WhatsApp Directo:', '813-175-9342', subline: 'Atención inmediata los 365 días del año', highlight: true),
                                _buildContactLine('Responsable Técnico:', 'Ing. Jorge Elizondo / Rep. Técnico', subline: 'Especialista en Bioseguridad Ambiental y MIP'),
                                _buildContactLine('Correo Electrónico Oficial:', 'ventas@ejexterminadores.com'),
                                _buildContactLine('Sitio Web Oficial:', 'www.ejexterminadores.com'),
                                _buildContactLine('Horario Operativo:', 'Lunes a Sábado de 8:00 a 19:00 hrs (Guardias 24/7)'),
                                pw.SizedBox(height: 6),
                                pw.Container(
                                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  decoration: pw.BoxDecoration(
                                    color: const PdfColor.fromInt(0xFF1E3A5F),
                                    borderRadius: pw.BorderRadius.circular(6),
                                    border: pw.Border.all(color: const PdfColor.fromInt(0xFF3B82F6), width: 0.8),
                                  ),
                                  child: pw.Text(
                                    'Respuesta prioritaria en menos de 2 horas para incidencias urgentes en Monterrey y zona conurbada.',
                                    style: const pw.TextStyle(fontSize: 8.2, color: PdfColors.white, fontStyle: pw.FontStyle.italic),
                                  ),
                                ),
                              ],
                            ),
                            pw.Container(
                              width: double.infinity,
                              padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                              decoration: pw.BoxDecoration(
                                color: secondaryBlue,
                                borderRadius: pw.BorderRadius.circular(6),
                              ),
                              child: pw.Column(
                                children: [
                                  pw.Text(
                                    'AGENDAR VISITA DE DIAGNÓSTICO SIN COSTO',
                                    textAlign: pw.TextAlign.center,
                                    style: pw.TextStyle(fontSize: 9.8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                                  ),
                                  pw.SizedBox(height: 2),
                                  pw.Text(
                                    'Cotización formal entregada el mismo día del levantamiento',
                                    textAlign: pw.TextAlign.center,
                                    style: const pw.TextStyle(fontSize: 8.0, color: PdfColors.grey300),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),
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
      padding: const pw.EdgeInsets.only(bottom: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: secondaryBlue, width: 2.0)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                title,
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: primaryNavy),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                subtitle,
                style: pw.TextStyle(fontSize: 9.0, color: secondaryBlue, fontStyle: pw.FontStyle.italic),
              ),
            ],
          ),
          if (logoImage != null)
            pw.Container(height: 32, width: 40, child: pw.Image(logoImage, fit: pw.BoxFit.contain)),
        ],
      ),
    );
  }

  static pw.Widget _buildSlideFooter(int currentPage, int totalPages) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 5),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: cardBorder, width: 0.8)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'EJ Exterminadores | Manejo Integrado de Plagas | Monterrey, N.L. | Tel: 813-175-9342',
            style: const pw.TextStyle(fontSize: 8.0, color: PdfColors.grey700),
          ),
          pw.Text(
            'Página $currentPage de $totalPages',
            style: pw.TextStyle(fontSize: 8.0, fontWeight: pw.FontWeight.bold, color: primaryNavy),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildKpiCard(String metric, String title, String description) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: lightBg,
          borderRadius: pw.BorderRadius.circular(8),
          border: pw.Border.all(color: cardBorder, width: 1.0),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text(metric, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: primaryNavy)),
            pw.SizedBox(height: 2),
            pw.Text(title, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: secondaryBlue)),
            pw.SizedBox(height: 3),
            pw.Text(description, style: const pw.TextStyle(fontSize: 8.8, color: darkText, lineSpacing: 1.2)),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildSectionCard({required String title, required PdfColor iconColor, required pw.Widget child}) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: lightBg,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: cardBorder, width: 1.0),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 11.5, fontWeight: pw.FontWeight.bold, color: iconColor),
          ),
          pw.SizedBox(height: 6),
          pw.Expanded(child: child),
        ],
      ),
    );
  }

  static pw.Widget _buildValueRow(String title, String desc) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.0),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
              text: '$title: ',
              style: pw.TextStyle(fontSize: 9.2, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF78350F)),
            ),
            pw.TextSpan(
              text: desc,
              style: const pw.TextStyle(fontSize: 8.8, color: darkText),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildSectorCard({required String tag, required String sectorTitle, required String subtitle, required List<String> features}) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: lightBg,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: cardBorder, width: 1.0),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
        children: [
          pw.Row(
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                decoration: pw.BoxDecoration(
                  color: primaryNavy,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(tag, style: pw.TextStyle(fontSize: 8.0, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: pw.Text(
                  sectorTitle,
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: primaryNavy),
                ),
              ),
            ],
          ),
          pw.Text(subtitle, style: pw.TextStyle(fontSize: 8.5, color: secondaryBlue, fontStyle: pw.FontStyle.italic)),
          pw.SizedBox(height: 3),
          ...features.map((feat) {
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 2.5),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('- ', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: secondaryBlue)),
                  pw.Expanded(
                    child: pw.Text(feat, style: const pw.TextStyle(fontSize: 9.0, color: darkText, lineSpacing: 1.25)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  static pw.Widget _buildStepItem({required String stepNumber, required String stepTitle, required String description, required String subtext}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: pw.BoxDecoration(
        color: lightBg,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: cardBorder, width: 1.0),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Container(
            width: 28,
            height: 28,
            alignment: pw.Alignment.center,
            decoration: const pw.BoxDecoration(color: primaryNavy, shape: pw.BoxShape.circle),
            child: pw.Text(stepNumber, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
          ),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(stepTitle, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: primaryNavy)),
                pw.SizedBox(height: 2),
                pw.Text(description, style: const pw.TextStyle(fontSize: 9.2, color: darkText, lineSpacing: 1.25)),
                pw.SizedBox(height: 1.5),
                pw.Text(subtext, style: pw.TextStyle(fontSize: 8.5, color: secondaryBlue, fontStyle: pw.FontStyle.italic)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildAdvantageCard(String title, String desc, {String? subtext}) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: pw.BoxDecoration(
          color: lightBg,
          borderRadius: pw.BorderRadius.circular(8),
          border: pw.Border.all(color: cardBorder, width: 1.0),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
          children: [
            pw.Text(title, style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: primaryNavy)),
            pw.Text(desc, style: const pw.TextStyle(fontSize: 8.8, color: darkText, lineSpacing: 1.25)),
            if (subtext != null)
              pw.Text(subtext, style: pw.TextStyle(fontSize: 8.2, color: secondaryBlue, fontStyle: pw.FontStyle.italic)),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildContactLine(String label, String value, {String? subline, bool highlight = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 8.2, color: PdfColors.grey300)),
          pw.SizedBox(height: 1),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: highlight ? 13 : 10.5,
              fontWeight: pw.FontWeight.bold,
              color: highlight ? const PdfColor.fromInt(0xFFFCD34D) : PdfColors.white,
            ),
          ),
          if (subline != null) ...[
            pw.SizedBox(height: 1),
            pw.Text(subline, style: const pw.TextStyle(fontSize: 8.0, color: PdfColors.grey300)),
          ],
        ],
      ),
    );
  }
}

