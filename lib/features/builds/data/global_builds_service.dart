import 'package:github_manager/features/builds/domain/global_build_entry.dart';
import 'package:github_manager/features/repositories/data/repository_git_service.dart';
import 'package:github_manager/features/repositories/data/repository_service.dart';
import 'package:github_manager/features/repositories/domain/github_repository.dart';
import 'package:github_manager/features/repositories/domain/repository_git_models.dart';

class GlobalBuildsService {
  GlobalBuildsService(this._repositoryService, this._gitService);

  static const repositoryCacheLifetime = Duration(minutes: 10);
  static const fullRunsRefreshInterval = Duration(minutes: 1);

  final RepositoryService _repositoryService;
  final RepositoryGitService _gitService;

  List<GitHubRepository>? _repositoriesCache;
  DateTime? _repositoriesLoadedAt;
  DateTime? _lastFullRunsRefresh;
  GlobalBuildsSnapshot? _snapshot;
  Future<GlobalBuildsSnapshot>? _loadInFlight;

  Future<GlobalBuildsSnapshot> load({
    int runsPerRepository = 8,
    bool forceFull = false,
  }) {
    final running = _loadInFlight;
    if (running != null) return running;
    final future = _loadNow(
      runsPerRepository: runsPerRepository,
      forceFull: forceFull,
    );
    _loadInFlight = future;
    return future.whenComplete(() {
      if (identical(_loadInFlight, future)) _loadInFlight = null;
    });
  }

  void invalidate() {
    _repositoriesCache = null;
    _repositoriesLoadedAt = null;
    _lastFullRunsRefresh = null;
    _snapshot = null;
  }

  Future<GlobalBuildsSnapshot> _loadNow({
    required int runsPerRepository,
    required bool forceFull,
  }) async {
    final now = DateTime.now();
    final repositories = await _repositories(
      now: now,
      forceRefresh: forceFull,
    );
    final previous = _snapshot;
    final fullRefreshDue = forceFull ||
        previous == null ||
        _lastFullRunsRefresh == null ||
        now.difference(_lastFullRunsRefresh!) >= fullRunsRefreshInterval;

    if (fullRefreshDue) {
      final loaded = await _queryRepositories(
        repositories,
        runsPerRepository: runsPerRepository,
      );
      final snapshot = _snapshotFrom(
        repositories: repositories,
        entries: loaded.entries,
        unavailableRepositories: loaded.failedRepositoryNames.length,
        loadedAt: now,
      );
      _snapshot = snapshot;
      _lastFullRunsRefresh = now;
      return snapshot;
    }

    final activeRepositoryNames = previous.entries
        .where((entry) => entry.isRunning)
        .map((entry) => entry.repository.fullName)
        .toSet();
    if (activeRepositoryNames.isEmpty) {
      // A tela pede refresh a cada poucos segundos, mas sem execução ativa o
      // serviço mantém o snapshot e só faz nova varredura global após 1 minuto.
      return previous;
    }

    final activeRepositories = repositories
        .where((repo) => activeRepositoryNames.contains(repo.fullName))
        .toList(growable: false);
    if (activeRepositories.isEmpty) return previous;

    final loaded = await _queryRepositories(
      activeRepositories,
      runsPerRepository: runsPerRepository,
    );
    final failed = loaded.failedRepositoryNames;

    final merged = <GlobalBuildEntry>[
      for (final entry in previous.entries)
        if (!activeRepositoryNames.contains(entry.repository.fullName) ||
            failed.contains(entry.repository.fullName))
          entry,
      ...loaded.entries,
    ];
    final snapshot = _snapshotFrom(
      repositories: repositories,
      entries: merged,
      unavailableRepositories: failed.isEmpty
          ? previous.unavailableRepositories
          : previous.unavailableRepositories > failed.length
              ? previous.unavailableRepositories
              : failed.length,
      loadedAt: now,
    );
    _snapshot = snapshot;
    return snapshot;
  }

