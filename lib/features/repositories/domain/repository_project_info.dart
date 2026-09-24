class RepositoryProjectInfo {
  const RepositoryProjectInfo({
    required this.projectName,
    required this.version,
    required this.technologies,
    this.packageName,
    this.applicationId,
    this.versionCode,
    this.versionSource,
  });

  final String projectName;
  final String? version;
  final List<String> technologies;
  final String? packageName;
  final String? applicationId;
  final int? versionCode;
  final String? versionSource;

  String? get versionLabel {
    final value = version?.trim();
    if (value == null || value.isEmpty) return null;
    if (versionCode == null || value.contains('+')) return value;
    return '$value+$versionCode';
  }

  String? get displayVersionLabel {
    final value = versionLabel;
    if (value == null) return null;
    final source = versionSource?.trim();
    return source == null || source.isEmpty ? value : '$value • $source';
  }

  String get technologiesLabel =>
      technologies.isEmpty ? 'Tecnologia não identificada' : technologies.join(' • ');
}
