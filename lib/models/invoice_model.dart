class InvoiceModel {
  final String id; // Google Drive PDF File ID
  final String pdfName; // e.g. "Factura_F102.pdf"
  final String folio; // e.g. "F102"
  final String clientName; // Nombre de la carpeta del cliente
  final String clientPhone; // Para WhatsApp
  final String clientEmail;
  final DateTime createdTime;
  final DateTime? modifiedTime;
  final String? pdfWebViewLink;
  final String? xmlFileId;
  final String? xmlFileName;
  final String status; // 'pending' (Pendientes_de_Pago), 'paid' (Pagadas), 'canceled' (Canceladas)
  final String parentFolderId;
  final int fileSize;

  InvoiceModel({
    required this.id,
    required this.pdfName,
    required this.folio,
    required this.clientName,
    this.clientPhone = '',
    this.clientEmail = '',
    required this.createdTime,
    this.modifiedTime,
    this.pdfWebViewLink,
    this.xmlFileId,
    this.xmlFileName,
    required this.status,
    required this.parentFolderId,
    this.fileSize = 0,
  });

  bool get hasXml => xmlFileId != null && xmlFileId!.isNotEmpty;

  String get formattedFileSize {
    if (fileSize <= 0) return '';
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  InvoiceModel copyWith({
    String? id,
    String? pdfName,
    String? folio,
    String? clientName,
    String? clientPhone,
    String? clientEmail,
    DateTime? createdTime,
    DateTime? modifiedTime,
    String? pdfWebViewLink,
    String? xmlFileId,
    String? xmlFileName,
    String? status,
    String? parentFolderId,
    int? fileSize,
  }) {
    return InvoiceModel(
      id: id ?? this.id,
      pdfName: pdfName ?? this.pdfName,
      folio: folio ?? this.folio,
      clientName: clientName ?? this.clientName,
      clientPhone: clientPhone ?? this.clientPhone,
      clientEmail: clientEmail ?? this.clientEmail,
      createdTime: createdTime ?? this.createdTime,
      modifiedTime: modifiedTime ?? this.modifiedTime,
      pdfWebViewLink: pdfWebViewLink ?? this.pdfWebViewLink,
      xmlFileId: xmlFileId ?? this.xmlFileId,
      xmlFileName: xmlFileName ?? this.xmlFileName,
      status: status ?? this.status,
      parentFolderId: parentFolderId ?? this.parentFolderId,
      fileSize: fileSize ?? this.fileSize,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'pdfName': pdfName,
      'folio': folio,
      'clientName': clientName,
      'clientPhone': clientPhone,
      'clientEmail': clientEmail,
      'createdTime': createdTime.toIso8601String(),
      'modifiedTime': modifiedTime?.toIso8601String(),
      'pdfWebViewLink': pdfWebViewLink,
      'xmlFileId': xmlFileId,
      'xmlFileName': xmlFileName,
      'status': status,
      'parentFolderId': parentFolderId,
      'fileSize': fileSize,
    };
  }

  factory InvoiceModel.fromMap(Map<String, dynamic> map) {
    return InvoiceModel(
      id: map['id'] ?? '',
      pdfName: map['pdfName'] ?? '',
      folio: map['folio'] ?? '',
      clientName: map['clientName'] ?? '',
      clientPhone: map['clientPhone'] ?? '',
      clientEmail: map['clientEmail'] ?? '',
      createdTime: DateTime.tryParse(map['createdTime'] ?? '') ?? DateTime.now(),
      modifiedTime: map['modifiedTime'] != null ? DateTime.tryParse(map['modifiedTime']) : null,
      pdfWebViewLink: map['pdfWebViewLink'],
      xmlFileId: map['xmlFileId'],
      xmlFileName: map['xmlFileName'],
      status: map['status'] ?? 'pending',
      parentFolderId: map['parentFolderId'] ?? '',
      fileSize: map['fileSize'] is int ? map['fileSize'] : 0,
    );
  }
}