  Future<List<GitHubRepository>> _repositories({
    required DateTime now,
    required bool forceRefresh,
  }) async {
    final cached = _repositoriesCache;
    final loadedAt = _repositoriesLoadedAt;
    if (!forceRefresh &&
        cached != null &&
        loadedAt != null &&
        now.difference(loadedAt) < repositoryCacheLifetime) {
      return cached;
    }

    final repositories = await _repositoryService.listRepositories();
    _repositoriesCache = List<GitHubRepository>.unmodifiable(repositories);
    _repositoriesLoadedAt = now;
    return _repositoriesCache!;
  }

  Future<_GlobalBuildQueryResult> _queryRepositories(
    List<GitHubRepository> repositories, {
    required int runsPerRepository,
  }) async {
    final entries = <GlobalBuildEntry>[];
    final failed = <String>{};

    const batchSize = 6;
    for (var start = 0; start < repositories.length; start += batchSize) {
      final end = (start + batchSize) > repositories.length
          ? repositories.length
          : start + batchSize;
      final batch = repositories.sublist(start, end);
      final results = await Future.wait(
        batch.map((repository) async {
          try {
            final runs = await _gitService.listRecentWorkflowRuns(
              repository.fullName,
              perPage: runsPerRepository,
              enrichVersions: false,
            );
            return (repository: repository, runs: runs, failed: false);
          } catch (_) {
            return (
              repository: repository,
              runs: const <RepositoryWorkflowRun>[],
              failed: true,
            );
          }
        }),
      );

      for (final result in results) {
        if (result.failed) {
          failed.add(result.repository.fullName);
          continue;
        }
        for (final raw in _latestBuildSet(result.runs)) {
          entries.add(
            GlobalBuildEntry(
              repository: result.repository,
              run: raw,
            ),
          );
        }
      }
    }

    return _GlobalBuildQueryResult(
      entries: entries,
      failedRepositoryNames: failed,
    );
  }

  static List<RepositoryWorkflowRun> _latestBuildSet(
    List<RepositoryWorkflowRun> runs,
  ) {
    if (runs.isEmpty) return const <RepositoryWorkflowRun>[];
    final ordered = List<RepositoryWorkflowRun>.from(runs)
      ..sort((a, b) => _runDate(b).compareTo(_runDate(a)));
    final latest = ordered.first;
    final latestSha = latest.headSha.trim();
    if (latestSha.isEmpty) return <RepositoryWorkflowRun>[latest];

    final result = ordered
        .where((run) => run.headSha.trim() == latestSha)
        .toList(growable: false);
    return result.isEmpty ? <RepositoryWorkflowRun>[latest] : result;
  }

  static DateTime _runDate(RepositoryWorkflowRun run) =>
      run.createdAt ??
      run.startedAt ??
      run.updatedAt ??
      DateTime.fromMillisecondsSinceEpoch(0);

  GlobalBuildsSnapshot _snapshotFrom({
    required List<GitHubRepository> repositories,
    required List<GlobalBuildEntry> entries,
    required int unavailableRepositories,
    required DateTime loadedAt,
  }) {
    entries.sort((a, b) {
      final aDate = a.date ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.date ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    final repositoriesWithBuilds = entries
        .map((entry) => entry.repository.fullName)
        .toSet()
        .length;

    return GlobalBuildsSnapshot(
      entries: List<GlobalBuildEntry>.unmodifiable(entries),
      repositoryCount: repositories.length,
      repositoriesWithBuilds: repositoriesWithBuilds,
      unavailableRepositories: unavailableRepositories,
      loadedAt: loadedAt,
    );
  }
}

class _GlobalBuildQueryResult {
  const _GlobalBuildQueryResult({
    required this.entries,
    required this.failedRepositoryNames,
  });

  final List<GlobalBuildEntry> entries;
  final Set<String> failedRepositoryNames;
}
