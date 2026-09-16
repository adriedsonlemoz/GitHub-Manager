import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:github_manager/core/network/github_api_client.dart';
import 'package:github_manager/core/security/secure_storage_service.dart';
import 'package:github_manager/features/builds/data/artifact_service.dart';
import 'package:github_manager/features/builds/data/build_cleanup_service.dart';
import 'package:github_manager/features/builds/domain/action_artifact.dart';
import 'package:github_manager/features/builds/domain/release_asset.dart';
import 'package:github_manager/features/repositories/domain/repository_git_models.dart';

void main() {
  RepositoryWorkflowRun run() => RepositoryWorkflowRun.fromJson({
        'id': 77,
        'workflow_id': 10,
        'path': '.github/workflows/android-apk.yml',
        'name': 'Android APK',
        'display_title': 'Release v2.0.70',
        'status': 'completed',
        'conclusion': 'success',
        'head_branch': 'main',
        'head_sha': 'abc1234567890',
        'run_number': 70,
        'run_attempt': 1,
      });

  test('deleting build also removes linked Release APK', () async {
    final events = <String>[];
    final client = _FakeGitHubApiClient(events);
    final artifacts = _FakeArtifactService(client, events)
      ..runArtifacts = const [
        ActionArtifact(
          id: 501,
          name: 'android-apk-2.0.70',
          sizeBytes: 100,
          expired: false,
          createdAt: null,
          workflowRunId: 77,
          workflowRunHeadSha: 'abc1234567890',
        ),
      ]
      ..releaseApks = const [
        ReleaseAsset(
          id: 601,
          name: 'app-release.apk',
          sizeBytes: 200,
          downloadUrl: '',
          tagName: 'v2.0.70',
          publishedAt: null,
          releaseId: 701,
          releaseName: 'Version 2.0.70',
          targetCommitish: 'abc1234567890',
        ),
      ];

    final result = await BuildCleanupService(client, artifacts).deleteBuild(
      repositoryFullName: 'owner/repo',
      run: run(),
    );

    expect(result.artifactsRemoved, 1);
    expect(result.releaseApksRemoved, 1);
    expect(result.hasWarnings, isFalse);
    expect(events, contains('delete-run:77'));
    expect(events, contains('delete-release-asset:601'));
    expect(
      events.indexOf('delete-run:77'),
      lessThan(events.indexOf('delete-release-asset:601')),
    );
  });

  test('remaining artifact after run deletion is deleted explicitly', () async {
    final events = <String>[];
    final client = _FakeGitHubApiClient(events);
    final leftover = const ActionArtifact(
      id: 999,
      name: 'android-apk-old',
      sizeBytes: 100,
      expired: false,
      createdAt: null,
      workflowRunId: 77,
    );
    final artifacts = _FakeArtifactService(client, events)
      ..runArtifacts = const [leftover]
      ..repositoryArtifactsAfterRunDelete = const [leftover];

    final result = await BuildCleanupService(client, artifacts).deleteBuild(
      repositoryFullName: 'owner/repo',
      run: run(),
    );

    expect(result.artifactsRemoved, 1);
    expect(events, contains('delete-artifact:999'));
  });
}

class _FakeGitHubApiClient extends GitHubApiClient {
  _FakeGitHubApiClient(this.events) : super(SecureStorageService());

  final List<String> events;

  @override
  Future<Response<T>> delete<T>(
    String path, {
    Object? data,
    CancelToken? cancelToken,
  }) async {
    final match = RegExp(r'/actions/runs/(\d+)$').firstMatch(path);
    if (match != null) events.add('delete-run:${match.group(1)}');
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: 204,
    );
  }
}

class _FakeArtifactService extends ArtifactService {
  _FakeArtifactService(GitHubApiClient client, this.events) : super(client);

  final List<String> events;
  List<ActionArtifact> runArtifacts = const [];
  List<ActionArtifact> repositoryArtifactsAfterRunDelete = const [];
  List<ReleaseAsset> releaseApks = const [];

  @override
  Future<List<ActionArtifact>> listArtifactsForRun({
    required String repositoryFullName,
    required int runId,
  }) async =>
      runArtifacts;

  @override
  Future<List<ActionArtifact>> listArtifacts(String repositoryFullName) async =>
      repositoryArtifactsAfterRunDelete;

  @override
  Future<List<ReleaseAsset>> findReleaseApksForBuild({
    required String repositoryFullName,
    required RepositoryWorkflowRun run,
  }) async =>
      releaseApks;

  @override
  Future<void> deleteArtifact({
    required String repositoryFullName,
    required int artifactId,
  }) async {
    events.add('delete-artifact:$artifactId');
  }

  @override
  Future<void> deleteReleaseAsset({
    required String repositoryFullName,
    required int assetId,
  }) async {
    events.add('delete-release-asset:$assetId');
  }
}
