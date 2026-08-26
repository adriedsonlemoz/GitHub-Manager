class RepositoryProjectInfo {
  const RepositoryProjectInfo({
    required this.projectName,
    required this.version,
    required this.technologies,
  });

  final String projectName;
  final String? version;
  final List<String> technologies;

  String get technologiesLabel =>
      technologies.isEmpty ? 'Tecnologia não identificada' : technologies.join(' • ');
}
