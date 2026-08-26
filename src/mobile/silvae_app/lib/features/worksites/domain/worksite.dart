final class Worksite {
  const Worksite({
    required this.id,
    required this.code,
    required this.name,
    required this.version,
    required this.updatedAt,
    this.address,
    this.jobOrderId,
    this.jobOrderCode,
    this.jobOrderName,
  });

  factory Worksite.fromRow(Map<String, Object?> row) => Worksite(
    id: row['id']! as String,
    code: row['code']! as String,
    name: row['name']! as String,
    address: row['address'] as String?,
    jobOrderId: row['job_order_id'] as String?,
    jobOrderCode: row['job_order_code'] as String?,
    jobOrderName: row['job_order_name'] as String?,
    version: row['version']! as int,
    updatedAt: DateTime.parse(row['updated_at']! as String),
  );

  final String id;
  final String code;
  final String name;
  final String? address;
  final String? jobOrderId;
  final String? jobOrderCode;
  final String? jobOrderName;
  final int version;
  final DateTime updatedAt;

  /// Etichetta compatta per liste e menu: la commessa precede il cantiere
  /// quando è nota, perché è il modo in cui l'ufficio nomina il lavoro.
  String get label {
    final prefix = jobOrderCode;
    return prefix == null ? '$code · $name' : '$prefix · $code · $name';
  }
}
