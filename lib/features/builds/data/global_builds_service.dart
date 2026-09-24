import 'package:github_manager/features/builds/domain/global_build_entry.dart';
import 'package:github_manager/features/repositories/data/repository_git_service.dart';
import 'package:github_manager/features/repositories/data/repository_service.dart';
import 'package:github_manager/features/repositories/domain/repository_git_models.dart';

class GlobalBuildsService {
  GlobalBuildsService(this._repositoryService, this._gitService);

  final RepositoryService _repositoryService;
  final RepositoryGitService _gitService;

  Future<GlobalBuildsSnapshot> load({int runsPerRepository = 5}) async {
    final repositories = await _repositoryService.listRepositories();
    final entries = <GlobalBuildEntry>[];
    var unavailable = 0;
    var withBuilds = 0;

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
          unavailable++;
          continue;
        }
        if (result.runs.isNotEmpty) withBuilds++;
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

    entries.sort((a, b) {
      final aDate = a.date ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.date ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

    return GlobalBuildsSnapshot(
      entries: List<GlobalBuildEntry>.unmodifiable(entries.take(250)),
      repositoryCount: repositories.length,
      repositoriesWithBuilds: withBuilds,
      unavailableRepositories: unavailable,
      loadedAt: DateTime.now(),
    );
  }
}
