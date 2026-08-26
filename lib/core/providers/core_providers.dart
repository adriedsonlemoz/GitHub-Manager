import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:github_manager/core/network/github_api_client.dart';
import 'package:github_manager/core/persistence/local_database.dart';
import 'package:github_manager/core/security/secure_storage_service.dart';

final secureStorageProvider = Provider<SecureStorageService>(
  (ref) => SecureStorageService(),
);

final localDatabaseProvider = Provider<LocalDatabase>((ref) {
  final database = LocalDatabase();
  ref.onDispose(database.close);
  return database;
});

final githubApiClientProvider = Provider<GitHubApiClient>(
  (ref) => GitHubApiClient(ref.watch(secureStorageProvider)),
);
