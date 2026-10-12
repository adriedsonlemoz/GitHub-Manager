/// Metadados opcionais produzidos PELO workflow da execução, sem confundir
/// o número do GitHub Actions com a versão Android.
class BuildManifest {
  const BuildManifest({
    required this.versionName,
    required this.versionCode,
    required this.applicationId,
    required this.runId,
    required this.commitSha,
    required this.apks,
  });

  final String versionName;
  final int versionCode;
  final String applicationId;
  final int runId;
  final String commitSha;
  final List<BuildManifestApk> apks;

  /// Rejeita manifestos de outra execução, evitando metadados incorretos.
  static BuildManifest? parse(
    Object? json, {
    required int expectedRunId,
    required String expectedCommit,
  }) {
    if (json is! Map) return null;
    if (json['schema'] != 1) return null;
    final runId = json['run_id'];
    final sha = json['commit_sha'];
    final version = json['version_name'];
    final code = json['version_code'];
    final applicationId = json['application_id'];
    if (runId is! int || runId != expectedRunId ||
        sha is! String || sha.toLowerCase() != expectedCommit.toLowerCase() ||
        version is! String || version.trim().isEmpty || version.length > 96 ||
        code is! int || code < 1 ||
        applicationId is! String || applicationId.trim().isEmpty) {
      return null;
    }
    final rawApks = json['apks'];
    final apks = <BuildManifestApk>[];
    if (rawApks is List) {
      for (final raw in rawApks.take(40)) {
        if (raw is! Map) continue;
        final name = raw['file_name'];
        final abi = raw['abi'];
        final bytes = raw['size_bytes'];
        final sha256 = raw['sha256'];
        if (name is! String || !name.endsWith('.apk') ||
            name.contains('/') || name.contains('\\') || name.length > 220 ||
            bytes is! int || bytes <= 0 ||
            sha256 is! String || !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(sha256)) {
          continue;
        }
        apks.add(BuildManifestApk(
          fileName: name,
          abi: abi is String && abi.length <= 40 ? abi : 'unknown',
          sizeBytes: bytes,
          sha256: sha256.toLowerCase(),
        ));
      }
    }
    return BuildManifest(
      versionName: version.trim(),
      versionCode: code,
      applicationId: applicationId.trim(),
      runId: runId,
      commitSha: sha.toLowerCase(),
      apks: List.unmodifiable(apks),
    );
  }
}

class BuildManifestApk {
  const BuildManifestApk({
    required this.fileName,
    required this.abi,
    required this.sizeBytes,
    required this.sha256,
  });
  final String fileName;
  final String abi;
  final int sizeBytes;
  final String sha256;
}
