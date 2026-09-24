import 'dart:convert';

import 'package:github_manager/core/errors/app_exception.dart';
import 'package:github_manager/core/network/github_api_client.dart';
import 'package:github_manager/features/repositories/domain/github_repository.dart';
import 'package:github_manager/features/repositories/domain/repository_project_info.dart';

class RepositoryProjectInfoService {
  RepositoryProjectInfoService(this._client);

  final GitHubApiClient _client;

  Future<RepositoryProjectInfo> loadSummary(
    GitHubRepository repository, {
    String? branch,
  }) async {
    final resolvedBranch = branch?.trim().isNotEmpty == true
        ? branch!.trim()
        : repository.defaultBranch;
    try {
      final rootResponse = await _client.get<List<dynamic>>(
        '/repos/${repository.fullName}/contents',
        queryParameters: {'ref': resolvedBranch},
      );
      final root = (rootResponse.data ?? const <dynamic>[])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
      final names = <String, Map<String, dynamic>>{
        for (final item in root)
          (item['name'] as String? ?? '').toLowerCase(): item,
      };

      Future<String?> readPath(String path) async {
        try {
          final response = await _client.get<Map<String, dynamic>>(
            '/repos/${repository.fullName}/contents/${path.split('/').map(Uri.encodeComponent).join('/')}',
            queryParameters: {'ref': resolvedBranch},
          );
          final json = response.data ?? const <String, dynamic>{};
          if (json['encoding'] != 'base64') return null;
          final encoded = (json['content'] as String? ?? '').replaceAll('\n', '');
          if (encoded.isEmpty) return null;
          return utf8.decode(base64.decode(encoded), allowMalformed: true);
        } catch (_) {
          return null;
        }
      }

      var projectName = repository.name;
      String? version;
      String? versionSource;

      final metadataFile = const [
        'github-manager.json',
        'app_identity.json',
        'app.json',
        'project.json',
        'manifest.json',
      ].where(names.containsKey).firstOrNull;
      if (metadataFile != null) {
        final raw = await readPath(metadataFile);
        if (raw != null) {
          try {
            final decoded = jsonDecode(raw);
            if (decoded is Map) {
              final map = Map<String, dynamic>.from(decoded);
              final candidateName = map['displayName'] ??
                  map['product'] ??
                  map['projectName'] ??
                  map['appName'] ??
                  map['name'];
              final candidateVersion = _versionFromJsonMap(map);
              final android = map['android'];
              if (candidateName is String && candidateName.trim().isNotEmpty) {
                projectName = candidateName.trim();
              }
              if (candidateVersion is String && candidateVersion.trim().isNotEmpty) {
                version = candidateVersion.trim().split('+').first;
                versionSource = metadataFile;
              }
              if (version == null && android is Map) {
                final androidVersion = android['versionName'];
                if (androidVersion is String && androidVersion.trim().isNotEmpty) {
                  version = androidVersion.trim().split('+').first;
                  versionSource = metadataFile;
                }
              }
            }
          } catch (_) {
            _ignoreInvalidMetadata();
          }
        }
      }

      if (version == null && names.containsKey('pubspec.yaml')) {
        final raw = await readPath('pubspec.yaml');
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
          if (yamlVersion?.isNotEmpty == true) {
            version = yamlVersion!.split('+').first;
            versionSource = 'pubspec.yaml';
          }
        }
      }

      if (version == null && names.containsKey('project.godot')) {
        final raw = await readPath('project.godot');
        if (raw != null) {
          final godotName = RegExp(r'^config/name\s*=\s*"([^"]+)"', multiLine: true)
              .firstMatch(raw)?.group(1)?.trim();
          final godotVersion = RegExp(r'^config/version\s*=\s*"([^"]+)"', multiLine: true)
              .firstMatch(raw)?.group(1)?.trim();
          if (projectName == repository.name && godotName?.isNotEmpty == true) {
            projectName = godotName!;
          }
          if (godotVersion?.isNotEmpty == true) {
            version = godotVersion;
            versionSource = 'project.godot';
          }
        }
      }

      if (version == null && names.containsKey('pyproject.toml')) {
        final raw = await readPath('pyproject.toml');
        if (raw != null) {
          version = RegExp(r'''^version\s*=\s*["']([^"']+)["']''', multiLine: true)
              .firstMatch(raw)?.group(1)?.trim();
          if (version?.isNotEmpty == true) versionSource = 'pyproject.toml';
        }
      }

      if (version == null && names.containsKey('cargo.toml')) {
        final raw = await readPath('Cargo.toml');
        if (raw != null) {
          version = RegExp(r'''^version\s*=\s*["']([^"']+)["']''', multiLine: true)
              .firstMatch(raw)?.group(1)?.trim();
          if (version?.isNotEmpty == true) versionSource = 'Cargo.toml';
        }
      }

      if (version == null && names.containsKey('package.json')) {
        final raw = await readPath('package.json');
        if (raw != null) {
          try {
            final decoded = jsonDecode(raw);
            if (decoded is Map) {
              final map = Map<String, dynamic>.from(decoded);
              final candidateName = map['name'];
              final candidateVersion = map['version'];
              if (projectName == repository.name && candidateName is String) {
                projectName = _humanize(candidateName);
              }
              if (candidateVersion is String && candidateVersion.trim().isNotEmpty) {
                version = candidateVersion.trim();
                versionSource = 'package.json';
              }
            }
          } catch (_) {
            _ignoreInvalidMetadata();
          }
        }
      }

      if (version == null && names.containsKey('version')) {
        final raw = await readPath('VERSION');
        if (raw?.trim().isNotEmpty == true) {
          version = raw!.trim();
          versionSource = 'VERSION';
        }
      }

      if (version == null && names.containsKey('manager.sh')) {
        final raw = await readPath('manager.sh');
        if (raw != null) {
          version = _versionFromShellScript(raw);
          if (version != null) versionSource = 'manager.sh';
        }
      }

      if (version == null) {
        final gradleCandidates = <String>[
          if (names.containsKey('app')) ...const [
            'app/build.gradle.kts',
            'app/build.gradle',
          ],
          if (names.containsKey('android')) ...const [
            'android/app/build.gradle.kts',
            'android/app/build.gradle',
          ],
        ];
        for (final gradlePath in gradleCandidates) {
          final raw = await readPath(gradlePath);
          if (raw == null) continue;
          version = RegExp(
            r'''versionName\s*(?:=\s*)?["']([^"']+)["']''',
          ).firstMatch(raw)?.group(1)?.trim();
          if (version?.isNotEmpty == true) {
            versionSource = gradlePath;
            break;
          }
        }
      }

      return RepositoryProjectInfo(
        projectName: projectName,
        version: version,
        versionSource: versionSource,
        technologies: [if (repository.language?.isNotEmpty == true) repository.language!],
      );
    } on AppException {
      return RepositoryProjectInfo(
        projectName: repository.name,
        version: null,
        technologies: [if (repository.language?.isNotEmpty == true) repository.language!],
      );
    }
  }

  Future<RepositoryProjectInfo> load(
    GitHubRepository repository, {
    String? branch,
  }) async {
    final resolvedBranch = branch?.trim().isNotEmpty == true
        ? branch!.trim()
        : repository.defaultBranch;
    try {
      final rootResponse = await _client.get<List<dynamic>>(
        '/repos/${repository.fullName}/contents',
        queryParameters: {'ref': resolvedBranch},
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
      String? versionSource;
      String? packageName;
      String? applicationId;
      int? versionCode;
      final metadataTechnologies = <String>[];

      Future<String?> readRoot(String name) async {
        final item = names[name.toLowerCase()];
        if (item == null || item['type'] != 'file') {
          return null;
        }
        final path = item['path'] as String? ?? name;
        final response = await _client.get<Map<String, dynamic>>(
          '/repos/${repository.fullName}/contents/${Uri.encodeComponent(path)}',
          queryParameters: {'ref': resolvedBranch},
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
        'app_identity.json',
        'app.json',
        'project.json',
        'manifest.json',
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
              final candidateVersion = _versionFromJsonMap(map);
              final candidatePackage = map['name'] ?? map['package'];
              final android = map['android'];
              if (candidateName is String && candidateName.trim().isNotEmpty) {
                projectName = candidateName.trim();
              }
              if (candidateVersion?.isNotEmpty == true) {
                version = candidateVersion;
                versionSource = metadataFile;
              }
              if (candidatePackage is String && candidatePackage.trim().isNotEmpty) {
                packageName = candidatePackage.trim();
              }
              if (android is Map) {
                final androidMap = Map<String, dynamic>.from(android);
                final id = androidMap['applicationId'] ?? androidMap['namespace'];
                if (id is String && id.trim().isNotEmpty) {
                  applicationId = id.trim();
                }
                final code = androidMap['versionCode'];
                if (code is num) versionCode = code.toInt();
                if (code is String) versionCode = int.tryParse(code);
                final androidVersion = androidMap['versionName'];
                if (androidVersion is String && androidVersion.trim().isNotEmpty) {
                  version = androidVersion.trim().split('+').first;
                  versionSource = metadataFile;
                }
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
          packageName ??= yamlName;
          if (yamlVersion?.isNotEmpty == true) {
            final resolvedVersion = yamlVersion!;
            if (version == null) {
              version = resolvedVersion.split('+').first;
              versionSource = 'pubspec.yaml';
            }
            if (resolvedVersion.contains('+')) {
              versionCode ??=
                  int.tryParse(resolvedVersion.split('+').last);
            }
          }
        }
      }

      if (version == null && names.containsKey('project.godot')) {
        final raw = await readRoot('project.godot');
        if (raw != null) {
          final godotName = RegExp(r'^config/name\s*=\s*"([^"]+)"', multiLine: true)
              .firstMatch(raw)?.group(1)?.trim();
          final godotVersion = RegExp(r'^config/version\s*=\s*"([^"]+)"', multiLine: true)
              .firstMatch(raw)?.group(1)?.trim();
          if (projectName == repository.name && godotName?.isNotEmpty == true) {
            projectName = godotName!;
          }
          if (godotVersion?.isNotEmpty == true) {
            version = godotVersion;
            versionSource = 'project.godot';
          }
        }
      }

      if (version == null && names.containsKey('pyproject.toml')) {
        final raw = await readRoot('pyproject.toml');
        if (raw != null) {
          version = RegExp(r'''^version\s*=\s*["']([^"']+)["']''', multiLine: true)
              .firstMatch(raw)?.group(1)?.trim();
          if (version?.isNotEmpty == true) versionSource = 'pyproject.toml';
        }
      }

      if (version == null && names.containsKey('cargo.toml')) {
        final raw = await readRoot('Cargo.toml');
        if (raw != null) {
          version = RegExp(r'''^version\s*=\s*["']([^"']+)["']''', multiLine: true)
              .firstMatch(raw)?.group(1)?.trim();
          if (version?.isNotEmpty == true) versionSource = 'Cargo.toml';
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
                versionSource = 'package.json';
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
          versionSource = 'VERSION';
        }
      }

      if (version == null && names.containsKey('manager.sh')) {
        final raw = await readRoot('manager.sh');
        if (raw != null) {
          version = _versionFromShellScript(raw);
          if (version != null) versionSource = 'manager.sh';
        }
      }

      // Android nativo mantém o módulo em app/, enquanto Flutter usa android/app/.
      // O Gradle do módulo é a fonte mais confiável para applicationId e versão.
      final gradleCandidates = <String>[
        if (names.containsKey('app')) ...const [
          'app/build.gradle.kts',
          'app/build.gradle',
        ],
        if (names.containsKey('android')) ...const [
          'android/app/build.gradle.kts',
          'android/app/build.gradle',
        ],
      ];
      if (applicationId == null || version == null || versionCode == null) {
        for (final gradlePath in gradleCandidates) {
          try {
            final response = await _client.get<Map<String, dynamic>>(
              '/repos/${repository.fullName}/contents/${gradlePath.split('/').map(Uri.encodeComponent).join('/')}',
              queryParameters: {'ref': resolvedBranch},
            );
            final json = response.data ?? const <String, dynamic>{};
            if (json['encoding'] != 'base64') continue;
            final encoded = (json['content'] as String? ?? '').replaceAll('\n', '');
            if (encoded.isEmpty) continue;
            final raw = utf8.decode(base64.decode(encoded), allowMalformed: true);
            applicationId ??= RegExp(
              r'''applicationId\s*(?:=\s*)?["']([^"']+)["']''',
            ).firstMatch(raw)?.group(1)?.trim();
            applicationId ??= RegExp(
              r'''namespace\s*(?:=\s*)?["']([^"']+)["']''',
            ).firstMatch(raw)?.group(1)?.trim();
            if (version == null) {
              version = RegExp(
                r'''versionName\s*(?:=\s*)?["']([^"']+)["']''',
              ).firstMatch(raw)?.group(1)?.trim();
              if (version != null) versionSource = gradlePath;
            }
            versionCode ??= int.tryParse(
              RegExp(r'''versionCode\s*(?:=\s*)?(\d+)''')
                      .firstMatch(raw)
                      ?.group(1) ??
                  '',
            );
            if (applicationId != null && version != null && versionCode != null) {
              break;
            }
          } catch (_) {
            // Gradle opcional/indisponível: a verificação continua com as demais pistas.
          }
        }
      }

      final technologies = <String>[...metadataTechnologies];
      if (names.containsKey('pubspec.yaml')) {
        technologies.add('Flutter');
      }
      if (gradleCandidates.isNotEmpty || names.containsKey('android')) {
        technologies.add('Android');
      }
      if (names.containsKey('project.godot')) {
        technologies.add('Godot');
      }
      if (names.containsKey('pyproject.toml')) {
        technologies.add('Python');
      }
      if (names.containsKey('cargo.toml')) {
        technologies.add('Rust');
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
        packageName: packageName,
        applicationId: applicationId,
        versionCode: versionCode,
        versionSource: versionSource,
      );
    } on AppException {
      return RepositoryProjectInfo(
        projectName: repository.name,
        version: null,
        technologies: [if (repository.language != null) repository.language!],
      );
    }
  }

  static String? _versionFromJsonMap(Map<String, dynamic> map) {
    for (final candidate in [
      map['version'],
      map['versionName'],
      map['appVersion'],
    ]) {
      if (candidate is String && candidate.trim().isNotEmpty) {
        return candidate.trim().split('+').first;
      }
    }
    for (final key in const ['release', 'app', 'project', 'metadata']) {
      final nested = map[key];
      if (nested is! Map) continue;
      final nestedMap = Map<String, dynamic>.from(nested);
      for (final candidate in [
        nestedMap['version'],
        nestedMap['versionName'],
        nestedMap['appVersion'],
      ]) {
        if (candidate is String && candidate.trim().isNotEmpty) {
          return candidate.trim().split('+').first;
        }
      }
    }
    return null;
  }

  static String? _versionFromShellScript(String text) {
    return RegExp(
      r'''^(?:(?:export|readonly)\s+)?[A-Z0-9_]*VERSION\s*=\s*["']?v?([0-9]+(?:\.[0-9]+){1,3}(?:[-+][A-Za-z0-9._-]+)?)["']?\s*(?:#.*)?$''',
      multiLine: true,
      caseSensitive: false,
    ).firstMatch(text)?.group(1)?.trim();
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
