import 'dart:convert';

enum ReportSyncStatus { device, syncing, synced, conflict, error }

/// Le voci della checklist di sicurezza proposte dall'app.
///
/// Restano qui e non nell'anagrafica finché non esiste una checklist per
/// organizzazione: l'elenco è quello del foglio cartaceo, uguale per tutti.
const List<({String code, String label})> safetyChecklist = [
  (code: 'DPI', label: 'Dispositivi di protezione indossati'),
  (code: 'MEZZI', label: 'Controllo mezzi e attrezzature'),
  (code: 'AREA', label: 'Area di lavoro delimitata'),
  (code: 'PRIMO-SOCCORSO', label: 'Kit di primo soccorso presente'),
  (code: 'FORMAZIONE', label: 'Squadra formata sulla lavorazione'),
];

final class DailyReport {
  const DailyReport({
    required this.id,
    required this.organizationId,
    required this.worksiteId,
    required this.reportDate,
    required this.status,
    required this.version,
    required this.syncStatus,
    required this.updatedAt,
    required this.content,
    this.authorId,
    this.notes,
    this.signature,
    this.remoteSnapshot,
  });

  factory DailyReport.fromRow(Map<String, Object?> row) => DailyReport(
    id: row['id']! as String,
    organizationId: row['organization_id']! as String,
    worksiteId: row['worksite_id']! as String,
    authorId: row['author_id'] as String?,
    reportDate: DateTime.parse(row['report_date']! as String),
    notes: row['notes'] as String?,
    signature: row['signature'] as String?,
    content: ReportContent.decode(row['content'] as String?),
    status: row['status']! as String,
    version: row['version']! as int,
    syncStatus: switch (row['sync_status']) {
      'synced' => ReportSyncStatus.synced,
      'processing' => ReportSyncStatus.syncing,
      'conflict' => ReportSyncStatus.conflict,
      'error' => ReportSyncStatus.error,
      _ => ReportSyncStatus.device,
    },
    remoteSnapshot: row['remote_snapshot'] == null
        ? null
        : DailyReport.fromRow(
            (jsonDecode(row['remote_snapshot']! as String)
                    as Map<String, dynamic>)
                .cast<String, Object?>(),
          ),
    updatedAt: DateTime.parse(row['updated_at']! as String),
  );

  final String id;
  final String organizationId;
  final String worksiteId;
  final String? authorId;
  final DateTime reportDate;
  final String? notes;
  final String? signature;
  final ReportContent content;
  final String status;
  final int version;
  final ReportSyncStatus syncStatus;
  final DateTime updatedAt;

  /// La copia del server messa da parte quando il pull ha trovato modifiche
  /// locali ancora in coda: è il secondo termine del conflitto.
  final DailyReport? remoteSnapshot;

  bool get isEditable =>
      (status == 'Draft' || status == 'Reopened') &&
      syncStatus != ReportSyncStatus.conflict;

  bool get isSubmittable => isEditable && content.crew.isNotEmpty;
}

/// Quel che il dispositivo possiede del report e invia per intero.
final class ReportContent {
  const ReportContent({
    this.crew = const [],
    this.activities = const [],
    this.safetyChecks = const [],
    this.photos = const [],
  });

  factory ReportContent.decode(String? value) {
    if (value == null || value.isEmpty) {
      return const ReportContent();
    }
    final json = jsonDecode(value) as Map<String, dynamic>;
    return ReportContent.fromJson(json);
  }

  factory ReportContent.fromJson(Map<String, dynamic> json) => ReportContent(
    crew: _mapList(json['crew'], CrewLine.fromJson),
    activities: _mapList(json['activities'], ActivityLine.fromJson),
    safetyChecks: _mapList(json['safetyChecks'], SafetyLine.fromJson),
    photos: _mapList(json['photos'], PhotoLine.fromJson),
  );

  final List<CrewLine> crew;
  final List<ActivityLine> activities;
  final List<SafetyLine> safetyChecks;
  final List<PhotoLine> photos;

  double get totalHours =>
      crew.fold(0, (total, member) => total + member.hours);

  Map<String, dynamic> toJson() => {
    'crew': crew.map((item) => item.toJson()).toList(growable: false),
    'activities': activities
        .map((item) => item.toJson())
        .toList(growable: false),
    'safetyChecks': safetyChecks
        .map((item) => item.toJson())
        .toList(growable: false),
    'photos': photos.map((item) => item.toJson()).toList(growable: false),
  };

  String encode() => jsonEncode(toJson());

  ReportContent copyWith({
    List<CrewLine>? crew,
    List<ActivityLine>? activities,
    List<SafetyLine>? safetyChecks,
    List<PhotoLine>? photos,
  }) => ReportContent(
    crew: crew ?? this.crew,
    activities: activities ?? this.activities,
    safetyChecks: safetyChecks ?? this.safetyChecks,
    photos: photos ?? this.photos,
  );

  static List<T> _mapList<T>(
    Object? value,
    T Function(Map<String, dynamic>) read,
  ) => (value as List<dynamic>? ?? const [])
      .map((item) => read(item as Map<String, dynamic>))
      .toList(growable: false);
}

final class CrewLine {
  const CrewLine({required this.userId, required this.hours, this.note});

  factory CrewLine.fromJson(Map<String, dynamic> json) => CrewLine(
    userId: json['userId'] as String,
    hours: (json['hours'] as num).toDouble(),
    note: json['note'] as String?,
  );

  final String userId;
  final double hours;
  final String? note;

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'hours': hours,
    'note': note,
  };
}

final class ActivityLine {
  const ActivityLine({required this.description, this.quantity, this.unit});

  factory ActivityLine.fromJson(Map<String, dynamic> json) => ActivityLine(
    description: json['description'] as String,
    quantity: (json['quantity'] as num?)?.toDouble(),
    unit: json['unit'] as String?,
  );

  final String description;
  final double? quantity;
  final String? unit;

  Map<String, dynamic> toJson() => {
    'description': description,
    'quantity': quantity,
    'unit': unit,
  };
}

final class SafetyLine {
  const SafetyLine({required this.code, required this.isCompliant, this.note});

  factory SafetyLine.fromJson(Map<String, dynamic> json) => SafetyLine(
    code: json['code'] as String,
    isCompliant: json['isCompliant'] as bool,
    note: json['note'] as String?,
  );

  final String code;
  final bool isCompliant;
  final String? note;

  Map<String, dynamic> toJson() => {
    'code': code,
    'isCompliant': isCompliant,
    'note': note,
  };
}

final class PhotoLine {
  const PhotoLine({
    required this.localReference,
    required this.capturedAt,
    this.latitude,
    this.longitude,
    this.caption,
  });

  factory PhotoLine.fromJson(Map<String, dynamic> json) => PhotoLine(
    localReference: json['localReference'] as String,
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
    capturedAt: DateTime.parse(json['capturedAt'] as String),
    caption: json['caption'] as String?,
  );

  final String localReference;
  final double? latitude;
  final double? longitude;
  final DateTime capturedAt;
  final String? caption;

  bool get hasPosition => latitude != null && longitude != null;

  Map<String, dynamic> toJson() => {
    'localReference': localReference,
    'latitude': latitude,
    'longitude': longitude,
    'capturedAt': capturedAt.toUtc().toIso8601String(),
    'caption': caption,
  };
}
