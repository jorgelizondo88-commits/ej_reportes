class CertificateModel {
  final String id; // Google Drive PDF File ID
  final String pdfName; // e.g. "Certificado_Fumigacion_Nov2026.pdf"
  final String title; // Nombre legible sin extensión
  final String clientName; // Nombre oficial de la carpeta / empresa del cliente
  final String clientPhone; // Para WhatsApp
  final String clientEmail;
  final DateTime createdTime; // Fecha de creación/subida en Drive (local)
  final DateTime? modifiedTime; // Fecha de modificación/movimiento en Drive (local)
  final DateTime addedTime; // Fecha efectiva de ingreso/agregado a la carpeta (local)
  final String? pdfWebViewLink;
  final String parentFolderId;
  final String subfolderName; // Ej. "2025" si estaba dentro de una subcarpeta de Certificados
  final int fileSize;

  CertificateModel({
    required this.id,
    required this.pdfName,
    String? title,
    required this.clientName,
    this.clientPhone = '',
    this.clientEmail = '',
    required this.createdTime,
    this.modifiedTime,
    DateTime? addedTime,
    this.pdfWebViewLink,
    required this.parentFolderId,
    this.subfolderName = '',
    this.fileSize = 0,
  })  : title = (title != null && title.trim().isNotEmpty) ? title.trim() : deriveDisplayTitle(pdfName),
        addedTime = (addedTime ?? computeEffectiveAddedTime(createdTime: createdTime, modifiedTime: modifiedTime)).toLocal();

  /// Determina la fecha efectiva en la que se ingresó o actualizó el certificado en Drive:
  /// - Si se subió desde navegador o Drive Desktop, `createdTime` refleja el momento exacto de subida a Drive
  ///   (aun si `modifiedTime` conservó la fecha vieja del archivo local).
  /// - Si se reemplazó o movió posteriormente en Drive, `modifiedTime` es mayor que `createdTime`.
  /// En ambos casos, tomar la más reciente refleja la fecha real de ingreso/actualización en Drive.
  static DateTime computeEffectiveAddedTime({
    DateTime? createdTime,
    DateTime? modifiedTime,
  }) {
    final c = createdTime?.toLocal();
    final m = modifiedTime?.toLocal();
    if (c != null && m != null) {
      return m.isAfter(c) ? m : c;
    }
    return c ?? m ?? DateTime.now();
  }

  static String deriveDisplayTitle(String fileName) {
    var cleaned = fileName.trim();
    cleaned = cleaned.replaceFirst(RegExp(r'\.pdf$', caseSensitive: false), '');
    cleaned = cleaned.replaceAll('_', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    return cleaned.isNotEmpty ? cleaned : fileName.trim();
  }

  static String _stripAccents(String input) {
    return input
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ñ', 'n');
  }

  static bool isCertificateFolderName(String folderName) {
    final norm = _stripAccents(folderName.trim());
    if (norm.isEmpty) return false;
    return norm.contains('certificad');
  }

  String get formattedFileSize {
    if (fileSize <= 0) return '';
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  CertificateModel copyWith({
    String? id,
    String? pdfName,
    String? title,
    String? clientName,
    String? clientPhone,
    String? clientEmail,
    DateTime? createdTime,
    DateTime? modifiedTime,
    DateTime? addedTime,
    String? pdfWebViewLink,
    String? parentFolderId,
    String? subfolderName,
    int? fileSize,
  }) {
    final nextCreated = createdTime ?? this.createdTime;
    final nextModified = modifiedTime ?? this.modifiedTime;
    return CertificateModel(
      id: id ?? this.id,
      pdfName: pdfName ?? this.pdfName,
      title: title ?? (pdfName != null ? deriveDisplayTitle(pdfName) : this.title),
      clientName: clientName ?? this.clientName,
      clientPhone: clientPhone ?? this.clientPhone,
      clientEmail: clientEmail ?? this.clientEmail,
      createdTime: nextCreated,
      modifiedTime: nextModified,
      addedTime: addedTime ?? computeEffectiveAddedTime(createdTime: nextCreated, modifiedTime: nextModified),
      pdfWebViewLink: pdfWebViewLink ?? this.pdfWebViewLink,
      parentFolderId: parentFolderId ?? this.parentFolderId,
      subfolderName: subfolderName ?? this.subfolderName,
      fileSize: fileSize ?? this.fileSize,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'pdfName': pdfName,
      'title': title,
      'clientName': clientName,
      'clientPhone': clientPhone,
      'clientEmail': clientEmail,
      'createdTime': createdTime.toIso8601String(),
      'modifiedTime': modifiedTime?.toIso8601String(),
      'addedTime': addedTime.toIso8601String(),
      'pdfWebViewLink': pdfWebViewLink,
      'parentFolderId': parentFolderId,
      'subfolderName': subfolderName,
      'fileSize': fileSize,
    };
  }

  factory CertificateModel.fromMap(Map<String, dynamic> map) {
    final created = (DateTime.tryParse(map['createdTime'] ?? '') ?? DateTime.now()).toLocal();
    final modified = map['modifiedTime'] != null ? DateTime.tryParse(map['modifiedTime'].toString())?.toLocal() : null;
    final storedAdded = map['addedTime'] != null ? DateTime.tryParse(map['addedTime'].toString())?.toLocal() : null;

    return CertificateModel(
      id: (map['id'] ?? '').toString(),
      pdfName: (map['pdfName'] ?? '').toString(),
      title: map['title']?.toString(),
      clientName: (map['clientName'] ?? '').toString(),
      clientPhone: (map['clientPhone'] ?? '').toString(),
      clientEmail: (map['clientEmail'] ?? '').toString(),
      createdTime: created,
      modifiedTime: modified,
      addedTime: storedAdded ?? computeEffectiveAddedTime(createdTime: created, modifiedTime: modified),
      pdfWebViewLink: map['pdfWebViewLink']?.toString(),
      parentFolderId: (map['parentFolderId'] ?? '').toString(),
      subfolderName: (map['subfolderName'] ?? '').toString(),
      fileSize: map['fileSize'] is int ? map['fileSize'] as int : (int.tryParse('${map['fileSize']}') ?? 0),
    );
  }
}
