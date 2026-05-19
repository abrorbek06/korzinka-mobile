class AuditLog {
  final String id;
  final String action;
  final String? fromStatus;
  final String? toStatus;
  final String? performedById;
  final String? performedByName;
  final String? notes;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  const AuditLog({
    required this.id,
    required this.action,
    this.fromStatus,
    this.toStatus,
    this.performedById,
    this.performedByName,
    this.notes,
    this.metadata,
    required this.createdAt,
  });

  factory AuditLog.fromJson(Map<String, dynamic> json) {
    final performer = json['performedBy'] as Map<String, dynamic>?;
    return AuditLog(
      id: json['id']?.toString() ?? '',
      action: json['action']?.toString() ?? '',
      fromStatus: json['fromStatus']?.toString(),
      toStatus: json['toStatus']?.toString(),
      performedById: performer?['id']?.toString(),
      performedByName: performer?['username']?.toString(),
      notes: json['notes']?.toString(),
      metadata: json['metadata'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(
        json['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  String get actionLabel {
    if (fromStatus != null && toStatus != null) {
      return '$fromStatus → $toStatus';
    }
    return action;
  }
}
