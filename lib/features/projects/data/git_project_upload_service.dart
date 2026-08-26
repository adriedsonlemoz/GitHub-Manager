import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:github_manager/core/errors/app_exception.dart';
import 'package:github_manager/core/network/github_api_client.dart';
import 'package:github_manager/core/utils/commit_message.dart';
import 'package:github_manager/features/projects/data/local_project_service.dart';
import 'package:github_manager/features/projects/domain/zip_project.dart';

class GitProjectUploadService {
  GitProjectUploadService(this._client);

  static const _maxInlineFileBytes = 128 * 1024;
  static const _maxInlineTreeBytes = 4 * 1024 * 1024;

  final GitHubApiClient _client;

  Future<ProjectUploadResult> uploadZip({
    required ZipProjectPreview project,
    required String repositoryFullName,
    required String branch,
    required String commitMessage,
    void Function(ProjectUploadProgress progress)? onProgress,
  }) async {
    onProgress?.call(const ProjectUploadProgress(phase: 'Preparando branch'));
    Map<String, dynamic> refData;
    try {
      final refResponse = await _client.get<Map<String, dynamic>>(
        '/repos/$repositoryFullName/git/ref/heads/$branch',
      );
      refData = refResponse.data ?? const {};
    } on GitHubNotFoundException {
      await _client.put<Map<String, dynamic>>(
        '/repos/$repositoryFullName/contents/.gitkeep',
        data: {
          'message': automaticCommitMessage('Inicializa repositório'),
          'content': '',
        },
      );
      await Future<void>.delayed(const Duration(seconds: 1));
      final refResponse = await _client.get<Map<String, dynamic>>(
        '/repos/$repositoryFullName/git/ref/heads/$branch',
      );
      refData = refResponse.data ?? const {};
    }

    final object = refData['object'];
    if (object is! Map || object['sha'] is! String) {
      throw const UnexpectedAppException('REF_SHA_MISSING');
    }
    final parentCommitSha = object['sha'] as String;

    final commitResponse = await _client.get<Map<String, dynamic>>(
      '/repos/$repositoryFullName/git/commits/$parentCommitSha',
    );
    final commit = commitResponse.data ?? const {};
    final tree = commit['tree'];
    if (tree is! Map || tree['sha'] is! String) {
      throw const UnexpectedAppException('BASE_TREE_SHA_MISSING');
    }
    final baseTreeSha = tree['sha'] as String;

    final currentTreeResponse = await _client.get<Map<String, dynamic>>(
      '/repos/$repositoryFullName/git/trees/$baseTreeSha',
      queryParameters: const {'recursive': '1'},
    );
    final currentTreeData = currentTreeResponse.data ?? const <String, dynamic>{};
    if (currentTreeData['truncated'] == true) {
      throw const UnexpectedAppException('BASE_TREE_TRUNCATED');
    }
    final currentTree = currentTreeData['tree'];
    final existingEntries = <String, ({String mode, String type})>{};
    if (currentTree is List) {
      for (final raw in currentTree.whereType<Map>()) {
        final path = raw['path'];
        final mode = raw['mode'];
        final type = raw['type'];
        if (path is String &&
            mode is String &&
            type is String &&
            (type == 'blob' || type == 'commit')) {
          existingEntries[path] = (mode: mode, type: type);
        }
      }
    }

    final input = InputFileStream(project.path);
    final archive = ZipDecoder().decodeStream(input, verify: true);
    final treeEntries = <Map<String, dynamic>>[];
    final newPaths = <String>{};
    var inlineBytes = 0;
    var processed = 0;

    try {
      for (final entry in archive) {
        if (!entry.isFile || entry.isSymbolicLink) {
          continue;
        }
        final validated = LocalProjectService.validateArchivePath(entry.name);
        final gitPath = _stripCommonRoot(validated, project.commonRoot);
        if (gitPath.isEmpty) {
          continue;
        }
        newPaths.add(gitPath);

        final bytes = entry.readBytes();
        if (bytes == null) {
          throw InvalidZipException(
            'Não foi possível ler $gitPath dentro do ZIP.',
            code: 'ZIP_ENTRY_READ_FAILED',
          );
        }
        final mode = _gitMode(entry.mode);
        final text = _tryDecodeText(bytes);
        final canInline = text != null &&
            bytes.length <= _maxInlineFileBytes &&
            inlineBytes + bytes.length <= _maxInlineTreeBytes;

        if (canInline) {
          treeEntries.add({
            'path': gitPath,
            'mode': mode,
            'type': 'blob',
            'content': text,
          });
          inlineBytes += bytes.length;
        } else {
          onProgress?.call(
            ProjectUploadProgress(
              phase: 'Enviando arquivos',
              current: processed,
              total: project.fileCount,
              fileName: gitPath,
            ),
          );
          final blobResponse = await _client.post<Map<String, dynamic>>(
            '/repos/$repositoryFullName/git/blobs',
            data: {
              'content': base64Encode(bytes),
              'encoding': 'base64',
            },
          );
          final sha = blobResponse.data?['sha'] as String?;
          if (sha == null || sha.isEmpty) {
            throw const UnexpectedAppException('BLOB_SHA_MISSING');
          }
          treeEntries.add({
            'path': gitPath,
            'mode': mode,
            'type': 'blob',
            'sha': sha,
          });
          await Future<void>.delayed(const Duration(seconds: 1));
        }
        processed++;
        onProgress?.call(
          ProjectUploadProgress(
            phase: 'Preparando commit',
            current: processed,
            total: project.fileCount,
            fileName: gitPath,
          ),
        );
      }
    } finally {
      archive.clearSync();
      input.closeSync();
    }

    final stalePaths = existingEntries.keys.where((path) => !newPaths.contains(path)).toList()
      ..sort();
    for (final stalePath in stalePaths) {
      final existing = existingEntries[stalePath]!;
      treeEntries.add({
        'path': stalePath,
        'mode': existing.mode,
        'type': existing.type,
        'sha': null,
      });
    }

    onProgress?.call(
      ProjectUploadProgress(
        phase: stalePaths.isEmpty ? 'Criando árvore Git' : 'Removendo arquivos antigos',
        current: processed,
        total: project.fileCount,
      ),
    );
    final treeResponse = await _client.post<Map<String, dynamic>>(
      '/repos/$repositoryFullName/git/trees',
      data: {
        'base_tree': baseTreeSha,
        'tree': treeEntries,
      },
    );
    final newTreeSha = treeResponse.data?['sha'] as String?;
    if (newTreeSha == null) {
      throw const UnexpectedAppException('TREE_SHA_MISSING');
    }

    await Future<void>.delayed(const Duration(seconds: 1));
    onProgress?.call(const ProjectUploadProgress(phase: 'Criando commit'));
    final newCommitResponse = await _client.post<Map<String, dynamic>>(
      '/repos/$repositoryFullName/git/commits',
      data: {
        'message': commitMessage.trim().isEmpty
            ? automaticCommitMessage('Atualização')
            : commitMessage.trim(),
        'tree': newTreeSha,
        'parents': [parentCommitSha],
      },
    );
    final newCommitSha = newCommitResponse.data?['sha'] as String?;
    if (newCommitSha == null) {
      throw const UnexpectedAppException('COMMIT_SHA_MISSING');
    }

    await Future<void>.delayed(const Duration(seconds: 1));
    onProgress?.call(const ProjectUploadProgress(phase: 'Atualizando branch'));
    await _client.patch<Map<String, dynamic>>(
      '/repos/$repositoryFullName/git/refs/heads/$branch',
      data: {'sha': newCommitSha, 'force': false},
    );

    onProgress?.call(
      ProjectUploadProgress(
        phase: 'Concluído',
        current: project.fileCount,
        total: project.fileCount,
      ),
    );
    return ProjectUploadResult(
      commitSha: newCommitSha,
      fileCount: project.fileCount,
    );
  }

  static String _stripCommonRoot(String path, String? root) {
    if (root == null || root.isEmpty) {
      return path;
    }
    final prefix = '$root/';
    return path.startsWith(prefix) ? path.substring(prefix.length) : path;
  }

  static String _gitMode(int mode) {
    final executable = mode & 0x49 != 0;
    return executable ? '100755' : '100644';
  }

  static String? _tryDecodeText(List<int> bytes) {
    if (bytes.contains(0)) {
      return null;
    }
    try {
      return utf8.decode(bytes, allowMalformed: false);
    } on FormatException {
      return null;
    }
  }
}
