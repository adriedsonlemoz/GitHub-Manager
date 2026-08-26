import 'package:github_manager/core/network/github_api_client.dart';
import 'package:github_manager/core/persistence/local_database.dart';
import 'package:github_manager/features/repositories/domain/github_repository.dart';

class RepositoryService {
  RepositoryService(this._client, this._database);

  static const _cacheKey = 'github.repositories';
  final GitHubApiClient _client;
  final LocalDatabase _database;

  Future<List<GitHubRepository>> listRepositories() async {
    try {
      final repositories = <GitHubRepository>[];
      for (var page = 1; page <= 10; page++) {
        final response = await _client.get<List<dynamic>>(
          '/user/repos',
          queryParameters: {
            'affiliation': 'owner,collaborator,organization_member',
            'sort': 'updated',
            'direction': 'desc',
            'per_page': 100,
            'page': page,
          },
        );
        final pageItems = (response.data ?? const <dynamic>[])
            .whereType<Map>()
            .map(
              (json) => GitHubRepository.fromJson(
                Map<String, dynamic>.from(json),
              ),
            )
            .toList(growable: false);
        repositories.addAll(pageItems);
        if (pageItems.length < 100) {
          break;
        }
      }
      await _database.putJson(
        _cacheKey,
        repositories.map((item) => item.toJson()).toList(),
      );
      return repositories;
    } catch (_) {
      final cached = await _database.readJson(_cacheKey);
      if (cached is List) {
        return cached
            .whereType<Map>()
            .map(
              (json) => GitHubRepository.fromJson(
                Map<String, dynamic>.from(json),
              ),
            )
            .toList(growable: false);
      }
      rethrow;
    }
  }

  Future<GitHubRepository> getRepository(String fullName) async {
    final response = await _client.get<Map<String, dynamic>>('/repos/$fullName');
    return GitHubRepository.fromJson(response.data ?? const <String, dynamic>{});
  }

  Future<GitHubRepository> createRepository({
    required String name,
    String? description,
    bool isPrivate = false,
    String? homepage,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/user/repos',
      data: {
        'name': name.trim(),
        'description': description?.trim() ?? '',
        'private': isPrivate,
        'homepage': homepage?.trim() ?? '',
        'auto_init': true,
      },
    );
    await _database.clearGitHubCache();
    return GitHubRepository.fromJson(response.data ?? const {});
  }

  Future<GitHubRepository> updateRepository({
    required String fullName,
    required String name,
    required String description,
    required bool isPrivate,
    required bool isArchived,
    String? homepage,
  }) async {
    final response = await _client.patch<Map<String, dynamic>>(
      '/repos/$fullName',
      data: {
        'name': name.trim(),
        'description': description.trim(),
        'private': isPrivate,
        'archived': isArchived,
        'homepage': homepage?.trim() ?? '',
      },
    );
    await _database.clearGitHubCache();
    return GitHubRepository.fromJson(response.data ?? const {});
  }

  Future<void> deleteRepository(String fullName) async {
    await _client.delete<void>('/repos/$fullName');
    await _database.clearGitHubCache();
  }
}
