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
  static const PdfColor cardBorder = PdfColor.fromInt(0xFFE2E8F0);
  static const PdfColor softBadgeBg = PdfColor.fromInt(0xFFEFF6FF);

  static Future<Uint8List> generatePresentationPdf() async {
    final pdf = pw.Document();

    // Carga de imágenes institucionales
    pw.ImageProvider? logoImage;
    pw.ImageProvider? technicianImage;
    pw.ImageProvider? inspectionImage;

    try {
      final logoBytes = await rootBundle.load('assets/images/logo.png');
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (_) {}

    try {
      final techBytes = await rootBundle.load('assets/images/presentation_technician_work.jpg');
      technicianImage = pw.MemoryImage(techBytes.buffer.asUint8List());
    } catch (_) {}

    try {
      final inspectBytes = await rootBundle.load('assets/images/presentation_inspection.jpg');
      inspectionImage = pw.MemoryImage(inspectBytes.buffer.asUint8List());
    } catch (_) {}

    final pageTheme = pw.PageTheme(
      pageFormat: PdfPageFormat.letter.landscape,
      margin: const pw.EdgeInsets.symmetric(horizontal: 26, vertical: 20),
      theme: pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
        italic: pw.Font.helveticaOblique(),
      ),
    );

    // ==========================================
    // DIAPOSITIVA 1: PORTADA EJECUTIVA
    // ==========================================
    pdf.addPage(
      pw.Page(
        pageTheme: pageTheme,
        build: (context) {
          return pw.Column(
            children: [
              pw.Expanded(
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    // Columna Izquierda: Información Principal
                    pw.Expanded(
                      flex: 6,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        children: [
                          if (logoImage != null)
                            pw.Container(
                              height: 62,
                              child: pw.Image(logoImage),
                            ),
                          pw.SizedBox(height: 12),
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                            decoration: pw.BoxDecoration(
                              color: const PdfColor.fromInt(0xFFFEF3C7),
                              borderRadius: pw.BorderRadius.circular(4),
                              border: pw.Border.all(color: const PdfColor.fromInt(0xFFFCD34D), width: 0.8),
                            ),
                            child: pw.Text(
                              '9 ANOS DE TRAYECTORIA Y LIDERAZGO TECNICO EN NUEVO LEON',
                              style: pw.TextStyle(
                                fontSize: 8.5,
                                fontWeight: pw.FontWeight.bold,
                                color: const PdfColor.fromInt(0xFF92400E),
                              ),
                            ),
                          ),
                          pw.SizedBox(height: 10),
                          pw.Text(
                            'DOSSIER CORPORATIVO DE SERVICIOS',
                            style: pw.TextStyle(
                              fontSize: 22,
                              fontWeight: pw.FontWeight.bold,
                              color: primaryNavy,
                              letterSpacing: 0.5,
                            ),
                          ),
                          pw.SizedBox(height: 3),
                          pw.Text(
                            'Manejo Integrado de Plagas Urbanas e Industriales (MIP)',
                            style: pw.TextStyle(
                              fontSize: 13,
                              fontWeight: pw.FontWeight.bold,
                              color: secondaryBlue,
                            ),
                          ),
                          pw.SizedBox(height: 10),
                          pw.Text(
                            'Soluciones profesionales de bioseguridad ambiental, control preventivo y cumplimiento normativo para la industria, sector comercial, educativo y residencial de Monterrey y su área metropolitana.',
                            style: const pw.TextStyle(
                              fontSize: 9.5,
                              color: darkText,
                              lineSpacing: 1.25,
                            ),
                          ),
                          pw.SizedBox(height: 14),
                          pw.Row(
                            children: [
                              _buildPill('NOM-256-SSA1-2012', 'Control Urbano'),
                              pw.SizedBox(width: 8),
                              _buildPill('NOM-251-SSA1-2009', 'Inocuidad y Alimentos'),
                              pw.SizedBox(width: 8),
                              _buildPill('COFEPRIS', 'Químicos Autorizados'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 22),

                    // Columna Derecha: Fotografía Corporativa
                    pw.Expanded(
                      flex: 4,
                      child: pw.Container(
                        height: double.infinity,
                        decoration: pw.BoxDecoration(
                          borderRadius: pw.BorderRadius.circular(8),
                          border: pw.Border.all(color: secondaryBlue, width: 2),
                        ),
                        child: pw.ClipRRect(
                          horizontalRadius: 6,
                          verticalRadius: 6,
                          child: technicianImage != null
                              ? pw.Image(technicianImage, fit: pw.BoxFit.cover)
                              : pw.Container(
                                  color: lightBg,
                                  child: pw.Center(
                                    child: pw.Text('EJ Exterminadores', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: primaryNavy)),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),
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
              _buildSlideHeader(logoImage, 'QUIÉNES SOMOS, MISIÓN Y PILARES DE CONFIANZA', 'Compromiso Ético y Científico con la Bioseguridad en Nuevo León'),
              pw.SizedBox(height: 10),
              pw.Expanded(
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Columna Izquierda: Trayectoria, Misión y Visión
                    pw.Expanded(
                      flex: 5,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildSectionCard(
                            title: 'NUESTRA TRAYECTORIA (9 AÑOS)',
                            iconColor: primaryNavy,
                            child: pw.Text(
                              'EJ Exterminadores es una empresa 100% regiomontana con 9 años de experiencia especializada en bioseguridad ambiental y Manejo Integrado de Plagas (MIP). Transformamos la fumigación tradicional en una disciplina científica, combinando química microencapsulada de bajo impacto, exclusión estructural física y trazabilidad digital en tiempo real.',
                              style: const pw.TextStyle(fontSize: 8.5, color: darkText, lineSpacing: 1.2),
                            ),
                          ),
                          pw.SizedBox(height: 8),
                          _buildSectionCard(
                            title: 'NUESTRA MISIÓN',
                            iconColor: secondaryBlue,
                            child: pw.Text(
                              'Salvaguardar la salud pública, la inocuidad operativa y los activos de nuestros clientes mediante soluciones científicas de grado industrial, garantizando ambientes seguros para las personas, inocuos para los alimentos y con estricto respeto al medio ambiente.',
                              style: const pw.TextStyle(fontSize: 8.5, color: darkText, lineSpacing: 1.2),
                            ),
                          ),
                          pw.SizedBox(height: 8),
                          _buildSectionCard(
                            title: 'NUESTRA VISIÓN',
                            iconColor: primaryNavy,
                            child: pw.Text(
                              'Consolidarnos como el socio estratégico líder en el norte de México en gestión sanitaria y prevención biológica, siendo reconocidos por nuestra capacidad técnica de ingeniería, cumplimiento normativo y ética profesional inquebrantable.',
                              style: const pw.TextStyle(fontSize: 8.5, color: darkText, lineSpacing: 1.2),
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 14),

                    // Columna Derecha: Valores y Diferenciadores
                    pw.Expanded(
                      flex: 5,
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(12),
                        decoration: pw.BoxDecoration(
                          color: lightBg,
                          borderRadius: pw.BorderRadius.circular(6),
                          border: pw.Border.all(color: cardBorder, width: 0.8),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                              decoration: const pw.BoxDecoration(color: primaryNavy),
                              child: pw.Text(
                                'NUESTROS 5 VALORES FUNDAMENTALES',
                                style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                              ),
                            ),
                            pw.SizedBox(height: 8),
                            _buildValueItem('1. Rigor Científico y Técnico', 'Uso exclusivo de formulaciones certificadas por COFEPRIS; dosificación exacta sin improvisaciones.'),
                            _buildValueItem('2. Honestidad y Ética Sanitaria', 'Diagnósticos transparentes; reportamos la realidad biológica de cada inmueble sin falsas promesas.'),
                            _buildValueItem('3. Puntualidad y Disciplina Operativa', 'Cumplimiento riguroso de fechas y horarios programados en pólizas comerciales e industriales.'),
                            _buildValueItem('4. Seguridad y Bioprotección Integral', 'Prioridad absoluta en la salud de personas, colaboradores de la empresa, mascotas y alimentos.'),
                            _buildValueItem('5. Alianza y Responsabilidad Compartida', 'Acompañamiento continuo y asesoría técnica para lograr el umbral cero plagas en equipo.'),
                          ],
                        ),
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
    // DIAPOSITIVA 3: CATÁLOGO DE SOLUCIONES POR SECTOR
    // ==========================================
    pdf.addPage(
      pw.Page(
        pageTheme: pageTheme,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildSlideHeader(logoImage, 'CATÁLOGO DE SERVICIOS ESPECIALIZADOS POR SECTOR', 'Programas a la Medida Diseñados para Cumplir los Estándares de su Giro'),
              pw.SizedBox(height: 10),
              pw.Expanded(
                child: pw.Row(
                  children: [
                    // Columna 1
                    pw.Expanded(
                      child: pw.Column(
                        children: [
                          _buildSectorCard(
                            tag: '[INDUSTRIA]',
                            sectorTitle: 'Sector Industrial, Naves & Parques Logísticos',
                            features: [
                              'Pólizas periódicas mensuales y bimestrales bajo contrato formal.',
                              'Cordones de bioseguridad perimetral y estaciones cebaderas de alta seguridad.',
                              'Carpetas técnicas y bitácoras para auditorías (Distintivo H, BPM, AIB, ISO).',
                              'Control de fauna nociva en andenes, comedores y áreas de producción.',
                            ],
                          ),
                          pw.SizedBox(height: 8),
                          _buildSectorCard(
                            tag: '[ALIMENTOS]',
                            sectorTitle: 'Sector Restaurantero, Cocinas & Alimentos',
                            features: [
                              'Control de cucaracha alemana con cebos en gel de microdosis sin suspender labores.',
                              'Cero contaminación cruzada en cubiertas de preparación de alimentos.',
                              'Instalación y monitoreo de trampas de luz ultravioleta (UV) para insectos voladores.',
                              'Certificado oficial de servicio para inspecciones sanitarias municipales.',
                            ],
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 12),

                    // Columna 2
                    pw.Expanded(
                      child: pw.Column(
                        children: [
                          _buildSectorCard(
                            tag: '[EDUCATIVO]',
                            sectorTitle: 'Sector Educativo, Colegios & Guarderías',
                            features: [
                              'Aplicaciones programadas en contraturno, fines de semana o periodos vacacionales.',
                              'Formulaciones inodoras de grado hospitalario, sin solventes agresivos.',
                              'Control perimetral de alacranes, ciempiés, arañas y mosquitos vectores.',
                              'Seguridad comprobada para el alumnado infantil y personal docente.',
                            ],
                          ),
                          pw.SizedBox(height: 8),
                          _buildSectorCard(
                            tag: '[RESIDENCIAL]',
                            sectorTitle: 'Sector Residencial, Quintas & Fraccionamientos',
                            features: [
                              'Blindaje de choque y barrera residual perimetral contra fauna nociva silvestre.',
                              'Tratamientos especializados para termitas subterráneas y de madera seca.',
                              'Protocolos seguros para mascotas (pet-friendly) y familias.',
                              'Inspección y sellado de accesos en jardines, bardas y patios.',
                            ],
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
              _buildSlideHeader(logoImage, 'METODOLOGÍA "MIP" Y TECNOLOGÍA DIGITAL EN CAMPO', '4 Fases de Precisión Técnica que Garantizan Resultados Científicos Duraderos'),
              pw.SizedBox(height: 10),
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
                            stepTitle: 'Inspección & Diagnóstico Estructural',
                            description: 'Mapeo exhaustivo de focos de calor, humedad, fuentes de alimento y vías de acceso biológico antes de aplicar cualquier químico.',
                          ),
                          pw.SizedBox(height: 6),
                          _buildStepItem(
                            stepNumber: '2',
                            stepTitle: 'Intervención Táctica Focalizada',
                            description: 'Uso de formulaciones microencapsuladas y cebos parafinados aprobados por COFEPRIS. Cero químicos de supermercado ni repelencias accidentales.',
                          ),
                          pw.SizedBox(height: 6),
                          _buildStepItem(
                            stepNumber: '3',
                            stepTitle: 'Trazabilidad & Reportes Digitales',
                            description: 'Con nuestra plataforma propia, entregamos reportes inmediatos en PDF con fotografías del servicio, firmas electrónicas y observaciones de mejora.',
                          ),
                          pw.SizedBox(height: 6),
                          _buildStepItem(
                            stepNumber: '4',
                            stepTitle: 'Garantía por Póliza & Blindaje Continuo',
                            description: 'Respaldo por escrito mediante contrato. Monitoreo permanente de estaciones cebaderas y refuerzos sin costo adicional ante contingencias.',
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 14),

                    // Columna Derecha: Fotografía y Respaldo Normativo
                    pw.Expanded(
                      flex: 4,
                      child: pw.Column(
                        children: [
                          pw.Expanded(
                            child: pw.Container(
                              decoration: pw.BoxDecoration(
                                borderRadius: pw.BorderRadius.circular(6),
                                border: pw.Border.all(color: cardBorder, width: 1),
                              ),
                              child: pw.ClipRRect(
                                horizontalRadius: 6,
                                verticalRadius: 6,
                                child: inspectionImage != null
                                    ? pw.Image(inspectionImage, fit: pw.BoxFit.cover)
                                    : pw.Container(color: lightBg),
                              ),
                            ),
                          ),
                          pw.SizedBox(height: 8),
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
                                  style: pw.TextStyle(fontSize: 8.0, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF3730A3)),
                                ),
                                pw.SizedBox(height: 2),
                                pw.Text(
                                  'Operamos bajo la NOM-256-SSA1-2012 y NOM-251-SSA1-2009. Fichas técnicas de seguridad (HDS) disponibles para cada ingrediente activo aplicado en sus instalaciones.',
                                  style: const pw.TextStyle(fontSize: 7.5, color: darkText, lineSpacing: 1.15),
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
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Columna Izquierda: 6 Ventajas Diferenciadoras
                    pw.Expanded(
                      flex: 6,
                      child: pw.Column(
                        children: [
                          pw.Row(
                            children: [
                              _buildAdvantageCard('9 Años de Experiencia', 'Trayectoria sólida y comprobada en Monterrey y su zona metropolitana.'),
                              pw.SizedBox(width: 8),
                              _buildAdvantageCard('Supervisión de Ingeniería', 'Asesoría técnica directa por el Ing. Jorge Elizondo / Rep. Técnico.'),
                            ],
                          ),
                          pw.SizedBox(height: 8),
                          pw.Row(
                            children: [
                              _buildAdvantageCard('Reportes Digitales al Instante', 'Generación inmediata de reportes con fotos y firmas electrónicas.'),
                              pw.SizedBox(width: 8),
                              _buildAdvantageCard('Formulaciones Autorizadas', 'Ingredientes activos grado industrial registrados ante COFEPRIS.'),
                            ],
                          ),
                          pw.SizedBox(height: 8),
                          pw.Row(
                            children: [
                              _buildAdvantageCard('Pólizas y Contratos Transparentes', 'Contratos formales digitales con facilidades de pago (15 o 30 días).'),
                              pw.SizedBox(width: 8),
                              _buildAdvantageCard('Garantía por Escrito', 'Refuerzos técnicos sin costo ante cualquier eventualidad extraordinaria.'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 14),

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
                                  'SOLICITE SU INSPECCIÓN Y COTIZACIÓN',
                                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFFFCD34D)),
                                ),
                                pw.SizedBox(height: 4),
                                pw.Text(
                                  'Atención Inmediata a Empresas, Colegios y Comercios:',
                                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.white),
                                ),
                                pw.SizedBox(height: 10),
                                _buildContactLine('Teléfono / WhatsApp:', '813-175-9342'),
                                _buildContactLine('Responsable Técnico:', 'Ing. Jorge Elizondo'),
                                _buildContactLine('Correo Electrónico:', 'contacto@ejexterminadores.com'),
                                _buildContactLine('Sitio Web:', 'www.ejexterminadores.com'),
                                _buildContactLine('Cobertura:', 'Monterrey y Área Metropolitana, N.L.'),
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
                                'VISITA DE DIAGNÓSTICO SIN COMPROMISO',
                                textAlign: pw.TextAlign.center,
                                style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
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
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: primaryNavy),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                subtitle,
                style: pw.TextStyle(fontSize: 8.5, color: secondaryBlue, fontStyle: pw.FontStyle.italic),
              ),
            ],
          ),
          if (logoImage != null)
            pw.Container(height: 28, child: pw.Image(logoImage)),
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
            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
          ),
          pw.Text(
            'Página $currentPage de $totalPages',
            style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: primaryNavy),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPill(String title, String subtitle) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: pw.BoxDecoration(
        color: softBadgeBg,
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: const PdfColor.fromInt(0xFFBFDBFE), width: 0.6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: primaryNavy)),
          pw.Text(subtitle, style: const pw.TextStyle(fontSize: 6.5, color: secondaryBlue)),
        ],
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
            style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: iconColor),
          ),
          pw.SizedBox(height: 3),
          child,
        ],
      ),
    );
  }

  static pw.Widget _buildValueItem(String title, String desc) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: pw.TextStyle(fontSize: 8.0, fontWeight: pw.FontWeight.bold, color: primaryNavy)),
          pw.Text(desc, style: const pw.TextStyle(fontSize: 7.5, color: darkText, lineSpacing: 1.15)),
        ],
      ),
    );
  }

  static pw.Widget _buildSectorCard({required String tag, required String sectorTitle, required List<String> features}) {
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
          pw.Row(
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: const pw.BoxDecoration(color: primaryNavy),
                child: pw.Text(tag, style: pw.TextStyle(fontSize: 7.0, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
              ),
              pw.SizedBox(width: 6),
              pw.Expanded(
                child: pw.Text(
                  sectorTitle,
                  style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: primaryNavy),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          ...features.map((feat) {
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 2),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('- ', style: pw.TextStyle(fontSize: 8.0, fontWeight: pw.FontWeight.bold, color: secondaryBlue)),
                  pw.Expanded(
                    child: pw.Text(feat, style: const pw.TextStyle(fontSize: 7.5, color: darkText, lineSpacing: 1.12)),
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
      padding: const pw.EdgeInsets.all(7),
      decoration: pw.BoxDecoration(
        color: lightBg,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: cardBorder, width: 0.8),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 20,
            height: 20,
            alignment: pw.Alignment.center,
            decoration: const pw.BoxDecoration(color: primaryNavy, shape: pw.BoxShape.circle),
            child: pw.Text(stepNumber, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(stepTitle, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: primaryNavy)),
                pw.SizedBox(height: 1.5),
                pw.Text(description, style: const pw.TextStyle(fontSize: 7.5, color: darkText, lineSpacing: 1.12)),
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
        padding: const pw.EdgeInsets.all(7),
        decoration: pw.BoxDecoration(
          color: lightBg,
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: cardBorder, width: 0.8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title, style: pw.TextStyle(fontSize: 8.2, fontWeight: pw.FontWeight.bold, color: secondaryBlue)),
            pw.SizedBox(height: 2),
            pw.Text(desc, style: const pw.TextStyle(fontSize: 7.2, color: darkText, lineSpacing: 1.12)),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildContactLine(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey300)),
          pw.Text(value, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
        ],
      ),
    );
  }
}
