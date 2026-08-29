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

  String _gitRefPath(String branch) => branch
      .split('/')
      .map(Uri.encodeComponent)
      .join('/');

  Future<_RepositoryBranchSnapshot?> _loadBranchSnapshot({
    required String repositoryFullName,
    required String branch,
  }) async {
    try {
      final ref = await _client.get<Map<String, dynamic>>(
        '/repos/$repositoryFullName/git/ref/heads/${_gitRefPath(branch)}',
      );
      final object = ref.data?['object'];
      final commitSha = object is Map ? object['sha']?.toString() : null;
      if (commitSha?.isNotEmpty != true) return null;

      final commit = await _client.get<Map<String, dynamic>>(
        '/repos/$repositoryFullName/git/commits/$commitSha',
      );
      final treeRaw = commit.data?['tree'];
      final treeSha = treeRaw is Map ? treeRaw['sha']?.toString() : null;
      if (treeSha?.isNotEmpty != true) return null;

      final tree = await _client.get<Map<String, dynamic>>(
        '/repos/$repositoryFullName/git/trees/$treeSha',
        queryParameters: const {'recursive': '1'},
      );
      if (tree.data?['truncated'] == true) {
        throw const RepositoryFileException(
          'O repositório é grande demais para uma limpeza segura em um único commit.',
          code: 'REPOSITORY_CLEAR_TREE_TRUNCATED',
        );
      }

      final entries = (tree.data?['tree'] as List? ?? const <dynamic>[])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .where((item) => item['type'] != 'tree')
          .toList(growable: false);

      return _RepositoryBranchSnapshot(
        commitSha: commitSha!,
        treeSha: treeSha!,
        entries: entries,
      );
    } on GitHubNotFoundException {
      return null;
    }
  }

  Future<int> countRepositoryFiles({
    required String repositoryFullName,
    required String branch,
  }) async {
    final snapshot = await _loadBranchSnapshot(
      repositoryFullName: repositoryFullName,
      branch: branch,
    );
    return snapshot?.entries.length ?? 0;
  }

  Future<int> clearRepositoryFiles({
    required String repositoryFullName,
    required String branch,
  }) async {
    final snapshot = await _loadBranchSnapshot(
      repositoryFullName: repositoryFullName,
      branch: branch,
    );
    if (snapshot == null || snapshot.entries.isEmpty) return 0;

    try {
      final deletionTree = snapshot.entries
          .map(
            (entry) => {
              'path': entry['path'],
              'mode': entry['mode'],
              'type': entry['type'],
              'sha': null,
            },
          )
          .toList(growable: false);

      final treeResponse = await _client.post<Map<String, dynamic>>(
        '/repos/$repositoryFullName/git/trees',
        data: {
          'base_tree': snapshot.treeSha,
          'tree': deletionTree,
        },
      );
      final newTreeSha = treeResponse.data?['sha']?.toString();
      if (newTreeSha?.isNotEmpty != true) {
        throw const RepositoryFileException(
          'O GitHub não retornou a árvore da limpeza.',
          code: 'REPOSITORY_CLEAR_TREE_MISSING',
        );
      }

      final commitResponse = await _client.post<Map<String, dynamic>>(
        '/repos/$repositoryFullName/git/commits',
        data: {
          'message': automaticCommitMessage('Limpa arquivos do repositório'),
          'tree': newTreeSha,
          'parents': [snapshot.commitSha],
        },
      );
      final newCommitSha = commitResponse.data?['sha']?.toString();
      if (newCommitSha?.isNotEmpty != true) {
        throw const RepositoryFileException(
          'O GitHub não retornou o commit da limpeza.',
          code: 'REPOSITORY_CLEAR_COMMIT_MISSING',
        );
      }

      await _client.patch<Map<String, dynamic>>(
        '/repos/$repositoryFullName/git/refs/heads/${_gitRefPath(branch)}',
        data: {'sha': newCommitSha, 'force': false},
      );
      return snapshot.entries.length;
    } on GitHubPermissionException {
      throw const RepositoryFileException(
        'O GitHub bloqueou a limpeza. Verifique Contents: write e as regras/proteções da branch.',
        code: 'REPOSITORY_CLEAR_PERMISSION',
      );
    } on GitHubValidationException {
      throw const RepositoryFileException(
        'A branch não aceitou o commit de limpeza. Verifique proteção de branch ou rulesets.',
        code: 'REPOSITORY_CLEAR_RULESET',
      );
    } on GitHubConflictException {
      throw const RepositoryFileException(
        'A branch mudou durante a limpeza. Atualize os arquivos e tente novamente.',
        code: 'REPOSITORY_CLEAR_CONFLICT',
      );
    }
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

class _RepositoryBranchSnapshot {
  const _RepositoryBranchSnapshot({
    required this.commitSha,
    required this.treeSha,
    required this.entries,
  });

  final String commitSha;
  final String treeSha;
  final List<Map<String, dynamic>> entries;
}
