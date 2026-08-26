import 'dart:convert';

import 'package:github_manager/core/errors/app_exception.dart';
import 'package:github_manager/core/network/github_api_client.dart';
import 'package:github_manager/features/repositories/domain/github_repository.dart';
import 'package:github_manager/features/repositories/domain/repository_project_info.dart';

class RepositoryProjectInfoService {
  RepositoryProjectInfoService(this._client);

  final GitHubApiClient _client;

  Future<RepositoryProjectInfo> load(GitHubRepository repository) async {
    try {
      final rootResponse = await _client.get<List<dynamic>>(
        '/repos/${repository.fullName}/contents',
        queryParameters: {'ref': repository.defaultBranch},
      );
      final root = (rootResponse.data ?? const <dynamic>[])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
      final names = <String, Map<String, dynamic>>{
        for (final item in root)
          (item['name'] as String? ?? '').toLowerCase(): item,
      };

      final languagesFuture = _client.get<Map<String, dynamic>>(
        '/repos/${repository.fullName}/languages',
      );

      String projectName = repository.name;
      String? version;
      final metadataTechnologies = <String>[];

      Future<String?> readRoot(String name) async {
        final item = names[name.toLowerCase()];
        if (item == null || item['type'] != 'file') {
          return null;
        }
        final path = item['path'] as String? ?? name;
        final response = await _client.get<Map<String, dynamic>>(
          '/repos/${repository.fullName}/contents/${Uri.encodeComponent(path)}',
          queryParameters: {'ref': repository.defaultBranch},
        );
        final json = response.data ?? const <String, dynamic>{};
        if (json['encoding'] != 'base64') {
          return null;
        }
        final encoded = (json['content'] as String? ?? '').replaceAll('\n', '');
        if (encoded.isEmpty) {
          return null;
        }
        return utf8.decode(base64.decode(encoded), allowMalformed: true);
      }

      final metadataFile = const [
        'github-manager.json',
        'app.json',
        'project.json',
      ].where(names.containsKey).firstOrNull;
      if (metadataFile != null) {
        final raw = await readRoot(metadataFile);
        if (raw != null) {
          try {
            final json = jsonDecode(raw);
            if (json is Map) {
              final map = Map<String, dynamic>.from(json);
              final candidateName = map['displayName'] ??
                  map['product'] ??
                  map['projectName'] ??
                  map['appName'] ??
                  map['name'];
              final candidateVersion = map['version'] ?? map['versionName'];
              if (candidateName is String && candidateName.trim().isNotEmpty) {
                projectName = candidateName.trim();
              }
              if (candidateVersion is String &&
                  candidateVersion.trim().isNotEmpty) {
                version = candidateVersion.trim();
              }
              for (final candidate in [
                map['framework'],
                map['language'],
                map['projectType'],
              ]) {
                if (candidate is String && candidate.trim().isNotEmpty) {
                  final technology = _humanize(candidate.trim());
                  if (!metadataTechnologies.contains(technology)) {
                    metadataTechnologies.add(technology);
                  }
                }
              }
            }
          } catch (_) {
            _ignoreInvalidMetadata();
          }
        }
      }

      if (names.containsKey('pubspec.yaml')) {
        final raw = await readRoot('pubspec.yaml');
        if (raw != null) {
          final yamlName = RegExp(r'^name:\s*([^\s#]+)', multiLine: true)
              .firstMatch(raw)
              ?.group(1)
              ?.trim();
          final yamlVersion = RegExp(r'^version:\s*([^\s#]+)', multiLine: true)
              .firstMatch(raw)
              ?.group(1)
              ?.trim();
          if (projectName == repository.name && yamlName?.isNotEmpty == true) {
            projectName = _humanize(yamlName!);
          }
          version ??= yamlVersion;
        }
      }

      if (names.containsKey('package.json')) {
        final raw = await readRoot('package.json');
        if (raw != null) {
          try {
            final json = jsonDecode(raw);
            if (json is Map) {
              final map = Map<String, dynamic>.from(json);
              final candidateName = map['name'];
              final candidateVersion = map['version'];
              if (projectName == repository.name && candidateName is String) {
                projectName = _humanize(candidateName);
              }
              if (version == null && candidateVersion is String) {
                version = candidateVersion.trim();
              }
            }
          } catch (_) {
            _ignoreInvalidMetadata();
          }
        }
      }

      if (version == null && names.containsKey('version')) {
        final raw = await readRoot('VERSION');
        if (raw?.trim().isNotEmpty == true) {
          version = raw!.trim();
        }
      }

      final technologies = <String>[...metadataTechnologies];
      if (names.containsKey('pubspec.yaml')) {
        technologies.add('Flutter');
      }
      if (names.containsKey('android')) {
        technologies.add('Android');
      }
      if (names.containsKey('package.json')) {
        technologies.add('Node.js');
      }
      if (names.containsKey('composer.json')) {
        technologies.add('PHP');
      }

      try {
        final languageResponse = await languagesFuture;
        final languageMap = languageResponse.data ?? const <String, dynamic>{};
        for (final language in languageMap.keys) {
          if (!technologies.any((item) => item.toLowerCase() == language.toLowerCase())) {
            technologies.add(language);
          }
          if (technologies.length >= 8) {
            break;
          }
        }
      } catch (_) {
        if (repository.language != null && repository.language!.isNotEmpty) {
          technologies.add(repository.language!);
        }
      }

      return RepositoryProjectInfo(
        projectName: projectName,
        version: version,
        technologies: technologies.take(8).toList(growable: false),
      );
    } on AppException {
      return RepositoryProjectInfo(
        projectName: repository.name,
        version: null,
        technologies: [if (repository.language != null) repository.language!],
      );
    }
  }

  static void _ignoreInvalidMetadata() {
    return;
  }

  static String _humanize(String raw) => raw
      .replaceAll(RegExp(r'[-_]+'), ' ')
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
