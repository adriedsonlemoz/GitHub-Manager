class RepositorySecret {
  const RepositorySecret({
    required this.name,
    required this.createdAt,
    required this.updatedAt,
  });

  final String name;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory RepositorySecret.fromJson(Map<String, dynamic> json) => RepositorySecret(
        name: json['name'] as String? ?? '',
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
        updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
      );
}
