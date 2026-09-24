import 'package:flutter_test/flutter_test.dart';
import 'package:github_manager/core/network/github_api_client.dart';
import 'package:github_manager/core/persistence/local_database.dart';
import 'package:github_manager/core/security/secure_storage_service.dart';
import 'package:github_manager/features/builds/data/global_builds_service.dart';
import 'package:github_manager/features/repositories/data/repository_git_service.dart';
import 'package:github_manager/features/repositories/data/repository_service.dart';
import 'package:github_manager/features/repositories/domain/github_repository.dart';
import 'package:github_manager/features/repositories/domain/repository_git_models.dart';

void main() {
  test('poll curto reutiliza repositórios e consulta apenas projeto com build ativa', () async {
    final repositoryService = _CountingRepositoryService();
    final gitService = _CountingGitService();
    final service = GlobalBuildsService(repositoryService, gitService);

    final first = await service.load();
    expect(first.runningCount, 1);
    expect(repositoryService.calls, 1);
    expect(gitService.calls['owner/active'], 1);
    expect(gitService.calls['owner/done'], 1);

    final second = await service.load();
    expect(repositoryService.calls, 1, reason: 'lista de repositórios deve vir do cache');
    expect(gitService.calls['owner/active'], 2, reason: 'build ativa precisa ser atualizada');
    expect(gitService.calls['owner/done'], 1, reason: 'build concluída não deve ser repolida a cada ciclo curto');
    expect(second.entries, isNotEmpty);
  });

  test('invalidate força atualização completa inclusive da lista de repositórios', () async {
    final repositoryService = _CountingRepositoryService();
    final gitService = _CountingGitService();
    final service = GlobalBuildsService(repositoryService, gitService);

    await service.load();
    service.invalidate();
    await service.load();

    expect(repositoryService.calls, 2);
    expect(gitService.calls['owner/active'], 2);
    expect(gitService.calls['owner/done'], 2);
  });
}

const _activeRepo = GitHubRepository(
  id: 1,
  name: 'active',
  fullName: 'owner/active',
  isPrivate: false,
  isArchived: false,
  defaultBranch: 'main',
  updatedAt: null,
  htmlUrl: 'https://example.invalid/owner/active',
);

const _doneRepo = GitHubRepository(
  id: 2,
  name: 'done',
  fullName: 'owner/done',
  isPrivate: false,
  isArchived: false,
  defaultBranch: 'main',
  updatedAt: null,
  htmlUrl: 'https://example.invalid/owner/done',
);

class _CountingRepositoryService extends RepositoryService {
  _CountingRepositoryService()
      : super(GitHubApiClient(SecureStorageService()), LocalDatabase.shared);

  int calls = 0;

  @override
  Future<List<GitHubRepository>> listRepositories() async {
    calls++;
    return const [_activeRepo, _doneRepo];
  }
}

class _CountingGitService extends RepositoryGitService {
  _CountingGitService() : super(GitHubApiClient(SecureStorageService()));

  final Map<String, int> calls = {};

  @override
  Future<List<RepositoryWorkflowRun>> listRecentWorkflowRuns(
    String repositoryFullName, {
    int perPage = 100,
    bool enrichVersions = true,
  }) async {
    calls.update(repositoryFullName, (value) => value + 1, ifAbsent: () => 1);
    if (repositoryFullName == _activeRepo.fullName) {
      return [_run(status: 'in_progress', conclusion: null, id: 10)];
    }
    return [_run(status: 'completed', conclusion: 'success', id: 20)];
  }
}

RepositoryWorkflowRun _run({
  required String status,
  required String? conclusion,
  required int id,
}) =>
    RepositoryWorkflowRun(
      id: id,
      workflowId: 1,
      workflowPath: '.github/workflows/android.yml',
      name: 'Android',
      title: 'Build',
      status: status,
      conclusion: conclusion,
      branch: 'main',
      headSha: 'abcdef123456',
      commitMessage: 'Build',
      event: 'push',
      runNumber: id,
      runAttempt: 1,
      createdAt: DateTime(2026, 9, 24),
      startedAt: DateTime(2026, 9, 24),
      updatedAt: DateTime(2026, 9, 24),
      htmlUrl: 'https://example.invalid/run/$id',
    );
