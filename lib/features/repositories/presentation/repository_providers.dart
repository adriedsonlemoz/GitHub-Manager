import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:github_manager/core/providers/core_providers.dart';
import 'package:github_manager/features/repositories/data/repository_git_service.dart';
import 'package:github_manager/features/repositories/data/repository_project_info_service.dart';
import 'package:github_manager/features/repositories/data/repository_service.dart';
import 'package:github_manager/features/repositories/domain/github_repository.dart';
import 'package:github_manager/features/repositories/domain/repository_project_info.dart';

final repositoryServiceProvider = Provider<RepositoryService>(
  (ref) => RepositoryService(
    ref.watch(githubApiClientProvider),
    ref.watch(localDatabaseProvider),
  ),
);

final repositoriesProvider = FutureProvider<List<GitHubRepository>>(
  (ref) => ref.watch(repositoryServiceProvider).listRepositories(),
);

final repositoryGitServiceProvider = Provider<RepositoryGitService>(
  (ref) => RepositoryGitService(ref.watch(githubApiClientProvider)),
);

final repositoryProjectInfoServiceProvider = Provider<RepositoryProjectInfoService>(
  (ref) => RepositoryProjectInfoService(ref.watch(githubApiClientProvider)),
);

final repositoryProjectInfoProvider = FutureProvider.family<RepositoryProjectInfo, GitHubRepository>(
  (ref, repository) => ref.watch(repositoryProjectInfoServiceProvider).load(repository),
);
