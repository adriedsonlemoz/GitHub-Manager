import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:github_manager/core/network/github_api_client.dart';
import 'package:github_manager/core/security/secure_storage_service.dart';
import 'package:github_manager/features/builds/data/artifact_service.dart';
import 'package:github_manager/features/builds/domain/action_artifact.dart';
import 'package:github_manager/features/builds/domain/release_asset.dart';

void main() {
  test('older APK cleanup covers Actions artifacts and Release APKs', () async {
    final client = _NoopGitHubApiClient();
    final service = _CleanupArtifactService(client)
      ..artifacts = [
        ActionArtifact(
          id: 1,
          name: 'android-apk-2.0.70',
          sizeBytes: 10,
          expired: false,
          createdAt: DateTime(2026, 9, 16),
          workflowRunId: 70,
        ),
        ActionArtifact(
          id: 3,
          name: 'android-universal-2.0.70',
          sizeBytes: 10,
          expired: false,
          createdAt: DateTime(2026, 9, 16),
          workflowRunId: 70,
        ),
        ActionArtifact(
          id: 2,
          name: 'android-apk-2.0.69',
          sizeBytes: 10,
          expired: true,
          createdAt: DateTime(2026, 9, 15),
          workflowRunId: 69,
        ),
      ]
      ..releaseAssets = [
        ReleaseAsset(
          id: 10,
          name: 'app-2.0.70.apk',
          sizeBytes: 20,
          downloadUrl: '',
          tagName: 'v2.0.70',
          publishedAt: DateTime(2026, 9, 16),
          releaseId: 100,
          releaseName: '2.0.70',
          targetCommitish: 'sha70',
        ),
        ReleaseAsset(
          id: 12,
          name: 'app-arm64-2.0.70.apk',
          sizeBytes: 20,
          downloadUrl: '',
          tagName: 'v2.0.70',
          publishedAt: DateTime(2026, 9, 16),
          releaseId: 100,
          releaseName: '2.0.70',
          targetCommitish: 'sha70',
        ),
        ReleaseAsset(
          id: 11,
          name: 'app-2.0.69.apk',
          sizeBytes: 20,
          downloadUrl: '',
          tagName: 'v2.0.69',
          publishedAt: DateTime(2026, 9, 15),
          releaseId: 101,
          releaseName: '2.0.69',
          targetCommitish: 'sha69',
        ),
      ];

    final result = await service.deleteOlderApkOutputs('owner/repo');

    expect(result.artifactsDeleted, 1);
    expect(result.releaseAssetsDeleted, 1);
    expect(result.totalDeleted, 2);
    expect(result.hasWarnings, isFalse);
    expect(service.deletedArtifactIds, [2]);
    expect(service.deletedReleaseAssetIds, [11]);
  });

  test('cleanup handles many versions inside one fixed Release', () async {
    final client = _NoopGitHubApiClient();
    final published = DateTime(2026, 9, 12, 23, 6);
    final service = _CleanupArtifactService(client)
      ..releaseAssets = [
        ReleaseAsset(
          id: 31,
          name: 'Explorador-XP-0.1.0-alpha.31-performance.apk',
          sizeBytes: 20,
          downloadUrl: '',
          tagName: 'explorador-xp-dev',
          publishedAt: published,
          releaseId: 300,
          releaseName: 'explorador-xp-dev',
          targetCommitish: 'main',
        ),
        ReleaseAsset(
          id: 74,
          name: 'Explorador-XP-0.1.0-alpha.74-universal.apk',
          sizeBytes: 20,
          downloadUrl: '',
          tagName: 'explorador-xp-dev',
          publishedAt: published,
          releaseId: 300,
          releaseName: 'explorador-xp-dev',
          targetCommitish: 'main',
        ),
        ReleaseAsset(
          id: 75,
          name: 'Explorador-XP-0.1.0-alpha.74-arm64-v8a.apk',
          sizeBytes: 20,
          downloadUrl: '',
          tagName: 'explorador-xp-dev',
          publishedAt: published,
          releaseId: 300,
          releaseName: 'explorador-xp-dev',
          targetCommitish: 'main',
        ),
        ReleaseAsset(
          id: 66,
          name: 'Explorador-XP-0.1.0-alpha.66-performance.apk',
          sizeBytes: 20,
          downloadUrl: '',
          tagName: 'explorador-xp-dev',
          publishedAt: published,
          releaseId: 300,
          releaseName: 'explorador-xp-dev',
          targetCommitish: 'main',
        ),
      ];

    final result = await service.deleteOlderApkOutputs('owner/repo');

    expect(result.releaseAssetsDeleted, 2);
    expect(service.deletedReleaseAssetIds, containsAll(<int>[31, 66]));
    expect(service.deletedReleaseAssetIds, isNot(contains(74)));
    expect(service.deletedReleaseAssetIds, isNot(contains(75)));
  });

  test('cleanup can use the APK snapshot already visible on screen', () async {
    final client = _NoopGitHubApiClient();
    final published = DateTime(2026, 9, 12, 23, 6);
    final service = _CleanupArtifactService(client);
    final visibleReleaseAssets = [
      ReleaseAsset(
        id: 31,
        name: 'Explorador-XP-0.1.0-alpha.31-performance.apk',
        sizeBytes: 20,
        downloadUrl: '',
        tagName: 'explorador-xp-dev',
        publishedAt: published,
        releaseId: 300,
        releaseName: 'explorador-xp-dev',
        targetCommitish: 'main',
      ),
      ReleaseAsset(
        id: 74,
        name: 'Explorador-XP-0.1.0-alpha.74-performance.apk',
        sizeBytes: 20,
        downloadUrl: '',
        tagName: 'explorador-xp-dev',
        publishedAt: published,
        releaseId: 300,
        releaseName: 'explorador-xp-dev',
        targetCommitish: 'main',
      ),
    ];

    final result = await service.deleteOlderApkOutputs(
      'owner/repo',
      artifactsSnapshot: const <ActionArtifact>[],
      releaseAssetsSnapshot: visibleReleaseAssets,
    );

    expect(result.releaseAssetsDeleted, 1);
    expect(service.deletedReleaseAssetIds, [31]);
  });

  test('cleanup keeps newest active APK artifact even if newer record expired', () async {
    final client = _NoopGitHubApiClient();
    final service = _CleanupArtifactService(client)
      ..artifacts = [
        ActionArtifact(
          id: 1,
          name: 'android-apk-expired-newer',
          sizeBytes: 10,
          expired: true,
          createdAt: DateTime(2026, 9, 16),
        ),
        ActionArtifact(
          id: 2,
          name: 'android-apk-active',
          sizeBytes: 10,
          expired: false,
          createdAt: DateTime(2026, 9, 15),
        ),
      ];

    final result = await service.deleteOlderApkOutputs('owner/repo');

    expect(result.artifactsDeleted, 1);
    expect(service.deletedArtifactIds, [1]);
  });
}

