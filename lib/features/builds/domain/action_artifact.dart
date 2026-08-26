class ActionArtifact {
  const ActionArtifact({
    required this.id,
    required this.name,
    required this.sizeBytes,
    required this.expired,
    required this.createdAt,
    this.workflowRunId,
  });

  final int id;
  final String name;
  final int sizeBytes;
  final bool expired;
  final DateTime? createdAt;
  final int? workflowRunId;

  bool get likelyContainsApk {
    final lower = name.toLowerCase();
    if (lower.contains('symbol')) {
      return false;
    }
    return lower.contains('apk') ||
        lower.contains('android') ||
        lower.contains('armeabi-v7a') ||
        lower.contains('arm32') ||
        lower.contains('arm64') ||
        lower.contains('release');
  }

  factory ActionArtifact.fromJson(Map<String, dynamic> json) {
    final workflow = json['workflow_run'];
    return ActionArtifact(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? 'Artifact',
      sizeBytes: (json['size_in_bytes'] as num?)?.toInt() ?? 0,
      expired: json['expired'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
      workflowRunId: workflow is Map
          ? (workflow['id'] as num?)?.toInt()
          : null,
    );
  }
}
