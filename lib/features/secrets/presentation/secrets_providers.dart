import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:github_manager/core/providers/core_providers.dart';
import 'package:github_manager/features/secrets/data/repository_secrets_service.dart';
import 'package:github_manager/features/secrets/domain/repository_secret.dart';

final repositorySecretsServiceProvider = Provider<RepositorySecretsService>(
  (ref) => RepositorySecretsService(ref.watch(githubApiClientProvider)),
);

final repositorySecretsProvider = FutureProvider.family<List<RepositorySecret>, String>(
  (ref, repositoryFullName) =>
      ref.watch(repositorySecretsServiceProvider).listSecrets(repositoryFullName),
);
