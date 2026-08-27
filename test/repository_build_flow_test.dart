import 'package:flutter_test/flutter_test.dart';
import 'package:github_manager/core/network/github_api_client.dart';
import 'package:github_manager/core/security/secure_storage_service.dart';
import 'package:github_manager/features/repositories/data/repository_git_service.dart';
import 'package:github_manager/features/repositories/domain/repository_git_models.dart';

void main() {
  const workflow = RepositoryWorkflow(
    id: 42,
    name: 'Release',
    path: '.github/workflows/release.yml',
    state: 'active',
  );

  RepositoryWorkflowRun run() => RepositoryWorkflowRun.fromJson({
        'id': 100,
        'workflow_id': 42,
        'path': '.github/workflows/release.yml',
        'name': 'Release',
        'display_title': 'Commit atual',
        'status': 'queued',
        'head_branch': 'main',
        'head_sha': 'abc1234',
        'event': 'push',
        'run_number': 1,
        'run_attempt': 1,
      });

  test('existing push run prevents duplicate workflow_dispatch', () async {
    final service = _FakeRepositoryGitService(
      workflow: workflow,
      runResponses: [
        [run()],
      ],
    );

    final result = await service.ensureBuildForCommit(
      repositoryFullName: 'owner/repo',
      branch: 'main',
      commitSha: 'abc1234',
      verificationAttempts: 1,
      verificationDelay: Duration.zero,
      postDispatchDelay: Duration.zero,
    );

    expect(result.dispatchTriggered, isFalse);
    expect(result.runs, hasLength(1));
    expect(service.dispatchCount, 0);
  });

  test('last-second run prevents manual dispatch race', () async {
    final service = _FakeRepositoryGitService(
      workflow: workflow,
      runResponses: [
        const [],
        [run()],
      ],
    );

    final result = await service.ensureBuildForCommit(
      repositoryFullName: 'owner/repo',
      branch: 'main',
      commitSha: 'abc1234',
      verificationAttempts: 1,
      verificationDelay: Duration.zero,
      postDispatchDelay: Duration.zero,
    );

    expect(result.dispatchTriggered, isFalse);
    expect(service.dispatchCount, 0);
  });

  test('dispatches generic structurally valid Release workflow once', () async {
    final service = _FakeRepositoryGitService(
      workflow: workflow,
      runResponses: const [[], [], []],
    );

    final result = await service.ensureBuildForCommit(
      repositoryFullName: 'owner/repo',
      branch: 'main',
      commitSha: 'abc1234',
      verificationAttempts: 1,
      verificationDelay: Duration.zero,
      postDispatchDelay: Duration.zero,
    );

    expect(result.dispatchTriggered, isTrue);
    expect(result.workflow?.name, 'Release');
    expect(service.dispatchCount, 1);
  });
}

class _FakeRepositoryGitService extends RepositoryGitService {
  _FakeRepositoryGitService({
    required this.workflow,
    required List<List<RepositoryWorkflowRun>> runResponses,
  })  : _runResponses = List<List<RepositoryWorkflowRun>>.from(runResponses),
        super(GitHubApiClient(SecureStorageService()));

  final RepositoryWorkflow workflow;
  final List<List<RepositoryWorkflowRun>> _runResponses;
  int dispatchCount = 0;
  int _runIndex = 0;

  @override
  Future<List<RepositoryWorkflow>> listWorkflows(String repositoryFullName) async =>
      [workflow];

  @override
  Future<RepositoryTextFile> readTextFile({
    required String repositoryFullName,
    required String branch,
    required String path,
  }) async =>
      const RepositoryTextFile(
        name: 'release.yml',
        path: '.github/workflows/release.yml',
        sha: 'sha',
        size: 200,
        content: '''
name: Release
on:
  push:
    branches: [main]
  workflow_dispatch:
jobs:
  build:
    steps:
      - run: flutter build apk --release
      - uses: actions/upload-artifact@v4
        with:
          path: build/app/outputs/flutter-apk/app-release.apk
''',
      );

  @override
  Future<List<RepositoryWorkflowRun>> listWorkflowRunsForCommit({
    required String repositoryFullName,
    required String commitSha,
  }) async {
    if (_runResponses.isEmpty) return const [];
    final index = _runIndex < _runResponses.length
        ? _runIndex++
        : _runResponses.length - 1;
    return _runResponses[index];
  }

  @override
  Future<int?> dispatchWorkflow({
    required String repositoryFullName,
    required RepositoryWorkflow workflow,
    required String ref,
  }) async {
    dispatchCount++;
    return 999;
  }
}
