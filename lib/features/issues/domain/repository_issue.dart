class RepositoryIssue {
  const RepositoryIssue({
    required this.number,
    required this.title,
    required this.state,
    required this.body,
    required this.author,
    required this.createdAt,
    required this.updatedAt,
    required this.htmlUrl,
    required this.labels,
  });

  final int number;
  final String title;
  final String state;
  final String body;
  final String author;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String htmlUrl;
  final List<String> labels;

  bool get isOpen => state == 'open';

  factory RepositoryIssue.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    final rawLabels = json['labels'];
    return RepositoryIssue(
      number: (json['number'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? '',
      state: json['state'] as String? ?? 'open',
      body: json['body'] as String? ?? '',
      author: user is Map ? user['login'] as String? ?? 'desconhecido' : 'desconhecido',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
      htmlUrl: json['html_url'] as String? ?? '',
      labels: rawLabels is List
          ? rawLabels
              .whereType<Map>()
              .map((item) => item['name'] as String? ?? '')
              .where((name) => name.isNotEmpty)
              .toList(growable: false)
          : const [],
    );
  }
}
