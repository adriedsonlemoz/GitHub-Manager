part of 'repository_git_service.dart';

mixin _RepositoryGitFileOperations on _RepositoryGitBase {
  Future<List<RepositoryContentItem>> listContents({
    required String repositoryFullName,
    required String branch,
    String path = '',
  }) async {
    final endpoint = _contentsEndpoint(repositoryFullName, path);
    final response = await _client.get<dynamic>(
      endpoint,
      queryParameters: {'ref': branch},
    );
    final raw = response.data;
    if (raw is! List) {
      return const [];
    }
    final items = raw
        .whereType<Map>()
        .map(
          (json) => RepositoryContentItem.fromJson(
            Map<String, dynamic>.from(json),
          ),
        )
        .toList();
    items.sort((a, b) {
      if (a.isDirectory != b.isDirectory) {
        return a.isDirectory ? -1 : 1;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return items;
  }

  Future<RepositoryTextFile> readTextFile({
    required String repositoryFullName,
    required String branch,
    required String path,
  }) async {
    final response = await _client.get<Map<String, dynamic>>(
      _contentsEndpoint(repositoryFullName, path),
      queryParameters: {'ref': branch},
    );
    final json = response.data ?? const <String, dynamic>{};
    final size = (json['size'] as num?)?.toInt() ?? 0;
    if (size > RepositoryGitService.maxEditableTextBytes) {
      throw const RepositoryFileException(
        'Este arquivo é grande demais para editar no celular. O limite do editor é 1 MB.',
        code: 'FILE_EDITOR_SIZE_LIMIT',
      );
    }
    if (json['encoding'] != 'base64') {
      throw const RepositoryFileException(
        'Este arquivo não pode ser aberto como texto pelo editor.',
        code: 'FILE_ENCODING_UNSUPPORTED',
      );
    }
    final encoded = (json['content'] as String? ?? '').replaceAll('\n', '');
    try {
      final bytes = base64.decode(encoded);
      final content = utf8.decode(bytes, allowMalformed: false);
      return RepositoryTextFile(
        name: json['name'] as String? ?? path.split('/').last,
        path: json['path'] as String? ?? path,
        sha: json['sha'] as String? ?? '',
        content: content,
        size: size,
      );
    } on FormatException {
      throw const RepositoryFileException(
        'O arquivo parece ser binário e não pode ser editado como texto.',
        code: 'FILE_BINARY',
      );
    }
  }

  Future<void> createTextFile({
    required String repositoryFullName,
    required String branch,
    required String path,
    required String content,
    required String message,
  }) async {
    final normalized = _normalizeRepositoryPath(path);
    await _client.put<Map<String, dynamic>>(
      _contentsEndpoint(repositoryFullName, normalized),
      data: {
        'message': message.trim().isEmpty
            ? automaticCommitMessage('Cria $normalized')
            : message.trim(),
        'content': base64.encode(utf8.encode(content)),
        'branch': branch,
      },
    );
  }

  Future<void> updateTextFile({
    required String repositoryFullName,
    required String branch,
    required RepositoryTextFile file,
    required String content,
    required String message,
  }) async {
    await _client.put<Map<String, dynamic>>(
      _contentsEndpoint(repositoryFullName, file.path),
      data: {
        'message': message.trim().isEmpty
            ? automaticCommitMessage('Atualiza ${file.path}')
            : message.trim(),
        'content': base64.encode(utf8.encode(content)),
        'sha': file.sha,
        'branch': branch,
      },
    );
  }

  Future<void> deleteItem({
    required String repositoryFullName,
    required String branch,
    required RepositoryContentItem item,
  }) async {
    if (!item.isFile) {
      throw const RepositoryFileException(
        'O GitHub não possui pastas vazias. Exclua os arquivos da pasta individualmente.',
        code: 'DIRECTORY_DELETE_UNSUPPORTED',
      );
    }
    await _client.delete<Map<String, dynamic>>(
      _contentsEndpoint(repositoryFullName, item.path),
      data: {
        'message': automaticCommitMessage('Exclui ${item.path}'),
        'sha': item.sha,
        'branch': branch,
      },
    );
  }

  Future<List<PlatformFile>> pickFiles() => FilePicker.pickFiles(
        type: FileType.any,
      );

  Future<void> uploadPickedFile({
    required String repositoryFullName,
    required String branch,
    required String directory,
    required PlatformFile pickedFile,
  }) async {
    final length = await pickedFile.length();
    if (length > RepositoryGitService.maxUploadBytes) {
      throw const RepositoryFileException(
        'Arquivos individuais acima de 95 MB não podem ser enviados por este fluxo.',
        code: 'GITHUB_FILE_SIZE_LIMIT',
      );
    }
    final bytes = await pickedFile.readAsBytes();
    final targetPath = _join(directory, pickedFile.name);
    await _client.put<Map<String, dynamic>>(
      _contentsEndpoint(repositoryFullName, targetPath),
      data: {
        'message': automaticCommitMessage('Envia $targetPath'),
        'content': base64.encode(bytes),
        'branch': branch,
      },
    );
  }

  Future<List<RepositoryBranch>> listBranches(String repositoryFullName) async {
    final branches = <RepositoryBranch>[];
    for (var page = 1; page <= 5; page++) {
      final response = await _client.get<List<dynamic>>(
        '/repos/$repositoryFullName/branches',
        queryParameters: {'per_page': 100, 'page': page},
      );
      final raw = response.data ?? const <dynamic>[];
      final pageItems = raw
          .whereType<Map>()
          .map(
            (json) => RepositoryBranch.fromJson(
              Map<String, dynamic>.from(json),
            ),
          )
          .toList(growable: false);
      branches.addAll(pageItems);
      if (pageItems.length < 100) {
        break;
      }
    }
    return branches;
  }

  Future<List<RepositoryCommit>> listCommits({
    required String repositoryFullName,
    required String branch,
  }) async {
    final response = await _client.get<List<dynamic>>(
      '/repos/$repositoryFullName/commits',
      queryParameters: {'sha': branch, 'per_page': 60},
    );
    return (response.data ?? const <dynamic>[])
        .whereType<Map>()
        .map(
          (json) => RepositoryCommit.fromJson(
            Map<String, dynamic>.from(json),
          ),
        )
        .toList(growable: false);
  }

  static String _contentsEndpoint(String fullName, String path) {
    final normalized = path.trim();
    if (normalized.isEmpty) {
      return '/repos/$fullName/contents';
    }
    final encodedPath = normalized.split('/').map(Uri.encodeComponent).join('/');
    return '/repos/$fullName/contents/$encodedPath';
  }

  static String _normalizeRepositoryPath(String raw) {
    final normalized = raw.replaceAll('\\', '/').trim();
    if (normalized.isEmpty || normalized.startsWith('/')) {
      throw const RepositoryFileException(
        'Informe um caminho relativo válido dentro do repositório.',
        code: 'REPOSITORY_PATH_INVALID',
      );
    }
    final rawParts = normalized.split('/');
    if (rawParts.any((part) => part == '..')) {
      throw const RepositoryFileException(
        'O caminho não pode sair da pasta atual usando ../.',
        code: 'REPOSITORY_PATH_TRAVERSAL',
      );
    }
    final parts = rawParts
        .where((part) => part.isNotEmpty && part != '.')
        .toList(growable: false);
    if (parts.isEmpty) {
      throw const RepositoryFileException(
        'Informe um caminho válido para o arquivo.',
        code: 'REPOSITORY_PATH_INVALID',
      );
    }
    return parts.join('/');
  }

  static String _join(String directory, String name) {
    if (directory.trim().isEmpty) {
      return _normalizeRepositoryPath(name);
    }
    return _normalizeRepositoryPath('$directory/$name');
  }
}
