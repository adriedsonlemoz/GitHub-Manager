import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:github_manager/core/providers/core_providers.dart';
import 'package:github_manager/features/home/data/github_profile_repository.dart';
import 'package:github_manager/features/home/domain/github_profile.dart';

final githubProfileRepositoryProvider = Provider<GitHubProfileRepository>(
  (ref) => GitHubProfileRepository(ref.watch(githubApiClientProvider)),
);

final githubProfileProvider = FutureProvider.autoDispose<GitHubProfile>(
  (ref) => ref.watch(githubProfileRepositoryProvider).loadProfile(),
);
