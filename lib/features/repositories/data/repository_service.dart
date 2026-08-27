import 'package:github_manager/core/network/github_api_client.dart';
import 'package:github_manager/core/persistence/local_database.dart';
import 'package:github_manager/features/repositories/domain/github_repository.dart';

class RepositoryService {
  RepositoryService(this._client, this._database);

  static const _cacheKey = 'github.repositories';
  static const _followedKey = 'followed.repositories';
  static const _followedCacheKey = 'followed.repositories.cache';
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


  Future<List<GitHubRepository>> listFollowedRepositories() async {
    final stored = await _database.readJson(_followedKey);
    final names = stored is List
        ? stored
            .whereType<String>()
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList()
        : <String>[];
    if (names.isEmpty) return const <GitHubRepository>[];

    final cachedRaw = await _database.readJson(_followedCacheKey);
    final cached = cachedRaw is List
        ? cachedRaw
            .whereType<Map>()
            .map((json) => GitHubRepository.fromJson(Map<String, dynamic>.from(json)))
            .where((repo) => names.contains(repo.fullName))
            .toList()
        : <GitHubRepository>[];

    if (cached.length == names.length) {
      cached.sort(
        (a, b) => (b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
      );
      return cached;
    }

    try {
      return await refreshFollowedRepositories();
    } catch (_) {
      cached.sort(
        (a, b) => (b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
      );
      return cached;
    }
  }

  Future<List<GitHubRepository>> refreshFollowedRepositories() async {
    final stored = await _database.readJson(_followedKey);
    final names = stored is List
        ? stored
            .whereType<String>()
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList()
        : <String>[];
    if (names.isEmpty) {
      await _database.putJson(_followedCacheKey, const <Object>[]);
      return const <GitHubRepository>[];
    }

    final results = await Future.wait(
      names.map((fullName) async {
        try {
          return await getRepository(fullName);
        } catch (_) {
          return null;
        }
      }),
    );
    final repositories = results.whereType<GitHubRepository>().toList();
    repositories.sort(
      (a, b) => (b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
    );
    await _database.putJson(
      _followedCacheKey,
      repositories.map((item) => item.toJson()).toList(),
    );
    return repositories;
  }

  Future<GitHubRepository?> getFollowedRepository(String fullName) async {
    final cachedRaw = await _database.readJson(_followedCacheKey);
    if (cachedRaw is List) {
      for (final raw in cachedRaw.whereType<Map>()) {
        final repo = GitHubRepository.fromJson(Map<String, dynamic>.from(raw));
        if (repo.fullName.toLowerCase() == fullName.toLowerCase()) {
          return repo;
        }
      }
    }
    return null;
  }

  Future<GitHubRepository> followRepository(String input) async {
    final fullName = _normalizeRepositoryReference(input);
    final repository = await getRepository(fullName);
    final stored = await _database.readJson(_followedKey);
    final names = stored is List
        ? stored.whereType<String>().map((item) => item.trim()).where((item) => item.isNotEmpty).toList()
        : <String>[];
    if (!names.contains(repository.fullName)) {
      names.add(repository.fullName);
      await _database.putJson(_followedKey, names);
    }

    final cachedRaw = await _database.readJson(_followedCacheKey);
    final cached = cachedRaw is List
        ? cachedRaw.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList()
        : <Map<String, dynamic>>[];
    cached.removeWhere(
      (item) => (item['full_name'] as String? ?? '').toLowerCase() ==
          repository.fullName.toLowerCase(),
    );
    cached.add(repository.toJson());
    await _database.putJson(_followedCacheKey, cached);
    return repository;
  }

  Future<void> unfollowRepository(String fullName) async {
    final stored = await _database.readJson(_followedKey);
    final names = stored is List
        ? stored.whereType<String>().map((item) => item.trim()).where((item) => item.isNotEmpty).toList()
        : <String>[];
    names.removeWhere((item) => item.toLowerCase() == fullName.toLowerCase());
    await _database.putJson(_followedKey, names);
    final cachedRaw = await _database.readJson(_followedCacheKey);
    if (cachedRaw is List) {
      final cached = cachedRaw.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList()
        ..removeWhere(
          (item) => (item['full_name'] as String? ?? '').toLowerCase() ==
              fullName.toLowerCase(),
        );
      await _database.putJson(_followedCacheKey, cached);
    }
  }

  static List<String> _referenceParts(String input) {
    var value = input.trim();
    if (value.isEmpty) return const <String>[];

    final uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme) {
      final host = uri.host.toLowerCase();
      if (host != 'github.com' && host != 'www.github.com') {
        throw const FormatException('Use um link válido do GitHub.');
      }
      value = uri.path;
    }

    value = value.split('?').first.split('#').first;
    value = value.replaceAll(RegExp(r'^/+|/+$'), '');
    if (value.endsWith('.git')) {
      value = value.substring(0, value.length - 4);
    }
    return value
        .split('/')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static String _normalizeRepositoryReference(String input) {
    final parts = _referenceParts(input);
    if (parts.length != 2) {
      if (parts.length == 1) {
        throw const FormatException(
          'Este link é de um perfil do GitHub. Escolha um repositório dessa conta.',
        );
      }
      throw const FormatException(
        'Informe um repositório como github.com/owner/repo ou owner/repo.',
      );
    }
    return '${parts[0]}/${parts[1]}';
  }

  Future<List<GitHubRepository>> listOwnerRepositoriesFromReference(
    String input,
  ) async {
    final parts = _referenceParts(input);
    if (parts.length != 1) {
      throw const FormatException('Informe somente o perfil do GitHub, como github.com/owner.');
    }
    final owner = parts.single;
    final repositories = <GitHubRepository>[];
    for (var page = 1; page <= 5; page++) {
      final response = await _client.get<List<dynamic>>(
        '/users/$owner/repos',
        queryParameters: {
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
      if (pageItems.length < 100) break;
    }
    return repositories;
  }

  Future<GitHubRepository> getRepository(String fullName) async {
    final response = await _client.get<Map<String, dynamic>>('/repos/$fullName');
    return GitHubRepository.fromJson(response.data ?? const <String, dynamic>{});
  }

  Future<GitHubRepository> forkRepository(String fullName) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/repos/$fullName/forks',
      data: const {'default_branch_only': false},
    );
    await _database.clearGitHubCache();
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
