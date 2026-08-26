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
}

class ProjectUploadProgress {
  const ProjectUploadProgress({
    required this.phase,
    this.current = 0,
    this.total = 0,
    this.fileName,
  });

  final String phase;
  final int current;
  final int total;
  final String? fileName;

  double? get fraction => total <= 0 ? null : current / total;
}

class ProjectUploadResult {
  const ProjectUploadResult({
    required this.commitSha,
    required this.fileCount,
  });

  final String commitSha;
  final int fileCount;
}
