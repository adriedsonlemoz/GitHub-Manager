import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:github_manager/core/providers/core_providers.dart';
import 'package:github_manager/features/auth/data/github_auth_repository.dart';

final githubAuthRepositoryProvider = Provider<GitHubAuthRepository>(
  (ref) => GitHubAuthRepository(
    ref.watch(secureStorageProvider),
    ref.watch(localDatabaseProvider),
  ),
);

final githubConnectionProvider = FutureProvider<bool>(
  (ref) => ref.watch(githubAuthRepositoryProvider).isConnected(),
);
