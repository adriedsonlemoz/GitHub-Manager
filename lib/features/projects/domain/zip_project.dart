class ZipProjectPreview {
  const ZipProjectPreview({
    required this.path,
    required this.name,
    required this.archiveBytes,
    required this.uncompressedBytes,
    required this.fileCount,
    required this.folderCount,
    required this.projectType,
    required this.importantFiles,
    required this.commonRoot,
    this.projectName,
    this.packageName,
    this.applicationId,
    this.version,
    this.versionCode,
  });

  final String path;
  final String name;
  final int archiveBytes;
  final int uncompressedBytes;
  final int fileCount;
  final int folderCount;
  final String projectType;
  final List<String> importantFiles;
  final String? commonRoot;
  final String? projectName;
  final String? packageName;
  final String? applicationId;
  final String? version;
  final int? versionCode;

  String get identityLabel =>
      projectName?.trim().isNotEmpty == true
          ? projectName!.trim()
          : packageName?.trim().isNotEmpty == true
              ? packageName!.trim()
              : name.replaceFirst(RegExp(r'\.zip$', caseSensitive: false), '');

  String? get versionLabel {
    final value = version?.trim();
    if (value == null || value.isEmpty) return null;
    if (versionCode == null || value.contains('+')) return value;
    return '$value+$versionCode';
  }
}

enum ProjectUploadProgressKind {
  stage,
  unchanged,
  changed,
  resumed,
  transferStarted,
  removed,
}

class ProjectUploadProgress {
  const ProjectUploadProgress({
    required this.phase,
    this.current = 0,
    this.total = 0,
    this.fileName,
    this.kind = ProjectUploadProgressKind.stage,
    this.affectedCount = 0,
  });

  final String phase;
  final int current;
  final int total;
  final String? fileName;
  final ProjectUploadProgressKind kind;
  final int affectedCount;

  double? get fraction => total <= 0 ? null : current / total;

  bool get isFileActivity =>
      kind != ProjectUploadProgressKind.stage &&
      kind != ProjectUploadProgressKind.removed;
}

class ProjectUploadResult {
  const ProjectUploadResult({
    required this.commitSha,
    required this.fileCount,
    required this.changed,
  });

  final String commitSha;
  final int fileCount;
  final bool changed;
}
