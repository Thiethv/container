class PendingRequest {
  const PendingRequest({
    required this.containerNo,
    required this.status,
    required this.errorFields,
    this.requestedBy = '',
    this.requestedAt,
    this.resolvedBy,
    this.resolvedAt,
    this.resolvedAction,
    this.resolvedReason,
    this.updatedAt,
    this.createdAt,
  });

  factory PendingRequest.fromMap(Map<String, dynamic> map) {
    return PendingRequest(
      containerNo: (map['container_no'] ?? '').toString(),
      requestedBy: (map['requested_by'] ?? '').toString(),
      requestedAt: _parseDate(map['requested_at']),
      status: (map['status'] ?? 'PENDING').toString(),
      errorFields: _parseErrorFields(map['error_fields']),
      resolvedBy: _stringOrNull(map['resolved_by']),
      resolvedAt: _parseDate(map['resolved_at']),
      resolvedAction: _stringOrNull(map['resolved_action']),
      resolvedReason: _stringOrNull(map['resolved_reason']),
      updatedAt: _parseDate(map['updated_at']),
      createdAt: _parseDate(map['created_at']),
    );
  }

  final String containerNo;
  final String requestedBy;
  final DateTime? requestedAt;
  final String status;
  final Map<String, List<String>> errorFields;
  final String? resolvedBy;
  final DateTime? resolvedAt;
  final String? resolvedAction;
  final String? resolvedReason;
  final DateTime? updatedAt;
  final DateTime? createdAt;

  int get issueCount =>
      errorFields.values.fold<int>(0, (sum, values) => sum + values.length);

  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) {
      return null;
    }
    if (raw is DateTime) {
      return raw.toLocal();
    }
    return DateTime.tryParse(raw.toString())?.toLocal();
  }

  static String? _stringOrNull(dynamic raw) {
    final value = raw?.toString().trim() ?? '';
    return value.isEmpty ? null : value;
  }

  static Map<String, List<String>> _parseErrorFields(dynamic raw) {
    if (raw is! Map) {
      return const <String, List<String>>{};
    }

    final parsed = <String, List<String>>{};
    for (final entry in raw.entries) {
      final key = entry.key.toString();
      final values = _normalizeValues(entry.value);
      if (values.isNotEmpty) {
        parsed[key] = values;
      }
    }
    return parsed;
  }

  static List<String> _normalizeValues(dynamic raw) {
    if (raw is List) {
      return raw
          .map((value) => value.toString().trim())
          .where((value) => value.isNotEmpty)
          .toList();
    }

    if (raw is String) {
      return raw
          .split(',')
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList();
    }

    return const <String>[];
  }
}
