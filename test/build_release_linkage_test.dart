import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:github_manager/core/network/github_api_client.dart';
import 'package:github_manager/core/security/secure_storage_service.dart';
import 'package:github_manager/features/builds/data/artifact_service.dart';
import 'package:github_manager/features/builds/domain/release_asset.dart';
import 'package:github_manager/features/repositories/domain/repository_git_models.dart';

void main() {
  RepositoryWorkflowRun run({required String version, required String sha}) =>
      RepositoryWorkflowRun.fromJson({
        'id': 77,
        'workflow_id': 10,
        'path': '.github/workflows/android-apk.yml',
        'name': 'Android APK',
        'display_title': 'Release v$version',
        'status': 'completed',
        'conclusion': 'success',
        'head_branch': 'main',
        'head_sha': sha,
        'run_number': 70,
        'run_attempt': 1,
      }).withBuildVersion(version);

  test('release target pointing to run SHA is linked directly', () async {
    final client = _CommitClient('unused');
    final service = _ReleaseListArtifactService(client)
      ..assets = [
        const ReleaseAsset(
          id: 10,
          name: 'app-release.apk',
          sizeBytes: 20,
          downloadUrl: '',
          tagName: 'v2.0.70',
          publishedAt: null,
          releaseId: 20,
          releaseName: '2.0.70',
          targetCommitish: 'abc123',
        ),
      ];

    final matches = await service.findReleaseApksForBuild(
      repositoryFullName: 'owner/repo',
      run: run(version: '2.0.70', sha: 'abc123'),
    );

    expect(matches.map((item) => item.id), [10]);
    expect(client.commitLookups, 0);
  });

  test('legacy release version matching does not confuse 2.0.7 with 2.0.70', () async {
    final client = _CommitClient('abc123');
    final service = _ReleaseListArtifactService(client)
      ..assets = [
        const ReleaseAsset(
          id: 11,
          name: 'app-2.0.70.apk',
          sizeBytes: 20,
          downloadUrl: '',
          tagName: 'v2.0.70',
          publishedAt: null,
          releaseId: 21,
          releaseName: 'Version 2.0.70',
          targetCommitish: 'main',
        ),
      ];

    final matches = await service.findReleaseApksForBuild(
      repositoryFullName: 'owner/repo',
      run: run(version: '2.0.7', sha: 'abc123'),
    );

    expect(matches, isEmpty);
    expect(client.commitLookups, 0);
  });
}

class _CommitClient extends GitHubApiClient {
  _CommitClient(this.sha) : super(SecureStorageService());

  final String sha;
  int commitLookups = 0;

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) async {
    commitLookups++;
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data: <String, dynamic>{'sha': sha} as T,
    );
  }
}

class _ReleaseListArtifactService extends ArtifactService {
  _ReleaseListArtifactService(GitHubApiClient client) : super(client);

  List<ReleaseAsset> assets = const [];

  @override
  Future<List<ReleaseAsset>> listReleaseAssets(String repositoryFullName) async =>
      assets;
}
