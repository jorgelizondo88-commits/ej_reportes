import 'dart:convert';

class CloudSyncItemModel {
  final String id;
  final String clientName;
  final String documentType; // 'Reporte', 'Cotización', 'Contrato', 'Plano', 'BaseDatos'
  final String folio;
  final String fileName;
  final String localFilePath;
  String status; // 'pending', 'uploading', 'synced', 'error'
  final DateTime createdAt;
  DateTime? syncedAt;
  String? errorMessage;
  String? driveFileId;
  String? driveWebViewLink;

  CloudSyncItemModel({
    required this.id,
    required this.clientName,
    required this.documentType,
    required this.folio,
    required this.fileName,
    required this.localFilePath,
    this.status = 'pending',
    required this.createdAt,
    this.syncedAt,
    this.errorMessage,
    this.driveFileId,
    this.driveWebViewLink,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'clientName': clientName,
      'documentType': documentType,
      'folio': folio,
      'fileName': fileName,
      'localFilePath': localFilePath,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'syncedAt': syncedAt?.toIso8601String(),
      'errorMessage': errorMessage,
      'driveFileId': driveFileId,
      'driveWebViewLink': driveWebViewLink,
    };
  }

  factory CloudSyncItemModel.fromMap(Map<String, dynamic> map) {
    return CloudSyncItemModel(
      id: map['id'] ?? '',
      clientName: map['clientName'] ?? '',
      documentType: map['documentType'] ?? 'Reporte',
      folio: map['folio'] ?? '',
      fileName: map['fileName'] ?? '',
      localFilePath: map['localFilePath'] ?? '',
      status: map['status'] ?? 'pending',
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      syncedAt: map['syncedAt'] != null ? DateTime.tryParse(map['syncedAt']) : null,
      errorMessage: map['errorMessage'],
      driveFileId: map['driveFileId'],
      driveWebViewLink: map['driveWebViewLink'],
    );
  }

  String toJson() => jsonEncode(toMap());

  factory CloudSyncItemModel.fromJson(String source) =>
      CloudSyncItemModel.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
