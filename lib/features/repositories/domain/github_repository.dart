class GitHubRepository {
  const GitHubRepository({
    required this.id,
    required this.name,
    required this.fullName,
    required this.isPrivate,
    required this.isArchived,
    required this.defaultBranch,
    required this.updatedAt,
    required this.htmlUrl,
    this.description,
    this.language,
    this.homepage,
  });

  final int id;
  final String name;
  final String fullName;
  final String? description;
  final bool isPrivate;
  final bool isArchived;
  final String defaultBranch;
  final String? language;
  final String? homepage;
  final DateTime? updatedAt;
  final String htmlUrl;

  factory GitHubRepository.fromJson(Map<String, dynamic> json) => GitHubRepository(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: json['name'] as String? ?? '',
        fullName: json['full_name'] as String? ?? '',
        description: json['description'] as String?,
        isPrivate: json['private'] as bool? ?? false,
        isArchived: json['archived'] as bool? ?? false,
        defaultBranch: json['default_branch'] as String? ?? 'main',
        language: json['language'] as String?,
        homepage: json['homepage'] as String?,
        updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
        htmlUrl: json['html_url'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'full_name': fullName,
        'description': description,
        'private': isPrivate,
        'archived': isArchived,
        'default_branch': defaultBranch,
        'language': language,
        'homepage': homepage,
        'updated_at': updatedAt?.toIso8601String(),
        'html_url': htmlUrl,
      };
}
