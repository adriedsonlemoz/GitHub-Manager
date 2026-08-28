part of 'repository_git_service.dart';

mixin _RepositoryGitWorkflowOperations
    on _RepositoryGitBase, _RepositoryGitFileOperations {
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

  Future<_WorkflowRunsPage> _listWorkflowRunsEndpoint(
    String repositoryFullName,
    String endpoint, {
    Map<String, dynamic> queryParameters = const {},
  }) async {
    final byId = <int, RepositoryWorkflowRun>{};
    int? status;
    int? totalCount;
    for (var page = 1; page <= 5; page++) {
      final response = await this._client.get<Map<String, dynamic>>(
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

}
