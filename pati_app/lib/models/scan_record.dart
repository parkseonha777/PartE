enum RiskLevel { danger, caution, safe }

class ScanRecord {
  final String id;
  final DateTime scannedAt;
  final String ingredientsText;
  final List<String> dangerNames;
  final List<String> cautionNames;

  const ScanRecord({
    required this.id,
    required this.scannedAt,
    required this.ingredientsText,
    required this.dangerNames,
    required this.cautionNames,
  });

  // 제품명 대신 스캔한 날짜와 시각을 제목으로 사용
  String get title {
    String two(int n) => n.toString().padLeft(2, '0');
    final d = scannedAt;
    return '${d.year}.${two(d.month)}.${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  RiskLevel get level {
    if (dangerNames.isNotEmpty) return RiskLevel.danger;
    if (cautionNames.isNotEmpty) return RiskLevel.caution;
    return RiskLevel.safe;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'scannedAt': scannedAt.toIso8601String(),
        'ingredientsText': ingredientsText,
        'dangerNames': dangerNames,
        'cautionNames': cautionNames,
      };

  factory ScanRecord.fromJson(Map<String, dynamic> json) => ScanRecord(
        id: json['id'] as String,
        scannedAt: DateTime.parse(json['scannedAt'] as String),
        ingredientsText: json['ingredientsText'] as String? ?? '',
        dangerNames: List<String>.from(json['dangerNames'] as List? ?? []),
        cautionNames: List<String>.from(json['cautionNames'] as List? ?? []),
      );
}