import 'package:github_manager/features/repositories/domain/github_repository.dart';
import 'package:github_manager/features/repositories/domain/repository_git_models.dart';

class GlobalBuildEntry {
  const GlobalBuildEntry({
    required this.repository,
    required this.run,
  });

  final GitHubRepository repository;
  final RepositoryWorkflowRun run;

  DateTime? get date => run.createdAt ?? run.startedAt ?? run.updatedAt;
  String get branch => run.branch.trim().isEmpty
      ? repository.defaultBranch
      : run.branch.trim();

  bool get isRunning => run.isRunning;
  bool get isSuccess => run.status == 'completed' && run.conclusion == 'success';
  bool get isFailure => run.status == 'completed' &&
      const <String>{
        'failure',
        'timed_out',
        'action_required',
        'startup_failure',
        'stale',
      }.contains(run.conclusion);
}

class GlobalRepositoryBuildGroup {
  GlobalRepositoryBuildGroup({
    required this.repository,
    required List<GlobalBuildEntry> entries,
  }) : entries = List<GlobalBuildEntry>.unmodifiable(
          List<GlobalBuildEntry>.from(entries)
            ..sort((a, b) {
              final aDate = a.date ?? DateTime.fromMillisecondsSinceEpoch(0);
              final bDate = b.date ?? DateTime.fromMillisecondsSinceEpoch(0);
              return bDate.compareTo(aDate);
            }),
        );

  final GitHubRepository repository;
  final List<GlobalBuildEntry> entries;

  GlobalBuildEntry get primary => entries.first;
  DateTime? get date => primary.date;
  String get branch => primary.branch;
  String? get version {
    for (final entry in entries) {
      final value = entry.run.detectedVersion?.trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  int get buildCount => entries.length;
  int get runningCount => entries.where((entry) => entry.isRunning).length;
  bool get isRunning => runningCount > 0;
  bool get isFailure => !isRunning && entries.any((entry) => entry.isFailure);
  bool get isSuccess =>
      entries.isNotEmpty && !isRunning && entries.every((entry) => entry.isSuccess);
}

class GlobalBuildsSnapshot {
  const GlobalBuildsSnapshot({
    required this.entries,
    required this.repositoryCount,
    required this.repositoriesWithBuilds,
    required this.unavailableRepositories,
    required this.loadedAt,
  });

  final List<GlobalBuildEntry> entries;
  final int repositoryCount;
  final int repositoriesWithBuilds;
  final int unavailableRepositories;
  final DateTime loadedAt;

  List<GlobalRepositoryBuildGroup> get groups {
    final grouped = <String, List<GlobalBuildEntry>>{};
    final repositories = <String, GitHubRepository>{};
    for (final entry in entries) {
      final key = entry.repository.fullName;
      repositories[key] = entry.repository;
      grouped.putIfAbsent(key, () => <GlobalBuildEntry>[]).add(entry);
    }
    final result = <GlobalRepositoryBuildGroup>[
      for (final item in grouped.entries)
        GlobalRepositoryBuildGroup(
          repository: repositories[item.key]!,
          entries: item.value,
        ),
    ];
    result.sort((a, b) {
      final aDate = a.date ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.date ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    return List<GlobalRepositoryBuildGroup>.unmodifiable(result);
  }

  int get runningCount => entries.where((item) => item.isRunning).length;
  int get successCount => entries.where((item) => item.isSuccess).length;
  int get failureCount => entries.where((item) => item.isFailure).length;
}
