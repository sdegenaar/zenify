/// Action types for restoring mutations
enum ZenMutationAction {
  create,
  update,
  delete,
  custom,
}

/// A serialized mutation job that can be stored and replayed
class ZenMutationJob {
  final String id;
  final String mutationKey;
  final ZenMutationAction action;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int retryCount;

  const ZenMutationJob({
    required this.id,
    required this.mutationKey,
    required this.action,
    this.payload = const {},
    required this.createdAt,
    this.retryCount = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'mutationKey': mutationKey,
        'action': action.index,
        'payload': payload,
        'createdAt': createdAt.toIso8601String(),
        'retryCount': retryCount,
      };

  factory ZenMutationJob.fromJson(Map<String, dynamic> json) {
    return ZenMutationJob(
      id: json['id'] as String,
      mutationKey: json['mutationKey'] as String,
      action: ZenMutationAction.values[json['action'] as int],
      payload: json['payload'] as Map<String, dynamic>,
      createdAt: DateTime.parse(json['createdAt'] as String),
      retryCount: json['retryCount'] as int? ?? 0,
    );
  }
}
