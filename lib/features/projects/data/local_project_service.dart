import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:github_manager/core/errors/app_exception.dart';
import 'package:github_manager/features/projects/domain/zip_project.dart';

class LocalProjectService {
  static const maxArchiveBytes = 300 * 1024 * 1024;
  static const maxUncompressedBytes = 500 * 1024 * 1024;
  static const maxFiles = 5000;
  static const maxFileBytes = 95 * 1024 * 1024;

  Future<ZipProjectPreview?> pickAndAnalyzeZip() async {
    final selected = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
    );
    if (selected == null) {
      return null;
    }
    final path = selected.path;
    if (path == null || path.isEmpty) {
      throw const InvalidZipException(
        'Não foi possível acessar o ZIP selecionado.',
        code: 'ZIP_PATH_UNAVAILABLE',
      );
    }
    return analyzeZip(path, displayName: selected.name);
  }

  Future<ZipProjectPreview> analyzeZip(
    String path, {
    String? displayName,
  }) async {
    final source = File(path);
    if (!await source.exists()) {
      throw const InvalidZipException('O ZIP selecionado não existe mais.');
    }
    final archiveBytes = await source.length();
    if (archiveBytes <= 0 || archiveBytes > maxArchiveBytes) {
      throw const InvalidZipException(
        'O ZIP está vazio ou ultrapassa o limite local de 300 MB.',
        code: 'ZIP_SIZE_LIMIT',
      );
    }

    final input = InputFileStream(path);
    Archive archive;
    try {
      archive = ZipDecoder().decodeStream(input, verify: true);
    } catch (_) {
      input.closeSync();
      throw const InvalidZipException(
        'O arquivo não é um ZIP válido ou está corrompido.',
        code: 'ZIP_CORRUPT',
      );
    }

    var files = 0;
    var folders = 0;
    var totalBytes = 0;
    final paths = <String>[];
    final seenPaths = <String>{};
    final important = <String>[];
    String? detectedProjectName;
    String? detectedPackageName;
    String? detectedApplicationId;
    String? detectedVersion;
    int? detectedVersionCode;

    try {
      for (final entry in archive) {
        final normalized = validateArchivePath(entry.name);
        if (entry.isSymbolicLink) {
          throw const InvalidZipException(
            'ZIPs com links simbólicos não são aceitos por segurança.',
            code: 'ZIP_SYMLINK',
          );
        }
        if (entry.isDirectory) {
          folders++;
          continue;
        }
        if (!entry.isFile) {
          continue;
        }
        files++;
        if (files > maxFiles) {
          throw const InvalidZipException(
            'O ZIP ultrapassa o limite de 5.000 arquivos.',
            code: 'ZIP_FILE_COUNT',
          );
        }
        if (entry.size > maxFileBytes) {
          throw InvalidZipException(
            'O arquivo $normalized ultrapassa 95 MB e não pode ser enviado ao GitHub.',
            code: 'ZIP_FILE_TOO_LARGE',
          );
        }
        totalBytes += entry.size;
        if (totalBytes > maxUncompressedBytes) {
          throw const InvalidZipException(
            'O conteúdo descompactado ultrapassa o limite local de 500 MB.',
            code: 'ZIP_EXPANDED_SIZE',
          );
        }
        if (!seenPaths.add(normalized)) {
          throw InvalidZipException(
            'O ZIP contém o caminho duplicado $normalized.',
            code: 'ZIP_DUPLICATE_PATH',
          );
        }
        paths.add(normalized);
        if (_isImportant(normalized)) {
          important.add(normalized);
        }

        final lowerPath = normalized.toLowerCase();
        if (_isIdentityFile(lowerPath)) {
          final bytes = entry.readBytes();
          if (bytes != null && bytes.length <= 1024 * 1024) {
            final text = utf8.decode(bytes, allowMalformed: true);
            if (lowerPath.endsWith('github-manager.json') ||
                lowerPath.endsWith('app.json') ||
                lowerPath.endsWith('project.json')) {
              try {
                final raw = jsonDecode(text);
                if (raw is Map) {
                  final map = Map<String, dynamic>.from(raw);
                  detectedProjectName ??= _firstString([
                    map['displayName'],
                    map['product'],
                    map['projectName'],
                    map['appName'],
                  ]);
                  detectedPackageName ??= _firstString([map['name'], map['package']]);
                  detectedVersion ??= _firstString([map['version'], map['versionName']]);
                  final android = map['android'];
                  if (android is Map) {
                    final androidMap = Map<String, dynamic>.from(android);
                    detectedApplicationId ??=
                        _firstString([androidMap['applicationId'], androidMap['namespace']]);
                    detectedVersion ??=
                        _firstString([androidMap['versionName']]) ?? detectedVersion;
                    final code = androidMap['versionCode'];
                    if (code is num) detectedVersionCode ??= code.toInt();
                    if (code is String) detectedVersionCode ??= int.tryParse(code);
                  }
                }
              } catch (_) {
                // Metadado opcional inválido não invalida o ZIP inteiro.
              }
            } else if (lowerPath.endsWith('pubspec.yaml')) {
              detectedPackageName ??= RegExp(r'^name:\s*([^\s#]+)', multiLine: true)
                  .firstMatch(text)
                  ?.group(1)
                  ?.trim();
              final version = RegExp(r'^version:\s*([^\s#]+)', multiLine: true)
                  .firstMatch(text)
                  ?.group(1)
                  ?.trim();
              if (version?.isNotEmpty == true) {
                detectedVersion ??= version!.split('+').first;
                if (version.contains('+')) {
                  detectedVersionCode ??= int.tryParse(version.split('+').last);
                }
              }
            } else if (lowerPath.endsWith('/version') || lowerPath == 'version') {
              detectedVersion ??= text.trim().split('+').first;
            } else if (lowerPath.endsWith('build.gradle') ||
                lowerPath.endsWith('build.gradle.kts')) {
              detectedApplicationId ??= RegExp(
                r'''applicationId\s*(?:=\s*)?["']([^"']+)["']''',
              ).firstMatch(text)?.group(1)?.trim();
              detectedApplicationId ??= RegExp(
                r'''namespace\s*(?:=\s*)?["']([^"']+)["']''',
              ).firstMatch(text)?.group(1)?.trim();
            }
          }
        }
      }
    } finally {
      archive.clearSync();
      input.closeSync();
    }

    if (files == 0) {
      throw const InvalidZipException('O ZIP não contém arquivos para enviar.');
    }

    final commonRoot = _findCommonRoot(paths);
    return ZipProjectPreview(
      path: path,
      name: displayName ?? source.uri.pathSegments.last,
      archiveBytes: archiveBytes,
      uncompressedBytes: totalBytes,
      fileCount: files,
      folderCount: folders,
      projectType: _detectProjectType(paths),
      importantFiles: important.take(12).toList(growable: false),
      commonRoot: commonRoot,
      projectName: detectedProjectName,
      packageName: detectedPackageName,
      applicationId: detectedApplicationId,
      version: detectedVersion,
      versionCode: detectedVersionCode,
    );
  }

  static String validateArchivePath(String raw) {
    final normalized = raw.replaceAll('\\', '/').trim();
    if (normalized.isEmpty || normalized.contains('\u0000')) {
      throw const InvalidZipException(
        'O ZIP contém um caminho de arquivo inválido.',
        code: 'ZIP_PATH_INVALID',
      );
    }
    if (normalized.startsWith('/') ||
        RegExp(r'^[A-Za-z]:/').hasMatch(normalized)) {
      throw const InvalidZipException(
        'O ZIP contém caminho absoluto e foi bloqueado por segurança.',
        code: 'ZIP_ABSOLUTE_PATH',
      );
    }
    final parts = normalized.split('/');
    if (parts.any((part) => part == '..')) {
      throw const InvalidZipException(
        'O ZIP contém tentativa de sair da pasta temporária (../).',
        code: 'ZIP_PATH_TRAVERSAL',
      );
    }
    final safe = parts.where((part) => part.isNotEmpty && part != '.').join('/');
    if (safe.isEmpty) {
      throw const InvalidZipException(
        'O ZIP contém um caminho vazio ou inválido.',
        code: 'ZIP_PATH_INVALID',
      );
    }
    return safe;
  }

  static String? _findCommonRoot(List<String> paths) {
    if (paths.isEmpty || paths.any((path) => !path.contains('/'))) {
      return null;
    }
    final first = paths.first.split('/').first;
    if (first.isEmpty) {
      return null;
    }
    return paths.every((path) => path.split('/').first == first) ? first : null;
  }

  static bool _isIdentityFile(String lowerPath) =>
      lowerPath.endsWith('github-manager.json') ||
      lowerPath.endsWith('app.json') ||
      lowerPath.endsWith('project.json') ||
      lowerPath.endsWith('pubspec.yaml') ||
      lowerPath.endsWith('/version') ||
      lowerPath == 'version' ||
      lowerPath.endsWith('android/app/build.gradle') ||
      lowerPath.endsWith('android/app/build.gradle.kts');

  static String? _firstString(List<Object?> values) {
    for (final value in values) {
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  static bool _isImportant(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('pubspec.yaml') ||
        lower.endsWith('package.json') ||
        lower.endsWith('build.gradle') ||
        lower.endsWith('build.gradle.kts') ||
        lower.endsWith('androidmanifest.xml') ||
        lower.endsWith('readme.md') ||
        lower.contains('/.github/workflows/') ||
        lower.startsWith('.github/workflows/');
  }

  static String _detectProjectType(List<String> paths) {
    final lower = paths.map((path) => path.toLowerCase()).toList();
    if (lower.any((path) => path.endsWith('pubspec.yaml')) &&
        lower.any((path) => path.contains('lib/main.dart'))) {
      return 'Flutter';
    }
    if (lower.any((path) => path.endsWith('androidmanifest.xml')) &&
        lower.any(
          (path) => path.endsWith('build.gradle') || path.endsWith('build.gradle.kts'),
        )) {
      return 'Android';
    }
    if (lower.any((path) => path.endsWith('package.json'))) {
      return 'Node/JavaScript';
    }
    if (lower.any((path) => path.endsWith('.php'))) {
      return 'PHP';
    }
    return 'Projeto genérico';
  }
}
