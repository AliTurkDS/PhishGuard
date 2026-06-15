// lib/models/scan_record.dart

class ScanRecord {
  final int? id;
  final String url;
  final String label;
  final double confidence;
  final bool isSafe;
  final DateTime scannedAt;

  const ScanRecord({
    this.id,
    required this.url,
    required this.label,
    required this.confidence,
    required this.isSafe,
    required this.scannedAt,
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'url': url,
    'label': label,
    'confidence': confidence,
    'is_safe': isSafe ? 1 : 0,
    'scanned_at': scannedAt.toIso8601String(),
  };

  static ScanRecord fromMap(Map<String, dynamic> m) => ScanRecord(
    id: m['id'] as int?,
    url: m['url'] as String,
    label: m['label'] as String,
    confidence: (m['confidence'] as num).toDouble(),
    isSafe: (m['is_safe'] as int) == 1,
    scannedAt: DateTime.parse(m['scanned_at'] as String),
  );
}
