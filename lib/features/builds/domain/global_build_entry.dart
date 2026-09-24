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

  int get runningCount => entries.where((item) => item.isRunning).length;
  int get successCount => entries.where((item) => item.isSuccess).length;
  int get failureCount => entries.where((item) => item.isFailure).length;
}
