import 'dart:typed_data';
import 'trap_monitoring_model.dart';

class ChemicalProduct {
  final String id;
  final String name;
  final String activeIngredient;
  final String dosage;
  final String registrationNumber;
  final String applicationMethod;
  final String targetArea;

  ChemicalProduct({
    required this.id,
    required this.name,
    required this.activeIngredient,
    required this.dosage,
    required this.registrationNumber,
    required this.applicationMethod,
    required this.targetArea,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'activeIngredient': activeIngredient,
      'dosage': dosage,
      'registrationNumber': registrationNumber,
      'applicationMethod': applicationMethod,
      'targetArea': targetArea,
    };
  }

  factory ChemicalProduct.fromMap(Map<String, dynamic> map) {
    return ChemicalProduct(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      activeIngredient: map['activeIngredient'] ?? '',
      dosage: map['dosage'] ?? '',
      registrationNumber: map['registrationNumber'] ?? '',
      applicationMethod: map['applicationMethod'] ?? '',
      targetArea: map['targetArea'] ?? '',
    );
  }
}

class PhotoEvidence {
  final String path;
  final String description;

  PhotoEvidence({
    required this.path,
    this.description = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'path': path,
      'description': description,
    };
  }

  factory PhotoEvidence.fromMap(Map<String, dynamic> map) {
    return PhotoEvidence(
      path: map['path'] ?? '',
      description: map['description'] ?? '',
    );
  }
}

class ServiceReport {
  final String reportFolio;
  final DateTime serviceDate;
  final String serviceTimeStart;
  final String serviceTimeEnd;
  final String technicianName;

  final String clientName;
  final String businessName;
  final String clientAddress;
  final String clientPhone;
  final String clientEmail;
  final String facilityType;
  final bool hasTraps;

  final List<String> targetedPests;
  final String inspectionFindings;

  final List<ChemicalProduct> chemicals;
  final List<TrapMonitoring> traps;

  final List<PhotoEvidence> photoEvidences;
  final String recommendations;
  final String warranties;

  final Uint8List? technicianSignature;
  final Uint8List? clientSignature;
  final String receivedByName;

  ServiceReport({
    required this.reportFolio,
    required this.serviceDate,
    required this.serviceTimeStart,
    required this.serviceTimeEnd,
    required this.technicianName,
    required this.clientName,
    required this.businessName,
    required this.clientAddress,
    required this.clientPhone,
    required this.clientEmail,
    required this.facilityType,
    required this.hasTraps,
    required this.targetedPests,
    required this.inspectionFindings,
    required this.chemicals,
    required this.traps,
    required this.photoEvidences,
    required this.recommendations,
    this.warranties = '',
    this.technicianSignature,
    this.clientSignature,
    required this.receivedByName,
  });
}