import 'package:github_manager/features/builds/domain/action_artifact.dart';
import 'package:github_manager/features/builds/domain/release_asset.dart';
import 'package:github_manager/features/builds/domain/release_asset_group.dart';
import 'package:github_manager/features/projects/domain/project_safety_check.dart';

/// Identifica os arquivos APK mais recentes sem confiar que a primeira
/// resposta da API do GitHub já é a versão correta.
///
/// Releases oficiais têm prioridade sobre artifacts de teste, exceto quando
/// um artifact informa explicitamente uma versão semanticamente mais nova.
/// Informações desconhecidas nunca são apresentadas como versões confirmadas.
class LatestApkShortcut {
  const LatestApkShortcut({
    required this.releaseAssets,
    required this.artifacts,
    this.version,
  });

  final List<ReleaseAsset> releaseAssets;
  final List<ActionArtifact> artifacts;
  final String? version;

  bool get isEmpty => releaseAssets.isEmpty && artifacts.isEmpty;
  bool get isRelease => releaseAssets.isNotEmpty;
  bool get hasVariants =>
      isRelease ? releaseAssets.length > 1 : artifacts.length > 1;

  static LatestApkShortcut resolve({
    required List<ReleaseAsset> releases,
    required List<ActionArtifact> artifacts,
  }) {
    final latestRelease = groupReleaseAssets(
      releases.where((asset) => asset.isApk && asset.id > 0),
    ).where((group) => group.hasApk).firstOrNull;

    final validArtifacts = artifacts.where(
      (item) => !item.expired && item.id > 0 && item.likelyContainsApk,
    ).toList()
      ..sort((left, right) {
        final leftDate = left.createdAt?.millisecondsSinceEpoch ?? 0;
        final rightDate = right.createdAt?.millisecondsSinceEpoch ?? 0;
        final dateOrder = rightDate.compareTo(leftDate);
        return dateOrder != 0 ? dateOrder : right.id.compareTo(left.id);
      });

    List<ActionArtifact> newestArtifacts = const [];
    String? artifactVersion;
    if (validArtifacts.isNotEmpty) {
      final first = validArtifacts.first;
      artifactVersion = _versionFromFileName(first.name);
      newestArtifacts = validArtifacts.where((item) {
        // Agrupa variantes da mesma execução, sem misturar builds antigas.
        if (first.workflowRunId != null) {
          return item.workflowRunId == first.workflowRunId;
        }
        final version = _versionFromFileName(item.name);
        if (artifactVersion != null) return version == artifactVersion;
        return item.id == first.id;
      }).toList(growable: false);
    }

    if (latestRelease != null) {
      final releaseVersion = latestRelease.version;
      final artifactIsNewer =
          newestArtifacts.isNotEmpty &&
          ProjectSafetyCheck.compareVersions(
                artifactVersion,
                null,
                releaseVersion,
                null,
              ) ==
              ProjectVersionComparison.newer;
      if (!artifactIsNewer) {
        return LatestApkShortcut(
          releaseAssets: latestRelease.assets.where((asset) => asset.isApk).toList(),
          artifacts: const [],
          version: releaseVersion,
        );
      }
    }

    if (newestArtifacts.isNotEmpty) {
      return LatestApkShortcut(
        releaseAssets: const [],
        artifacts: newestArtifacts,
        version: artifactVersion,
      );
    }
    return const LatestApkShortcut(releaseAssets: [], artifacts: []);
  }

  static String? _versionFromFileName(String name) => RegExp(
    r'(\d+\.\d+\.\d+(?:-(?:alpha|beta|preview|pre|rc|dev)(?:[._-]?\d+)?)?)',
    caseSensitive: false,
  ).firstMatch(name)?.group(1);
}
