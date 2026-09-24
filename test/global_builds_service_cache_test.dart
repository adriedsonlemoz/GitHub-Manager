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

  test('mantém somente as builds do commit mais recente de cada repositório', () async {
    final repositoryService = _CountingRepositoryService();
    final gitService = _CountingGitService(includeOldRun: true);
    final service = GlobalBuildsService(repositoryService, gitService);

    final snapshot = await service.load();
    final activeEntries = snapshot.entries
        .where((entry) => entry.repository.fullName == _activeRepo.fullName)
        .toList(growable: false);

    expect(activeEntries, hasLength(1));
    expect(activeEntries.single.run.id, 10);
    expect(activeEntries.single.run.headSha, 'latest-sha');
  });


  test('agrupa workflows diferentes do mesmo commit mais recente', () async {
    final repositoryService = _CountingRepositoryService();
    final gitService = _CountingGitService(includeSiblingRun: true);
    final service = GlobalBuildsService(repositoryService, gitService);

    final snapshot = await service.load();
    final group = snapshot.groups.firstWhere(
      (item) => item.repository.fullName == _activeRepo.fullName,
    );

    expect(group.buildCount, 2);
    expect(group.entries.map((entry) => entry.run.id), containsAll(<int>[10, 11]));
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
  _CountingGitService({this.includeOldRun = false, this.includeSiblingRun = false})
      : super(GitHubApiClient(SecureStorageService()));

  final bool includeOldRun;
  final bool includeSiblingRun;
  final Map<String, int> calls = {};

  @override
  Future<List<RepositoryWorkflowRun>> listRecentWorkflowRuns(
    String repositoryFullName, {
    int perPage = 100,
    bool enrichVersions = true,
  }) async {
    calls.update(repositoryFullName, (value) => value + 1, ifAbsent: () => 1);
    if (repositoryFullName == _activeRepo.fullName) {
      return [
        _run(
          status: 'in_progress',
          conclusion: null,
          id: 10,
          headSha: 'latest-sha',
          createdAt: DateTime(2026, 9, 24, 12),
        ),
        if (includeSiblingRun)
          _run(
            status: 'in_progress',
            conclusion: null,
            id: 11,
            headSha: 'latest-sha',
            createdAt: DateTime(2026, 9, 24, 12),
          ),
        if (includeOldRun)
          _run(
            status: 'completed',
            conclusion: 'success',
            id: 9,
            headSha: 'old-sha',
            createdAt: DateTime(2026, 9, 23, 12),
          ),
      ];
    }
    return [
      _run(
        status: 'completed',
        conclusion: 'success',
        id: 20,
        headSha: 'done-sha',
        createdAt: DateTime(2026, 9, 24, 11),
      ),
    ];
  }
}

RepositoryWorkflowRun _run({
  required String status,
  required String? conclusion,
  required int id,
  String headSha = 'abcdef123456',
  DateTime? createdAt,
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
      headSha: headSha,
      commitMessage: 'Build',
      event: 'push',
      runNumber: id,
      runAttempt: 1,
      createdAt: createdAt ?? DateTime(2026, 9, 24),
      startedAt: createdAt ?? DateTime(2026, 9, 24),
      updatedAt: createdAt ?? DateTime(2026, 9, 24),
      htmlUrl: 'https://example.invalid/run/$id',
    );
