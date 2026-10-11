import 'package:github_manager/features/builds/domain/global_build_entry.dart';
import 'package:github_manager/features/repositories/data/repository_git_service.dart';
import 'package:github_manager/features/repositories/data/repository_service.dart';
import 'package:github_manager/features/repositories/domain/github_repository.dart';
import 'package:github_manager/features/repositories/domain/repository_git_models.dart';

class GlobalBuildsService {
  GlobalBuildsService(this._repositoryService, this._gitService, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  static const repositoryCacheLifetime = Duration(minutes: 10);
  static const fullRunsRefreshInterval = Duration(minutes: 1);
  static const activeRunsRefreshInterval = Duration(seconds: 15);

  final RepositoryService _repositoryService;
  final RepositoryGitService _gitService;
  final DateTime Function() _clock;

  List<GitHubRepository>? _repositoriesCache;
  DateTime? _repositoriesLoadedAt;
  DateTime? _lastFullRunsRefresh;
  DateTime? _lastActiveRunsRefresh;
  GlobalBuildsSnapshot? _snapshot;
  Future<GlobalBuildsSnapshot>? _loadInFlight;

  Future<GlobalBuildsSnapshot> load({
    int runsPerRepository = 25,
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
    _lastActiveRunsRefresh = null;
    _snapshot = null;
  }

  Future<GlobalBuildsSnapshot> _loadNow({
    required int runsPerRepository,
    required bool forceFull,
  }) async {
    final now = _clock();
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
        historyEntries: [
          for (final repository in repositories)
            if (loaded.failedRepositoryNames.contains(repository.fullName))
              ...?previous?.historyEntries.where(
                (entry) => entry.repository.fullName == repository.fullName,
              )
            else
              ...loaded.entries.where(
                (entry) => entry.repository.fullName == repository.fullName,
              ),
        ],
        unavailableRepositories: loaded.failedRepositoryNames.length,
        loadedAt: _clock(),
      );
      _snapshot = snapshot;
      _lastFullRunsRefresh = _clock();
      _lastActiveRunsRefresh = _lastFullRunsRefresh;
      return snapshot;
    }

    final activeRepositoryNames = previous.entries
        .where((entry) => entry.isRunning)
        .map((entry) => entry.repository.fullName)
        .toSet();
    if (activeRepositoryNames.isEmpty ||
        (_lastActiveRunsRefresh != null &&
            now.difference(_lastActiveRunsRefresh!) < activeRunsRefreshInterval)) {
      // Sem build ativa, só há varredura global a cada minuto.
      // Com build ativa, consultas são limitadas a uma a cada 15 segundos.
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
      for (final entry in previous.historyEntries.isEmpty
          ? previous.entries
          : previous.historyEntries)
        if (!activeRepositoryNames.contains(entry.repository.fullName) ||
            failed.contains(entry.repository.fullName))
          entry,
      ...loaded.entries,
    ];
    final snapshot = _snapshotFrom(
      repositories: repositories,
      historyEntries: merged,
      unavailableRepositories: failed.isEmpty
          ? previous.unavailableRepositories
          : previous.unavailableRepositories > failed.length
              ? previous.unavailableRepositories
              : failed.length,
      loadedAt: _clock(),
    );
    _snapshot = snapshot;
    _lastActiveRunsRefresh = _clock();
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
        for (final raw in result.runs) {
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
    required List<GlobalBuildEntry> historyEntries,
    required int unavailableRepositories,
    required DateTime loadedAt,
  }) {
    historyEntries.sort((a, b) {
      final aDate = a.date ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.date ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    final latestByRepository = <String, List<GlobalBuildEntry>>{};
    for (final entry in historyEntries) {
      latestByRepository.putIfAbsent(entry.repository.fullName, () => []).add(entry);
    }
    final latestEntries = <GlobalBuildEntry>[
      for (final runs in latestByRepository.values)
        ..._latestBuildSet(runs.map((entry) => entry.run).toList()).map(
          (run) => runs.firstWhere((entry) => entry.run.id == run.id),
        ),
    ]..sort((a, b) => (b.date ?? DateTime.fromMillisecondsSinceEpoch(0))
        .compareTo(a.date ?? DateTime.fromMillisecondsSinceEpoch(0)));
    final repositoriesWithBuilds = latestEntries
        .map((entry) => entry.repository.fullName)
        .toSet()
        .length;

    return GlobalBuildsSnapshot(
      entries: List<GlobalBuildEntry>.unmodifiable(latestEntries),
      historyEntries: List<GlobalBuildEntry>.unmodifiable(historyEntries),
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
