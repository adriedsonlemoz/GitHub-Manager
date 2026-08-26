import 'package:github_manager/core/network/github_api_client.dart';
import 'package:github_manager/features/builds/domain/action_artifact.dart';
import 'package:github_manager/features/builds/domain/release_asset.dart';

class ArtifactService {
  ArtifactService(this._client);

  final GitHubApiClient _client;

  Future<List<ActionArtifact>> listArtifacts(String repositoryFullName) async {
    final artifacts = <ActionArtifact>[];
    for (var page = 1; page <= 5; page++) {
      final response = await _client.get<Map<String, dynamic>>(
        '/repos/$repositoryFullName/actions/artifacts',
        queryParameters: {'per_page': 100, 'page': page},
      );
      final raw = response.data?['artifacts'];
      if (raw is! List) {
        break;
      }
      final pageItems = raw
          .whereType<Map>()
          .map(
            (json) => ActionArtifact.fromJson(
              Map<String, dynamic>.from(json),
            ),
          )
          .toList(growable: false);
      artifacts.addAll(pageItems);
      if (raw.length < 100) {
        break;
      }
    }
    artifacts.sort(
      (a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
    );
    return artifacts;
  }

  Future<void> deleteArtifact({
    required String repositoryFullName,
    required int artifactId,
  }) =>
      _client.delete<void>(
        '/repos/$repositoryFullName/actions/artifacts/$artifactId',
      );


  Future<List<ReleaseAsset>> listReleaseAssets(String repositoryFullName) async {
    final response = await _client.get<List<dynamic>>(
      '/repos/$repositoryFullName/releases',
      queryParameters: {'per_page': 30, 'page': 1},
    );
    final result = <ReleaseAsset>[];
    for (final rawRelease in response.data ?? const <dynamic>[]) {
      if (rawRelease is! Map) continue;
      final release = Map<String, dynamic>.from(rawRelease);
      final tag = release['tag_name'] as String? ?? '';
      final published = DateTime.tryParse(release['published_at'] as String? ?? '');
      final assets = release['assets'];
      if (assets is! List) continue;
      for (final rawAsset in assets) {
        if (rawAsset is Map) {
          final asset = ReleaseAsset.fromJson(
            Map<String, dynamic>.from(rawAsset),
            tagName: tag,
            publishedAt: published,
          );
          if (asset.downloadUrl.isNotEmpty) result.add(asset);
        }
      }
    }
    result.sort(
      (a, b) => (b.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(a.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
    );
    return result;
  }

  Future<int> deleteOlderApkArtifacts(String repositoryFullName) async {
    final artifacts = await listArtifacts(repositoryFullName);
    final apks = artifacts
        .where((item) => item.likelyContainsApk && !item.expired)
        .toList();
    if (apks.length <= 1) return 0;
    var deleted = 0;
    for (final artifact in apks.skip(1)) {
      await deleteArtifact(
        repositoryFullName: repositoryFullName,
        artifactId: artifact.id,
      );
      deleted++;
    }
    return deleted;
  }

}
