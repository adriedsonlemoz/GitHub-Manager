import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:github_manager/core/errors/app_exception.dart';
import 'package:github_manager/core/network/github_api_client.dart';
import 'package:github_manager/core/utils/commit_message.dart';
import 'package:github_manager/features/repositories/domain/repository_git_models.dart';
import 'package:github_manager/features/repositories/domain/workflow_definition_inspector.dart';

class RepositoryGitService {
  RepositoryGitService(this._client);

  static const maxEditableTextBytes = 1024 * 1024;
  static const maxUploadBytes = 95 * 1024 * 1024;

  final GitHubApiClient _client;
  final Map<String, String?> _runVersionCache = <String, String?>{};

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
    if (size > maxEditableTextBytes) {
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
    if (length > maxUploadBytes) {
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

  Future<List<RepositoryWorkflow>> listWorkflows(
    String repositoryFullName,
  ) async {
    final workflows = <RepositoryWorkflow>[];
    for (var page = 1; page <= 5; page++) {
      final response = await _client.get<Map<String, dynamic>>(
        '/repos/$repositoryFullName/actions/workflows',
        queryParameters: {'per_page': 100, 'page': page},
      );
      final raw = response.data?['workflows'];
      if (raw is! List) {
        throw const RepositoryFileException(
          'O GitHub retornou uma resposta inesperada ao listar workflows.',
          code: 'ACTIONS_WORKFLOWS_RESPONSE_INVALID',
        );
      }
      final pageItems = raw
          .whereType<Map>()
          .map(
            (json) => RepositoryWorkflow.fromJson(
              Map<String, dynamic>.from(json),
            ),
          )
          .toList(growable: false);
      workflows.addAll(pageItems);
      if (pageItems.length < 100) {
        break;
      }
    }
    workflows.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return workflows;
  }

  Future<bool> workflowSupportsDispatch({
    required String repositoryFullName,
    required String branch,
    required RepositoryWorkflow workflow,
  }) async {
    final candidates = <String>{
      if (workflow.path.trim().isNotEmpty)
        workflow.path.trim().replaceFirst(RegExp(r'^/+'), ''),
      if (workflow.fileName.trim().isNotEmpty)
        '.github/workflows/${workflow.fileName.trim()}',
    };
    for (final path in candidates) {
      try {
        final file = await readTextFile(
          repositoryFullName: repositoryFullName,
          branch: branch,
          path: path,
        );
        if (WorkflowDefinitionInspector.inspect(file.content).supportsDispatch) {
          return true;
        }
      } catch (_) {
        // Tenta a próxima forma de localizar o mesmo workflow.
      }
    }
    return false;
  }

  Future<int?> dispatchWorkflow({
    required String repositoryFullName,
    required RepositoryWorkflow workflow,
    required String ref,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/repos/$repositoryFullName/actions/workflows/${workflow.id}/dispatches',
      data: {'ref': ref},
    );
    return (response.data?['workflow_run_id'] as num?)?.toInt();
  }

  Future<int?> dispatchWorkflowFile({
    required String repositoryFullName,
    required String workflowFileName,
    required String ref,
  }) async {
    final fileName = workflowFileName.trim();
    if (fileName.isEmpty) {
      throw const RepositoryFileException(
        'Informe o arquivo do workflow que será executado.',
        code: 'WORKFLOW_FILE_REQUIRED',
      );
    }
    final response = await _client.post<Map<String, dynamic>>(
      '/repos/$repositoryFullName/actions/workflows/${Uri.encodeComponent(fileName)}/dispatches',
      data: {'ref': ref},
    );
    return (response.data?['workflow_run_id'] as num?)?.toInt();
  }

  Future<List<RepositoryWorkflowRun>> listWorkflowRunsForCommit({
    required String repositoryFullName,
    required String commitSha,
  }) async {
    final normalizedSha = commitSha.trim();
    if (normalizedSha.isEmpty) {
      return const [];
    }
    final result = await _listWorkflowRunsEndpoint(
      repositoryFullName,
      '/repos/$repositoryFullName/actions/runs',
      queryParameters: {'head_sha': normalizedSha},
    );
    return result.runs;
  }

  Future<RepositoryBuildLaunchResult> ensureBuildForCommit({
    required String repositoryFullName,
    required String branch,
    required String commitSha,
    void Function(String status)? onStatus,
    int verificationAttempts = 5,
    Duration verificationDelay = const Duration(seconds: 2),
    Duration postDispatchDelay = const Duration(seconds: 2),
  }) async {
    final normalizedSha = commitSha.trim();
    if (normalizedSha.isEmpty) {
      throw const RepositoryFileException(
        'O commit criado não possui SHA válido.',
        code: 'BUILD_COMMIT_SHA_MISSING',
      );
    }

    List<RepositoryWorkflow>? knownWorkflows;
    List<RepositoryWorkflow>? knownApkWorkflows;

    Future<List<RepositoryWorkflow>> loadKnownWorkflows() async {
      if (knownWorkflows != null) return knownWorkflows!;
      try {
        knownWorkflows = await listWorkflows(repositoryFullName);
      } catch (_) {
        knownWorkflows = const [];
      }
      return knownWorkflows!;
    }

    Future<List<RepositoryWorkflowRun>> filterApkRuns(
      List<RepositoryWorkflowRun> runs,
    ) async {
      final workflows = await loadKnownWorkflows();
      if (knownApkWorkflows == null && workflows.isNotEmpty) {
        knownApkWorkflows = await _findStructuralApkWorkflows(
          repositoryFullName: repositoryFullName,
          branch: branch,
          workflows: workflows,
        );
      }
      final apkWorkflows = knownApkWorkflows ?? const <RepositoryWorkflow>[];
      if (apkWorkflows.isNotEmpty) {
        return runs
            .where(
              (run) => apkWorkflows.any((workflow) => run.belongsTo(workflow)),
            )
            .toList(growable: false);
      }
      // Fallback apenas quando a API ainda não expôs os workflows/arquivos.
      return runs.where(_runLooksLikeApk).toList(growable: false);
    }

    // O SHA recém-criado é sempre consultado ANTES de procurar um workflow
    // manual. Isso evita disparar uma segunda build enquanto o push ainda
    // está sendo indexado pelo GitHub.
    for (var attempt = 0; attempt < verificationAttempts; attempt++) {
      onStatus?.call(
        attempt == 0
            ? 'Verificando se o push já iniciou a build'
            : 'Aguardando a build automática aparecer no GitHub',
      );

      final commitRuns = await listWorkflowRunsForCommit(
        repositoryFullName: repositoryFullName,
        commitSha: normalizedSha,
      );
      final apkRuns = await filterApkRuns(commitRuns);

      if (apkRuns.isNotEmpty) {
        final workflows = await loadKnownWorkflows();
        final workflow = _workflowForRun(workflows, apkRuns.first);
        onStatus?.call('Projeto atualizado • Build iniciada');
        return RepositoryBuildLaunchResult(
          commitSha: normalizedSha,
          runs: apkRuns,
          workflow: workflow,
          dispatchTriggered: false,
        );
      }

      if (attempt + 1 < verificationAttempts) {
        await Future<void>.delayed(verificationDelay);
      }
    }

    // Somente depois de confirmar que não existe execução APK para o SHA
    // novo é permitido procurar workflow_dispatch.
    onStatus?.call(
      'Nenhuma build automática encontrada. Verificando execução manual',
    );

    final workflows = await loadKnownWorkflows();

    final workflow = await _selectApkDispatchWorkflow(
      repositoryFullName: repositoryFullName,
      branch: branch,
      workflows: workflows,
    );

    if (workflow != null) {
      // Reconsulta o SHA imediatamente antes do POST de dispatch para fechar
      // a janela de corrida entre a verificação anterior e o disparo manual.
      final lastSecondRuns = await listWorkflowRunsForCommit(
        repositoryFullName: repositoryFullName,
        commitSha: normalizedSha,
      );
      final automaticRuns = await filterApkRuns(lastSecondRuns);
      if (automaticRuns.isNotEmpty) {
        onStatus?.call('Projeto atualizado • Build iniciada');
        return RepositoryBuildLaunchResult(
          commitSha: normalizedSha,
          runs: automaticRuns,
          workflow: _workflowForRun(workflows, automaticRuns.first),
          dispatchTriggered: false,
        );
      }

      onStatus?.call('O push não iniciou a build. Iniciando ${workflow.name}');
      final workflowRunId = await dispatchWorkflow(
        repositoryFullName: repositoryFullName,
        workflow: workflow,
        ref: branch,
      );

      await Future<void>.delayed(postDispatchDelay);
      final runs = await listWorkflowRunsForCommit(
        repositoryFullName: repositoryFullName,
        commitSha: normalizedSha,
      );
      final apkRuns = runs
          .where((run) => run.belongsTo(workflow))
          .toList(growable: false);
      return RepositoryBuildLaunchResult(
        commitSha: normalizedSha,
        runs: apkRuns,
        workflow: workflow,
        dispatchTriggered: true,
        workflowRunId: workflowRunId,
      );
    }

    // Workflows recém-criados podem demorar a aparecer em /actions/workflows.
    // Fazemos fallback nos arquivos reais de .github/workflows.
    final fileWorkflow = await _findApkDispatchWorkflowFile(
      repositoryFullName: repositoryFullName,
      branch: branch,
    );

    if (fileWorkflow != null) {
      final lastSecondRuns = await listWorkflowRunsForCommit(
        repositoryFullName: repositoryFullName,
        commitSha: normalizedSha,
      );
      final automaticRuns = await filterApkRuns(lastSecondRuns);
      if (automaticRuns.isNotEmpty) {
        onStatus?.call('Projeto atualizado • Build iniciada');
        return RepositoryBuildLaunchResult(
          commitSha: normalizedSha,
          runs: automaticRuns,
          workflow: _workflowForRun(workflows, automaticRuns.first),
          dispatchTriggered: false,
        );
      }

      onStatus?.call(
        'O push não iniciou a build. Iniciando ${fileWorkflow.fileName}',
      );
      final workflowRunId = await dispatchWorkflowFile(
        repositoryFullName: repositoryFullName,
        workflowFileName: fileWorkflow.fileName,
        ref: branch,
      );

      await Future<void>.delayed(postDispatchDelay);
      final runs = await listWorkflowRunsForCommit(
        repositoryFullName: repositoryFullName,
        commitSha: normalizedSha,
      );
      return RepositoryBuildLaunchResult(
        commitSha: normalizedSha,
        runs: runs
            .where(
              (run) => _sameWorkflowPath(
                run.workflowPath,
                fileWorkflow.path,
              ),
            )
            .toList(growable: false),
        workflow: null,
        dispatchTriggered: true,
        workflowRunId: workflowRunId,
      );
    }

    throw const RepositoryFileException(
      'O projeto foi atualizado, mas nenhuma build automática apareceu para o novo commit e não foi encontrado um workflow de APK com workflow_dispatch.',
      code: 'APK_WORKFLOW_DISPATCH_UNAVAILABLE',
    );
  }

  static bool _isApkWorkflowCandidate(RepositoryWorkflow workflow) {
    final searchable =
        '${workflow.name} ${workflow.fileName} ${workflow.path}'.toLowerCase();
    if (searchable.contains('apk')) {
      return true;
    }
    return searchable.contains('android') &&
        (searchable.contains('build') || searchable.contains('signed'));
  }

  static bool _runLooksLikeApk(RepositoryWorkflowRun run) {
    final searchable =
        '${run.name} ${run.title} ${run.workflowPath}'.toLowerCase();
    if (searchable.contains('apk')) {
      return true;
    }
    return searchable.contains('android') &&
        (searchable.contains('build') || searchable.contains('signed'));
  }

  Future<_WorkflowFileCandidate?> _findApkDispatchWorkflowFile({
    required String repositoryFullName,
    required String branch,
  }) async {
    List<RepositoryContentItem> files;
    try {
      files = await listContents(
        repositoryFullName: repositoryFullName,
        branch: branch,
        path: '.github/workflows',
      );
    } catch (_) {
      return null;
    }

    final yamlFiles = files
        .where(
          (item) =>
              item.isFile &&
              (item.name.toLowerCase().endsWith('.yml') ||
                  item.name.toLowerCase().endsWith('.yaml')),
        )
        .toList(growable: false);

    final preferred = <RepositoryContentItem>[
      ...yamlFiles.where(_contentItemLooksLikeApkWorkflow),
      ...yamlFiles.where((item) => !_contentItemLooksLikeApkWorkflow(item)),
    ];

    for (final item in preferred) {
      try {
        final file = await readTextFile(
          repositoryFullName: repositoryFullName,
          branch: branch,
          path: item.path,
        );
        final definition = WorkflowDefinitionInspector.inspect(file.content);
        if (definition.supportsDispatch && definition.likelyBuildsApk) {
          return _WorkflowFileCandidate(
            fileName: item.name,
            path: item.path,
          );
        }
      } catch (_) {
        // Um YAML indisponível não impede verificar os demais.
      }
    }
    return null;
  }

  static bool _contentItemLooksLikeApkWorkflow(RepositoryContentItem item) {
    final value = '${item.name} ${item.path}'.toLowerCase();
    return value.contains('apk') || value.contains('android');
  }

  Future<List<RepositoryWorkflow>> _findStructuralApkWorkflows({
    required String repositoryFullName,
    required String branch,
    required List<RepositoryWorkflow> workflows,
    bool requireDispatch = false,
  }) async {
    final active = workflows.where((workflow) => workflow.isActive).toList();
    active.sort((a, b) {
      final aPreferred = _isApkWorkflowCandidate(a) ? 0 : 1;
      final bPreferred = _isApkWorkflowCandidate(b) ? 0 : 1;
      if (aPreferred != bPreferred) return aPreferred.compareTo(bPreferred);
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    final result = <RepositoryWorkflow>[];
    final seen = <int>{};
    for (final workflow in active) {
      if (workflow.id <= 0 || !seen.add(workflow.id)) continue;
      final definition = await _readWorkflowDefinition(
        repositoryFullName: repositoryFullName,
        branch: branch,
        workflow: workflow,
      );
      if (definition == null || !definition.likelyBuildsApk) continue;
      if (requireDispatch && !definition.supportsDispatch) continue;
      result.add(workflow);
    }
    return result;
  }

  Future<WorkflowDefinitionInfo?> _readWorkflowDefinition({
    required String repositoryFullName,
    required String branch,
    required RepositoryWorkflow workflow,
  }) async {
    final candidates = <String>{
      if (workflow.path.trim().isNotEmpty)
        workflow.path.trim().replaceFirst(RegExp(r'^/+'), ''),
      if (workflow.fileName.trim().isNotEmpty)
        '.github/workflows/${workflow.fileName.trim()}',
    };
    for (final path in candidates) {
      try {
        final file = await readTextFile(
          repositoryFullName: repositoryFullName,
          branch: branch,
          path: path,
        );
        return WorkflowDefinitionInspector.inspect(file.content);
      } catch (_) {
        // Tenta a próxima representação do mesmo workflow.
      }
    }
    return null;
  }

  Future<RepositoryWorkflow?> _selectApkDispatchWorkflow({
    required String repositoryFullName,
    required String branch,
    required List<RepositoryWorkflow> workflows,
  }) async {
    final candidates = await _findStructuralApkWorkflows(
      repositoryFullName: repositoryFullName,
      branch: branch,
      workflows: workflows,
      requireDispatch: true,
    );
    return candidates.isEmpty ? null : candidates.first;
  }

  Future<String> dispatchBestApkWorkflow({
    required String repositoryFullName,
    required String branch,
  }) async {
    List<RepositoryWorkflow> workflows = const [];
    try {
      workflows = await listWorkflows(repositoryFullName);
    } catch (_) {
      // O fallback pelos YAMLs cobre workflows recém-criados.
    }

    final workflow = await _selectApkDispatchWorkflow(
      repositoryFullName: repositoryFullName,
      branch: branch,
      workflows: workflows,
    );
    if (workflow != null) {
      await dispatchWorkflow(
        repositoryFullName: repositoryFullName,
        workflow: workflow,
        ref: branch,
      );
      return workflow.name;
    }

    final file = await _findApkDispatchWorkflowFile(
      repositoryFullName: repositoryFullName,
      branch: branch,
    );
    if (file != null) {
      await dispatchWorkflowFile(
        repositoryFullName: repositoryFullName,
        workflowFileName: file.fileName,
        ref: branch,
      );
      return file.fileName;
    }

    throw const RepositoryFileException(
      'Nenhum workflow que gere APK e aceite workflow_dispatch foi encontrado.',
      code: 'APK_WORKFLOW_DISPATCH_UNAVAILABLE',
    );
  }

  static bool _sameWorkflowPath(String a, String b) =>
      a.trim().replaceAll('\\', '/').toLowerCase() ==
      b.trim().replaceAll('\\', '/').toLowerCase();

  static RepositoryWorkflow? _workflowForRun(
    List<RepositoryWorkflow> workflows,
    RepositoryWorkflowRun run,
  ) {
    for (final workflow in workflows) {
      if (run.belongsTo(workflow)) {
        return workflow;
      }
    }
    return null;
  }

  Future<RepositoryActionsData> loadActions(
    String repositoryFullName, {
    RepositoryWorkflow? workflow,
  }) async {
    final workflows = await listWorkflows(repositoryFullName);
    final repositoryPage = await _listWorkflowRunsEndpoint(
      repositoryFullName,
      '/repos/$repositoryFullName/actions/runs',
    );
    final allRuns = await _enrichRunVersions(
      repositoryFullName,
      repositoryPage.runs,
      limit: 8,
    );

    RepositoryWorkflow? selected;
    if (workflow != null) {
      for (final item in workflows) {
        if (item.id == workflow.id ||
            (workflow.path.isNotEmpty && item.path == workflow.path)) {
          selected = item;
          break;
        }
      }
      selected ??= workflow;
    }

    var visibleRuns = selected == null
        ? List<RepositoryWorkflowRun>.from(allRuns)
        : allRuns.where((run) => run.belongsTo(selected!)).toList();

    String? fallbackEndpoint;
    int? fallbackHttpStatus;
    int? fallbackRunsReceived;
    var reason = selected == null
        ? (allRuns.isEmpty ? 'api_vazia' : 'todas_as_execucoes')
        : (visibleRuns.isEmpty
            ? (allRuns.isEmpty ? 'api_vazia' : 'filtro_sem_correspondencia')
            : 'filtro_local');

    if (selected != null && visibleRuns.isEmpty) {
      final candidates = <String>[
        if (selected.id > 0)
          '/repos/$repositoryFullName/actions/workflows/${selected.id}/runs',
        if (selected.fileName.trim().isNotEmpty)
          '/repos/$repositoryFullName/actions/workflows/${Uri.encodeComponent(selected.fileName)}/runs',
      ];
      for (final endpoint in candidates.toSet()) {
        try {
          final fallback = await _listWorkflowRunsEndpoint(
            repositoryFullName,
            endpoint,
          );
          fallbackEndpoint = endpoint;
          fallbackHttpStatus = fallback.httpStatus;
          fallbackRunsReceived = fallback.runs.length;
          if (fallback.runs.isNotEmpty) {
            visibleRuns = fallback.runs;
            reason = 'fallback_workflow_especifico';
            break;
          }
        } on AppException {
          fallbackEndpoint = endpoint;
          reason = 'fallback_com_erro';
        }
      }
    }

    return RepositoryActionsData(
      workflows: workflows,
      allRuns: allRuns,
      runs: visibleRuns,
      selectedWorkflow: selected,
      diagnostic: RepositoryActionsDiagnostic(
        endpoint: '/repos/$repositoryFullName/actions/runs?per_page=100',
        httpStatus: repositoryPage.httpStatus,
        repositoryRunsReceived: allRuns.length,
        runsAfterFilter: visibleRuns.length,
        totalCountReported: repositoryPage.totalCount,
        reason: reason,
        workflowId: selected?.id,
        workflowName: selected?.name,
        workflowPath: selected?.path,
        workflowState: selected?.state,
        fallbackEndpoint: fallbackEndpoint,
        fallbackHttpStatus: fallbackHttpStatus,
        fallbackRunsReceived: fallbackRunsReceived,
      ),
    );
  }

  Future<List<RepositoryWorkflowRun>> listWorkflowRuns(
    String repositoryFullName,
  ) async {
    final result = await _listWorkflowRunsEndpoint(
      repositoryFullName,
      '/repos/$repositoryFullName/actions/runs',
    );
    return _enrichRunVersions(repositoryFullName, result.runs, limit: 3);
  }

  Future<List<RepositoryWorkflowRun>> _enrichRunVersions(
    String repositoryFullName,
    List<RepositoryWorkflowRun> runs, {
    required int limit,
  }) async {
    final recentBySha = <String, RepositoryWorkflowRun>{};
    for (final run in runs) {
      if (run.headSha.trim().isEmpty) continue;
      recentBySha.putIfAbsent(run.headSha, () => run);
      if (recentBySha.length >= limit) break;
    }
    final versions = <String, String?>{};
    await Future.wait(
      recentBySha.values.map((run) async {
        final parsed = run.detectedVersion;
        if (parsed != null) {
          versions[run.headSha] = parsed;
          return;
        }
        if (run.headSha.trim().isEmpty) return;
        final key = '$repositoryFullName@${run.headSha}';
        if (_runVersionCache.containsKey(key)) {
          versions[run.headSha] = _runVersionCache[key];
          return;
        }
        final resolved = await _resolveVersionAtRef(
          repositoryFullName,
          run.headSha,
        );
        _runVersionCache[key] = resolved;
        versions[run.headSha] = resolved;
      }),
    );

    return runs
        .map(
          (run) => versions.containsKey(run.headSha)
              ? run.withBuildVersion(versions[run.headSha])
              : run,
        )
        .toList(growable: false);
  }

  Future<String?> _resolveVersionAtRef(
    String repositoryFullName,
    String ref,
  ) async {
    for (final path in const [
      'github-manager.json',
      'app.json',
      'pubspec.yaml',
      'VERSION',
    ]) {
      try {
        final file = await readTextFile(
          repositoryFullName: repositoryFullName,
          branch: ref,
          path: path,
        );
        final text = file.content;
        if (path.endsWith('.json')) {
          final raw = jsonDecode(text);
          if (raw is Map) {
            final map = Map<String, dynamic>.from(raw);
            final android = map['android'];
            if (android is Map) {
              final androidMap = Map<String, dynamic>.from(android);
              final name = androidMap['versionName']?.toString().trim();
              final code = androidMap['versionCode']?.toString().trim();
              if (name?.isNotEmpty == true) {
                return code?.isNotEmpty == true ? '$name+$code' : name;
              }
            }
            final version = (map['version'] ?? map['versionName'])?.toString().trim();
            if (version?.isNotEmpty == true) return version;
          }
        } else if (path == 'pubspec.yaml') {
          final version = RegExp(r'^version:\s*([^\s#]+)', multiLine: true)
              .firstMatch(text)
              ?.group(1)
              ?.trim();
          if (version?.isNotEmpty == true) return version;
        } else {
          final version = text.trim();
          if (version.isNotEmpty) return version;
        }
      } catch (_) {
        // Tenta a próxima fonte de versão.
      }
    }
    return null;
  }

  Future<_WorkflowRunsPage> _listWorkflowRunsEndpoint(
    String repositoryFullName,
    String endpoint, {
    Map<String, dynamic> queryParameters = const {},
  }) async {
    final byId = <int, RepositoryWorkflowRun>{};
    int? status;
    int? totalCount;
    for (var page = 1; page <= 5; page++) {
      final response = await _client.get<Map<String, dynamic>>(
        endpoint,
        queryParameters: {
          ...queryParameters,
          'per_page': 100,
          'page': page,
        },
      );
      status = response.statusCode;
      totalCount ??= (response.data?['total_count'] as num?)?.toInt();
      final raw = response.data?['workflow_runs'];
      if (raw is! List) {
        throw const RepositoryFileException(
          'O GitHub retornou uma resposta inesperada ao listar execuções.',
          code: 'ACTIONS_RUNS_RESPONSE_INVALID',
        );
      }
      final pageItems = raw
          .whereType<Map>()
          .map(
            (json) => RepositoryWorkflowRun.fromJson(
              Map<String, dynamic>.from(json),
            ),
          )
          .toList(growable: false);
      for (final item in pageItems) {
        byId[item.id] = item;
      }
      if (pageItems.length < 100) {
        break;
      }
    }
    final runs = byId.values.toList()
      ..sort((a, b) {
        final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
    return _WorkflowRunsPage(
      runs: runs,
      httpStatus: status,
      totalCount: totalCount,
    );
  }

  Future<List<RepositoryWorkflowJob>> listWorkflowRunJobs({
    required String repositoryFullName,
    required int runId,
  }) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/repos/$repositoryFullName/actions/runs/$runId/jobs',
      queryParameters: {'per_page': 100},
    );
    final raw = response.data?['jobs'];
    if (raw is! List) {
      throw const RepositoryFileException(
        'O GitHub retornou uma resposta inesperada ao listar jobs.',
        code: 'ACTIONS_JOBS_RESPONSE_INVALID',
      );
    }
    return raw
        .whereType<Map>()
        .map(
          (json) => RepositoryWorkflowJob.fromJson(
            Map<String, dynamic>.from(json),
          ),
        )
        .toList(growable: false);
  }

  Future<RepositoryWorkflowFailure?> loadWorkflowFailure({
    required String repositoryFullName,
    required RepositoryWorkflowJob job,
  }) async {
    if (!job.failed) {
      return null;
    }
    RepositoryWorkflowStep? failedStep;
    for (final step in job.steps) {
      if (step.failed) {
        failedStep = step;
        break;
      }
    }
    String? message;
    try {
      final response = await _client.get<List<dynamic>>(
        '/repos/$repositoryFullName/check-runs/${job.id}/annotations',
        queryParameters: {'per_page': 100},
      );
      final annotations = response.data ?? const <dynamic>[];
      for (final raw in annotations.whereType<Map>()) {
        if (raw['annotation_level'] == 'failure') {
          final value = raw['message']?.toString().trim();
          if (value != null && value.isNotEmpty) {
            message = value;
            break;
          }
        }
      }
    } on AppException {
      // A ausência de annotations não esconde a etapa que falhou.
    }
    return RepositoryWorkflowFailure(
      jobName: job.name,
      stepName: failedStep?.name ?? 'Etapa não informada pelo GitHub',
      message: message ??
          'O GitHub marcou esta etapa como falha. Baixe os logs para ver a saída completa do comando.',
    );
  }

  Future<void> cancelWorkflowRun({
    required String repositoryFullName,
    required int runId,
  }) =>
      _client.post<void>(
        '/repos/$repositoryFullName/actions/runs/$runId/cancel',
      );

  Future<void> rerunWorkflowRun({
    required String repositoryFullName,
    required int runId,
  }) =>
      _client.post<void>(
        '/repos/$repositoryFullName/actions/runs/$runId/rerun',
      );

  Future<void> deleteWorkflowRun({
    required String repositoryFullName,
    required int runId,
  }) =>
      _client.delete<void>(
        '/repos/$repositoryFullName/actions/runs/$runId',
      );

  Future<int> deleteWorkflowRuns({
    required String repositoryFullName,
    required Iterable<int> runIds,
  }) async {
    var deleted = 0;
    for (final runId in runIds.toSet()) {
      await deleteWorkflowRun(
        repositoryFullName: repositoryFullName,
        runId: runId,
      );
      deleted++;
    }
    return deleted;
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


class _WorkflowFileCandidate {
  const _WorkflowFileCandidate({
    required this.fileName,
    required this.path,
  });

  final String fileName;
  final String path;
}

class _WorkflowRunsPage {
  const _WorkflowRunsPage({
    required this.runs,
    required this.httpStatus,
    required this.totalCount,
  });

  final List<RepositoryWorkflowRun> runs;
  final int? httpStatus;
  final int? totalCount;
}
