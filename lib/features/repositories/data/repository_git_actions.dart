part of 'repository_git_service.dart';

mixin _RepositoryGitActionsOperations
    on _RepositoryGitBase, _RepositoryGitFileOperations, _RepositoryGitWorkflowOperations {
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
}