class _NoopGitHubApiClient extends GitHubApiClient {
  _NoopGitHubApiClient() : super(SecureStorageService());

  @override
  Future<Response<T>> delete<T>(
    String path, {
    Object? data,
    CancelToken? cancelToken,
  }) async =>
      Response<T>(
        requestOptions: RequestOptions(path: path),
        statusCode: 204,
      );
}

class _CleanupArtifactService extends ArtifactService {
  _CleanupArtifactService(GitHubApiClient client) : super(client);

  List<ActionArtifact> artifacts = const [];
  List<ReleaseAsset> releaseAssets = const [];
  final List<int> deletedArtifactIds = [];
  final List<int> deletedReleaseAssetIds = [];

  @override
  Future<List<ActionArtifact>> listArtifacts(String repositoryFullName) async =>
      artifacts;

  @override
  Future<List<ReleaseAsset>> listReleaseAssets(String repositoryFullName) async =>
      releaseAssets;

  @override
  Future<void> deleteArtifact({
    required String repositoryFullName,
    required int artifactId,
  }) async {
    deletedArtifactIds.add(artifactId);
  }

  @override
  Future<void> deleteReleaseAsset({
    required String repositoryFullName,
    required int assetId,
  }) async {
    deletedReleaseAssetIds.add(assetId);
  }
}
