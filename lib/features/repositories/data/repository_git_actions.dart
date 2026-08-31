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

  Future<List<RepositoryWorkflowRun>> listRecentWorkflowRuns(
    String repositoryFullName, {
    int perPage = 100,
  }) async {
    final normalizedPerPage = perPage < 1 ? 1 : (perPage > 100 ? 100 : perPage);
    final response = await _client.get<Map<String, dynamic>>(
      '/repos/$repositoryFullName/actions/runs',
      queryParameters: {'per_page': normalizedPerPage, 'page': 1},
    );
    final raw = response.data?['workflow_runs'];
    if (raw is! List) {
      throw const RepositoryFileException(
        'O GitHub retornou uma resposta inesperada ao atualizar as execuções.',
        code: 'ACTIONS_RECENT_RUNS_RESPONSE_INVALID',
      );
    }
    final runs = raw
        .whereType<Map>()
        .map(
          (json) => RepositoryWorkflowRun.fromJson(
            Map<String, dynamic>.from(json),
          ),
        )
        .toList(growable: true)
      ..sort((a, b) {
        final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
    return _enrichRunVersions(repositoryFullName, runs, limit: 3);
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
      'app/build.gradle.kts',
      'app/build.gradle',
      'android/app/build.gradle.kts',
      'android/app/build.gradle',
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
        } else if (path.endsWith('build.gradle') ||
            path.endsWith('build.gradle.kts')) {
          final name = RegExp(
            r'''versionName\s*(?:=\s*)?["']([^"']+)["']''',
          ).firstMatch(text)?.group(1)?.trim();
          final code = RegExp(r'''versionCode\s*(?:=\s*)?(\d+)''')
              .firstMatch(text)
              ?.group(1)
              ?.trim();
          if (name?.isNotEmpty == true) {
            return code?.isNotEmpty == true ? '$name+$code' : name;
          }
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
    required int runId,
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

    String? annotationMessage;
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
            annotationMessage = value;
            break;
          }
        }
      }
    } on AppException {
      // A ausência de annotations não esconde a etapa que falhou.
    }

    _WorkflowLogInsight? logInsight;
    String? logUnavailableReason;
    try {
      logInsight = await _loadWorkflowLogInsight(
        repositoryFullName: repositoryFullName,
        runId: runId,
        jobName: job.name,
        failedStepName: failedStep?.name,
      );
    } on AppException catch (error) {
      logUnavailableReason = error.message;
    } catch (_) {
      logUnavailableReason =
          'Não foi possível analisar automaticamente o arquivo de logs.';
    }

    final logHeadline = logInsight?.headline;
    final annotation = annotationMessage;
    final annotationIsGeneric = annotation != null &&
        RegExp(
          r'process completed with exit code\s+\d+',
          caseSensitive: false,
        ).hasMatch(annotation);
    final message = logHeadline != null && annotationIsGeneric
        ? logHeadline
        : annotation ??
            logHeadline ??
            'O GitHub marcou esta etapa como falha, mas não publicou uma mensagem detalhada.';

    return RepositoryWorkflowFailure(
      jobName: job.name,
      stepName: failedStep?.name ?? 'Etapa não informada pelo GitHub',
      message: message,
      annotationMessage: annotation,
      logHeadline: logHeadline,
      logContext: logInsight?.context ?? const <String>[],
      logsInspected: logInsight != null,
      logUnavailableReason: logUnavailableReason,
    );
  }

  Future<_WorkflowLogInsight?> _loadWorkflowLogInsight({
    required String repositoryFullName,
    required int runId,
    required String jobName,
    String? failedStepName,
  }) async {
    final tempRoot = await getTemporaryDirectory();
    final logFile = File(
      p.join(
        tempRoot.path,
        'github-manager-run-$runId-${DateTime.now().microsecondsSinceEpoch}.zip',
      ),
    );
    try {
      await _client.downloadRedirectedFile(
        '/repos/$repositoryFullName/actions/runs/$runId/logs',
        logFile.path,
      );
      if (!await logFile.exists() || await logFile.length() == 0) {
        return null;
      }

      final input = InputFileStream(logFile.path);
      try {
        final archive = ZipDecoder().decodeStream(input, verify: false);
        final entries = archive.where((entry) => entry.isFile).toList();
        if (entries.isEmpty) {
          return null;
        }
        entries.sort(
          (a, b) => _logEntryPriority(
            b.name,
            jobName: jobName,
            failedStepName: failedStepName,
          ).compareTo(
            _logEntryPriority(
              a.name,
              jobName: jobName,
              failedStepName: failedStepName,
            ),
          ),
        );

        _LogLineCandidate? best;
        var inspectedBytes = 0;
        const maxInspectedBytes = 8 * 1024 * 1024;
        const maxEntryBytes = 4 * 1024 * 1024;

        for (final entry in entries.take(16)) {
          if (entry.size <= 0 || entry.size > maxEntryBytes) continue;
          if (inspectedBytes + entry.size > maxInspectedBytes) break;
          final bytes = entry.readBytes();
          if (bytes == null || bytes.isEmpty) continue;
          inspectedBytes += bytes.length;
          final text = utf8.decode(bytes, allowMalformed: true);
          final lines = text
              .split('\n')
              .map(_cleanLogLine)
              .where((line) => line.isNotEmpty)
              .toList(growable: false);
          if (lines.isEmpty) continue;

          for (var index = 0; index < lines.length; index++) {
            final line = lines[index];
            final score = _diagnosticLineScore(
              line,
              failedStepName: failedStepName,
            );
            if (score <= 0) continue;
            if (best == null || score > best.score) {
              best = _LogLineCandidate(
                score: score,
                lineIndex: index,
                line: line,
                lines: lines,
              );
            }
          }
          if (best != null && best.score >= 100) break;
        }

        if (best == null) return null;

        final from = best.lineIndex > 2 ? best.lineIndex - 2 : 0;
        final to = best.lineIndex + 4 < best.lines.length
            ? best.lineIndex + 4
            : best.lines.length;
        final context = best.lines.sublist(from, to);
        return _WorkflowLogInsight(
          headline: _trimDiagnosticLine(best.line),
          context: _compactLogContext(context),
        );
      } finally {
        input.closeSync();
      }
    } finally {
      try {
        if (await logFile.exists()) await logFile.delete();
      } catch (_) {
        // Arquivo temporário auxiliar; o sistema pode limpá-lo depois.
      }
    }
  }

  static int _logEntryPriority(
    String name, {
    required String jobName,
    String? failedStepName,
  }) {
    final normalized = _normalizeDiagnosticText(name);
    var score = name.toLowerCase().endsWith('.txt') ? 10 : 0;
    final job = _normalizeDiagnosticText(jobName);
    final step = _normalizeDiagnosticText(failedStepName ?? '');
    if (job.isNotEmpty && normalized.contains(job)) score += 100;
    if (step.isNotEmpty && normalized.contains(step)) score += 40;
    return score;
  }

  static int _diagnosticLineScore(
    String line, {
    String? failedStepName,
  }) {
    final lower = line.toLowerCase();
    if (RegExp(r'process completed with exit code\s+\d+').hasMatch(lower)) {
      return 20;
    }
    if (lower.contains('##[error]')) return 120;
    if (lower.contains('build failed') ||
        lower.contains('compilation failed') ||
        lower.contains('test failed') ||
        lower.contains('tests failed')) {
      return 110;
    }
    if (RegExp(r'(^|\s)(fatal|exception|error)[:\s]').hasMatch(lower)) {
      return 100;
    }
    if (lower.contains('failure:') || lower.contains('failed:')) return 90;
    if (lower.contains('assertion failed') ||
        lower.contains('expected:') ||
        lower.contains('actual:')) {
      return 85;
    }
    final step = _normalizeDiagnosticText(failedStepName ?? '');
    if (step.isNotEmpty &&
        _normalizeDiagnosticText(line).contains(step) &&
        (lower.contains('error') || lower.contains('fail'))) {
      return 75;
    }
    if (lower.contains('failed') || lower.contains('failure')) return 65;
    return 0;
  }

  static String _cleanLogLine(String value) {
    var line = value
        .replaceAll(RegExp(r'\x1B\[[0-9;]*[A-Za-z]'), '')
        .replaceAll('\r', '')
        .trim();
    line = line.replaceFirst(
      RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z\s+'),
      '',
    );
    return line.trim();
  }

  static String _normalizeDiagnosticText(String value) {
    var normalized = value.toLowerCase();
    const replacements = <String, String>{
      'á': 'a',
      'à': 'a',
      'â': 'a',
      'ã': 'a',
      'ä': 'a',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'í': 'i',
      'ì': 'i',
      'î': 'i',
      'ï': 'i',
      'ó': 'o',
      'ò': 'o',
      'ô': 'o',
      'õ': 'o',
      'ö': 'o',
      'ú': 'u',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
      'ç': 'c',
    };
    for (final entry in replacements.entries) {
      normalized = normalized.replaceAll(entry.key, entry.value);
    }
    return normalized.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }

  static String _trimDiagnosticLine(String line) {
    final value = line.trim();
    return value.length <= 420 ? value : '${value.substring(0, 417)}...';
  }

  static List<String> _compactLogContext(List<String> lines) {
    final result = <String>[];
    for (final raw in lines) {
      final value = _trimDiagnosticLine(raw);
      if (value.isEmpty || (result.isNotEmpty && result.last == value)) continue;
      result.add(value);
      if (result.length >= 6) break;
    }
    return List<String>.unmodifiable(result);
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

  Future<RepositoryBulkDeleteResult> deleteWorkflowRuns({
    required String repositoryFullName,
    required Iterable<int> runIds,
  }) async {
    final deletedIds = <int>[];
    final failedIds = <int>[];
    final failureMessages = <int, String>{};
    for (final runId in runIds.toSet()) {
      try {
        await deleteWorkflowRun(
          repositoryFullName: repositoryFullName,
          runId: runId,
        );
        deletedIds.add(runId);
      } catch (error) {
        failedIds.add(runId);
        failureMessages[runId] = error is AppException
            ? error.message
            : 'Não foi possível excluir esta execução.';
      }
    }
    return RepositoryBulkDeleteResult(
      deletedIds: List<int>.unmodifiable(deletedIds),
      failedIds: List<int>.unmodifiable(failedIds),
      failureMessages: Map<int, String>.unmodifiable(failureMessages),
    );
  }
}

class _WorkflowLogInsight {
  const _WorkflowLogInsight({
    required this.headline,
    required this.context,
  });

  final String headline;
  final List<String> context;
}

class _LogLineCandidate {
  const _LogLineCandidate({
    required this.score,
    required this.lineIndex,
    required this.line,
    required this.lines,
  });

  final int score;
  final int lineIndex;
  final String line;
  final List<String> lines;
}
