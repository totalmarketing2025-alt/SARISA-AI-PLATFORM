class SearchCase {
  final int? id;
  final String caseNumber;
  final String personName;
  final String description;
  final String clothing;
  final String lastSeenLocation;
  final String lastSeenAt;
  final String status;
  final String createdAt;

  const SearchCase({
    this.id,
    required this.caseNumber,
    required this.personName,
    this.description = '',
    this.clothing = '',
    this.lastSeenLocation = '',
    this.lastSeenAt = '',
    this.status = 'ACTIVE',
    required this.createdAt,
  });

  Map<String, Object?> toMap() => {
    'id': id,
    'case_number': caseNumber,
    'person_name': personName,
    'description': description,
    'clothing': clothing,
    'last_seen_location': lastSeenLocation,
    'last_seen_at': lastSeenAt,
    'status': status,
    'created_at': createdAt,
  };

  factory SearchCase.fromMap(Map<String, Object?> map) => SearchCase(
    id: map['id'] as int?,
    caseNumber: map['case_number'] as String,
    personName: map['person_name'] as String,
    description: map['description'] as String? ?? '',
    clothing: map['clothing'] as String? ?? '',
    lastSeenLocation: map['last_seen_location'] as String? ?? '',
    lastSeenAt: map['last_seen_at'] as String? ?? '',
    status: map['status'] as String? ?? 'ACTIVE',
    createdAt: map['created_at'] as String,
  );
}

class CasePhoto {
  final int? id;
  final int caseId;
  final String filePath;
  final String fileName;
  final String addedAt;
  final String note;

  const CasePhoto({
    this.id,
    required this.caseId,
    required this.filePath,
    required this.fileName,
    required this.addedAt,
    this.note = '',
  });

  Map<String, Object?> toMap() => {
    'id': id,
    'case_id': caseId,
    'file_path': filePath,
    'file_name': fileName,
    'added_at': addedAt,
    'note': note,
  };

  factory CasePhoto.fromMap(Map<String, Object?> map) => CasePhoto(
    id: map['id'] as int?,
    caseId: map['case_id'] as int,
    filePath: map['file_path'] as String,
    fileName: map['file_name'] as String,
    addedAt: map['added_at'] as String,
    note: map['note'] as String? ?? '',
  );
}
