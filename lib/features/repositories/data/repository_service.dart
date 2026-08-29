import 'package:github_manager/core/errors/app_exception.dart';
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
  Future<List<GitHubRepository>>? _repositoriesRefreshInFlight;
  Future<List<GitHubRepository>>? _followedRefreshInFlight;

  Future<List<GitHubRepository>> _readRepositoryCache() async {
    final cached = await _database.readJson(_cacheKey);
    if (cached is! List) return const <GitHubRepository>[];
    return cached
        .whereType<Map>()
        .map(
          (json) => GitHubRepository.fromJson(
            Map<String, dynamic>.from(json),
          ),
        )
        .toList(growable: false);
  }

  Future<void> _writeRepositoryCache(
    List<GitHubRepository> repositories,
  ) async {
    await _database.putJson(
      _cacheKey,
      repositories.map((item) => item.toJson()).toList(),
    );
  }

  Future<void> _safeUpsertRepositoryCache(
    GitHubRepository repository, {
    String? replaceFullName,
  }) async {
    try {
      final repositories = (await _readRepositoryCache()).toList();
      final keys = <String>{
        repository.fullName.toLowerCase(),
        if (replaceFullName?.trim().isNotEmpty == true)
          replaceFullName!.toLowerCase(),
      };
      repositories.removeWhere(
        (item) => keys.contains(item.fullName.toLowerCase()),
      );
      repositories.insert(0, repository);
      await _writeRepositoryCache(repositories);
    } catch (_) {}
  }

  Future<void> _safeRemoveRepositoryFromCaches(String fullName) async {
    try {
      final repositories = (await _readRepositoryCache()).toList()
        ..removeWhere(
          (item) => item.fullName.toLowerCase() == fullName.toLowerCase(),
        );
      await _writeRepositoryCache(repositories);
    } catch (_) {}

    try {
      final followed = (await _readFollowedNames())
        ..removeWhere(
          (item) => item.toLowerCase() == fullName.toLowerCase(),
        );
      await _database.putJson(_followedKey, followed);
      final followedCache = await _readFollowedCache(followed);
      await _database.putJson(
        _followedCacheKey,
        followedCache.map((item) => item.toJson()).toList(),
      );
    } catch (_) {}
  }

  Future<void> _safeReplaceFollowedReference(
    String oldFullName,
    GitHubRepository repository,
  ) async {
    try {
      final names = await _readFollowedNames();
      var changed = false;
      for (var i = 0; i < names.length; i++) {
        if (names[i].toLowerCase() == oldFullName.toLowerCase()) {
          names[i] = repository.fullName;
          changed = true;
        }
      }
      if (!changed) return;
      await _database.putJson(_followedKey, names);

      final cachedRaw = await _database.readJson(_followedCacheKey);
      final cache = cachedRaw is List
          ? cachedRaw
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
          : <Map<String, dynamic>>[];
      cache.removeWhere(
        (item) =>
            (item['full_name'] as String? ?? '').toLowerCase() ==
            oldFullName.toLowerCase(),
      );
      cache.add(repository.toJson());
      await _database.putJson(_followedCacheKey, cache);
    } catch (_) {}
  }

  Future<List<GitHubRepository>> listRepositories() async {
    final cached = await _readRepositoryCache();
    if (cached.isNotEmpty) return cached;
    return refreshRepositories();
  }

  Future<List<GitHubRepository>> refreshRepositories() async {
    final running = _repositoriesRefreshInFlight;
    if (running != null) return running;

    final future = _fetchRepositoriesFromGitHub();
    _repositoriesRefreshInFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_repositoriesRefreshInFlight, future)) {
        _repositoriesRefreshInFlight = null;
      }
    }
  }

  Future<List<GitHubRepository>> _fetchRepositoriesFromGitHub() async {
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
      if (pageItems.length < 100) break;
    }
    await _writeRepositoryCache(repositories);
    return repositories;
  }

  Future<List<String>> _readFollowedNames() async {
    final stored = await _database.readJson(_followedKey);
    final source = stored is List
        ? stored.whereType<String>()
        : const Iterable<String>.empty();
    final names = <String>[];
    final seen = <String>{};
    for (final raw in source) {
      final name = raw.trim();
      if (name.isEmpty) continue;
      if (seen.add(name.toLowerCase())) names.add(name);
    }
    return names;
  }

  Future<List<GitHubRepository>> _readFollowedCache(
    List<String> names,
  ) async {
    if (names.isEmpty) return const <GitHubRepository>[];
    final wanted = names.map((name) => name.toLowerCase()).toSet();
    final cachedRaw = await _database.readJson(_followedCacheKey);
    if (cachedRaw is! List) return const <GitHubRepository>[];

    final byName = <String, GitHubRepository>{};
    for (final raw in cachedRaw.whereType<Map>()) {
      final repository =
          GitHubRepository.fromJson(Map<String, dynamic>.from(raw));
      final key = repository.fullName.toLowerCase();
      if (wanted.contains(key)) byName[key] = repository;
    }
    return _sortFollowed(byName.values.toList(growable: false));
  }

  static List<GitHubRepository> _sortFollowed(
    List<GitHubRepository> repositories,
  ) {
    repositories.sort(
      (a, b) => (b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
    );
    return repositories;
  }

  Future<List<GitHubRepository>> listFollowedRepositories() async {
    final names = await _readFollowedNames();
    if (names.isEmpty) {
      await _database.putJson(_followedCacheKey, const <Object>[]);
      return const <GitHubRepository>[];
    }

    // Causa real do spinner intermitente: a implementação anterior só aceitava
    // o cache quando ele continha 100% dos nomes salvos. Um único repositório
    // removido, renomeado ou temporariamente inacessível fazia cada abertura
    // esperar novamente todas as chamadas de rede.
    final cached = await _readFollowedCache(names);
    if (cached.isNotEmpty) {
      return cached;
    }

    // Rede só bloqueia a primeira abertura quando ainda não existe cache útil.
    return refreshFollowedRepositories();
  }

  Future<List<GitHubRepository>> refreshFollowedRepositories() async {
    final running = _followedRefreshInFlight;
    if (running != null) return running;

    final future = _refreshFollowedRepositoriesNow();
    _followedRefreshInFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_followedRefreshInFlight, future)) {
        _followedRefreshInFlight = null;
      }
    }
  }

  Future<List<GitHubRepository>> _refreshFollowedRepositoriesNow() async {
    var names = await _readFollowedNames();
    if (names.isEmpty) {
      await _database.putJson(_followedCacheKey, const <Object>[]);
      return const <GitHubRepository>[];
    }

    final previous = await _readFollowedCache(names);
    final previousByName = <String, GitHubRepository>{
      for (final item in previous) item.fullName.toLowerCase(): item,
    };
    final resolved = <String, GitHubRepository>{};
    final unavailable = <String>{};
    Object? firstFailure;

    await Future.wait(
      names.map((fullName) async {
        try {
          final repository = await getRepository(fullName);
          resolved[repository.fullName.toLowerCase()] = repository;
        } on GitHubNotFoundException {
          unavailable.add(fullName.toLowerCase());
        } catch (error) {
          firstFailure ??= error;
          final cached = previousByName[fullName.toLowerCase()];
          if (cached != null) {
            resolved[cached.fullName.toLowerCase()] = cached;
          }
        }
      }),
    );

    // Entradas que o GitHub confirma como inexistentes/inacessíveis deixam de
    // provocar novas chamadas a cada abertura do módulo.
    if (unavailable.isNotEmpty) {
      names = names
          .where((name) => !unavailable.contains(name.toLowerCase()))
          .toList(growable: false);
      await _database.putJson(_followedKey, names);
    }

    final repositories = _sortFollowed(resolved.values.toList());
    await _database.putJson(
      _followedCacheKey,
      repositories.map((item) => item.toJson()).toList(),
    );

    // Se nada pôde ser mostrado e houve erro real, propaga o erro para a UI
    // em vez de transformar a falha em lista vazia ou loading infinito.
    if (repositories.isEmpty && names.isNotEmpty && firstFailure != null) {
      throw firstFailure!;
    }
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
    final repository =
        GitHubRepository.fromJson(response.data ?? const <String, dynamic>{});
    if (repository.fullName.isNotEmpty) {
      await _safeUpsertRepositoryCache(repository);
    }
    return repository;
  }

  static bool _isAmbiguousMutationError(Object error) =>
      error is NetworkRequiredException || error is UnexpectedAppException;

  Future<String?> _currentLogin() async {
    try {
      final response = await _client.get<Map<String, dynamic>>('/user');
      final login = response.data?['login']?.toString().trim();
      return login?.isNotEmpty == true ? login : null;
    } catch (_) {
      return null;
    }
  }

  Future<GitHubRepository?> _confirmRepositoryExists(
    String fullName, {
    int attempts = 4,
  }) async {
    for (var attempt = 0; attempt < attempts; attempt++) {
      try {
        return await getRepository(fullName);
      } on GitHubNotFoundException {
        if (attempt + 1 < attempts) {
          await Future<void>.delayed(const Duration(milliseconds: 700));
        }
      } catch (_) {
        if (attempt + 1 < attempts) {
          await Future<void>.delayed(const Duration(milliseconds: 700));
        }
      }
    }
    return null;
  }

  Future<bool> _confirmRepositoryMissing(
    String fullName, {
    int attempts = 4,
  }) async {
    for (var attempt = 0; attempt < attempts; attempt++) {
      try {
        await getRepository(fullName);
        return false;
      } on GitHubNotFoundException {
        return true;
      } catch (_) {
        if (attempt + 1 < attempts) {
          await Future<void>.delayed(const Duration(milliseconds: 700));
        }
      }
    }
    return false;
  }

  Future<GitHubRepository> createRepository({
    required String name,
    String? description,
    bool isPrivate = false,
    String? homepage,
  }) async {
    final cleanName = name.trim();
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/user/repos',
        data: {
          'name': cleanName,
          'description': description?.trim() ?? '',
          'private': isPrivate,
          'homepage': homepage?.trim() ?? '',
          'auto_init': true,
        },
      );
      final repository = GitHubRepository.fromJson(response.data ?? const {});
      await _safeUpsertRepositoryCache(repository);
      return repository;
    } catch (error) {
      if (_isAmbiguousMutationError(error)) {
        final login = await _currentLogin();
        if (login != null) {
          final confirmed = await _confirmRepositoryExists('$login/$cleanName');
          if (confirmed != null) {
            await _safeUpsertRepositoryCache(confirmed);
            return confirmed;
          }
        }
      }
      rethrow;
    }
  }

  Future<GitHubRepository> updateRepository({
    required String fullName,
    required String name,
    required String description,
    required bool isPrivate,
    required bool isArchived,
    String? homepage,
  }) async {
    final cleanName = name.trim();
    final owner = fullName.split('/').first;
    final targetFullName = '$owner/$cleanName';
    try {
      final response = await _client.patch<Map<String, dynamic>>(
        '/repos/$fullName',
        data: {
          'name': cleanName,
          'description': description.trim(),
          'private': isPrivate,
          'archived': isArchived,
          'homepage': homepage?.trim() ?? '',
        },
      );
      final repository = GitHubRepository.fromJson(response.data ?? const {});
      await _safeUpsertRepositoryCache(repository, replaceFullName: fullName);
      if (repository.fullName.toLowerCase() != fullName.toLowerCase()) {
        await _safeReplaceFollowedReference(fullName, repository);
      }
      return repository;
    } catch (error) {
      if (_isAmbiguousMutationError(error)) {
        final confirmed = await _confirmRepositoryExists(targetFullName);
        if (confirmed != null) {
          await _safeUpsertRepositoryCache(confirmed, replaceFullName: fullName);
          if (confirmed.fullName.toLowerCase() != fullName.toLowerCase()) {
            await _safeReplaceFollowedReference(fullName, confirmed);
          }
          return confirmed;
        }
      }
      rethrow;
    }
  }

  Future<GitHubRepository> renameRepository({
    required String fullName,
    required String newName,
  }) async {
    final cleanName = newName.trim();
    if (cleanName.isEmpty) {
      throw const FormatException('Informe o novo nome do repositório.');
    }
    final owner = fullName.split('/').first;
    final targetFullName = '$owner/$cleanName';
    try {
      final response = await _client.patch<Map<String, dynamic>>(
        '/repos/$fullName',
        data: {'name': cleanName},
      );
      final repository = GitHubRepository.fromJson(response.data ?? const {});
      await _safeUpsertRepositoryCache(repository, replaceFullName: fullName);
      await _safeReplaceFollowedReference(fullName, repository);
      return repository;
    } catch (error) {
      if (_isAmbiguousMutationError(error)) {
        final confirmed = await _confirmRepositoryExists(targetFullName);
        if (confirmed != null) {
          await _safeUpsertRepositoryCache(confirmed, replaceFullName: fullName);
          await _safeReplaceFollowedReference(fullName, confirmed);
          return confirmed;
        }
      }
      rethrow;
    }
  }

  Future<void> deleteRepository(String fullName) async {
    try {
      await _client.delete<void>('/repos/$fullName');
    } on GitHubNotFoundException {
      // Estado final desejado já foi alcançado.
    } catch (error) {
      if (!_isAmbiguousMutationError(error) ||
          !await _confirmRepositoryMissing(fullName)) {
        rethrow;
      }
    }
    await _safeRemoveRepositoryFromCaches(fullName);
  }


}
