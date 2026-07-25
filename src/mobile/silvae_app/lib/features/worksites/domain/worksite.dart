final class Worksite {
  const Worksite({
    required this.id,
    required this.code,
    required this.name,
    required this.version,
    required this.updatedAt,
    this.address,
  });

  factory Worksite.fromRow(Map<String, Object?> row) => Worksite(
    id: row['id']! as String,
    code: row['code']! as String,
    name: row['name']! as String,
    address: row['address'] as String?,
    version: row['version']! as int,
    updatedAt: DateTime.parse(row['updated_at']! as String),
  );

  final String id;
  final String code;
  final String name;
  final String? address;
  final int version;
  final DateTime updatedAt;
}
