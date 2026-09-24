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

  Future<bool> hasApkBuildWorkflow({
    required String repositoryFullName,
    required String branch,
  }) async {
    List<RepositoryWorkflow> workflows = const <RepositoryWorkflow>[];
    try {
      workflows = await listWorkflows(repositoryFullName);
    } catch (_) {
      // A API de Actions pode não estar disponível para o token. A inspeção
      // dos YAMLs via Contents ainda consegue confirmar a presença do workflow.
    }

    if (workflows.isNotEmpty) {
      final structural = await _findStructuralApkWorkflows(
        repositoryFullName: repositoryFullName,
        branch: branch,
        workflows: workflows,
      );
      if (structural.isNotEmpty) return true;
    }

    final scan = await _scanWorkflowFiles(
      repositoryFullName: repositoryFullName,
      branch: branch,
    );
    if (scan.hasApkWorkflow) return true;
    if (scan.inspectionIncomplete) {
      throw const RepositoryFileException(
        'Não foi possível confirmar os workflows desta branch.',
        code: 'APK_WORKFLOW_INSPECTION_FAILED',
      );
    }
    return false;
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

    List<RepositoryWorkflow> knownWorkflows = const [];
    List<RepositoryWorkflow>? knownApkWorkflows;
    _WorkflowFileScan? initialWorkflowScan;

    try {
      knownWorkflows = await listWorkflows(repositoryFullName);
    } catch (_) {
      knownWorkflows = const [];
    }
    if (knownWorkflows.isNotEmpty) {
      knownApkWorkflows = await _findStructuralApkWorkflows(
        repositoryFullName: repositoryFullName,
        branch: branch,
        workflows: knownWorkflows,
      );
    }
    if (knownApkWorkflows?.isNotEmpty != true) {
      initialWorkflowScan = await _scanWorkflowFiles(
        repositoryFullName: repositoryFullName,
        branch: branch,
      );
      if (!initialWorkflowScan.hasApkWorkflow &&
          !initialWorkflowScan.inspectionIncomplete) {
        throw const RepositoryFileException(
          'Esta branch não possui workflow de build de APK. O projeto pode ser atualizado normalmente sem GitHub Actions.',
          code: 'APK_WORKFLOW_NOT_FOUND',
        );
      }
    }

    Future<List<RepositoryWorkflow>> loadKnownWorkflows() async {
      return knownWorkflows;
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
    // Por isso a fonte de verdade final são os YAMLs reais da branch.
    final workflowScan = initialWorkflowScan ??
        await _scanWorkflowFiles(
          repositoryFullName: repositoryFullName,
          branch: branch,
        );
    final fileWorkflow = workflowScan.firstDispatch;

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

    // Se existe um workflow de APK acionado por push, ainda pode haver atraso de
    // indexação do Actions. Damos uma janela extra antes de transformar isso em
    // atenção para o usuário. Isso evita falsos negativos logo após o commit.
    if (workflowScan.hasApkWorkflow && workflowScan.hasPush) {
      for (var attempt = 0; attempt < 4; attempt++) {
        onStatus?.call('Workflow de APK encontrado • aguardando o GitHub Actions');
        await Future<void>.delayed(const Duration(seconds: 3));
        final delayedRuns = await listWorkflowRunsForCommit(
          repositoryFullName: repositoryFullName,
          commitSha: normalizedSha,
        );
        final apkRuns = await filterApkRuns(delayedRuns);
        if (apkRuns.isNotEmpty) {
          onStatus?.call('Projeto atualizado • Build iniciada');
          return RepositoryBuildLaunchResult(
            commitSha: normalizedSha,
            runs: apkRuns,
            workflow: _workflowForRun(workflows, apkRuns.first),
            dispatchTriggered: false,
          );
        }
      }

      throw RepositoryFileException(
        'O projeto foi enviado e existe um workflow de APK com gatilho por push, mas o GitHub Actions ainda não criou uma execução para este commit. Verifique filtros de branch/paths ou tente localizar a build novamente.',
        code: 'APK_WORKFLOW_PUSH_NOT_STARTED',
      );
    }

    if (workflowScan.hasApkWorkflow) {
      throw RepositoryFileException(
        'O projeto foi enviado, mas o workflow de APK não possui um gatilho utilizável pelo GitHub Manager. Adicione push e/ou workflow_dispatch ao bloco on: do workflow.',
        code: 'APK_WORKFLOW_TRIGGER_MISSING',
      );
    }

    if (workflowScan.inspectionIncomplete) {
      throw const RepositoryFileException(
        'O projeto foi enviado, mas não foi possível confirmar com segurança se a branch possui um workflow de APK. Tente verificar a build novamente.',
        code: 'APK_WORKFLOW_INSPECTION_FAILED',
      );
    }

    throw const RepositoryFileException(
      'O projeto foi enviado, mas não foi encontrado nenhum workflow em .github/workflows que gere APK.',
      code: 'APK_WORKFLOW_NOT_FOUND',
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

  Future<_WorkflowFileScan> _scanWorkflowFiles({
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
    } on GitHubNotFoundException {
      return const _WorkflowFileScan(apkCandidates: []);
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
    final apkCandidates = <_WorkflowFileInspection>[];
    var inspectionIncomplete = false;

    for (final item in preferred) {
      try {
        final file = await readTextFile(
          repositoryFullName: repositoryFullName,
          branch: branch,
          path: item.path,
        );
        final definition = WorkflowDefinitionInspector.inspect(file.content);
        if (!definition.likelyBuildsApk) continue;
        apkCandidates.add(
          _WorkflowFileInspection(
            fileName: item.name,
            path: item.path,
            info: definition,
          ),
        );
      } catch (_) {
        inspectionIncomplete = true;
        // Um YAML indisponível não impede verificar os demais.
      }
    }
    return _WorkflowFileScan(
      apkCandidates: apkCandidates,
      inspectionIncomplete: inspectionIncomplete,
    );
  }

  Future<_WorkflowFileCandidate?> _findApkDispatchWorkflowFile({
    required String repositoryFullName,
    required String branch,
  }) async {
    final scan = await _scanWorkflowFiles(
      repositoryFullName: repositoryFullName,
      branch: branch,
    );
    final candidate = scan.firstDispatch;
    if (candidate == null) return null;
    return _WorkflowFileCandidate(
      fileName: candidate.fileName,
      path: candidate.path,
    );
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
