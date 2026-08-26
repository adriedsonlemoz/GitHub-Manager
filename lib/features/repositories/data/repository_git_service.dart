import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:github_manager/core/errors/app_exception.dart';
import 'package:github_manager/core/network/github_api_client.dart';
import 'package:github_manager/core/utils/commit_message.dart';
import 'package:github_manager/features/repositories/domain/repository_git_models.dart';

class RepositoryGitService {
  RepositoryGitService(this._client);

  static const maxEditableTextBytes = 1024 * 1024;
  static const maxUploadBytes = 95 * 1024 * 1024;

  final GitHubApiClient _client;

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
    if (workflow.path.trim().isEmpty) {
      return false;
    }
    final file = await readTextFile(
      repositoryFullName: repositoryFullName,
      branch: branch,
      path: workflow.path,
    );
    return _supportsWorkflowDispatchContent(file.content);
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
    int verificationAttempts = 4,
    Duration verificationDelay = const Duration(seconds: 2),
  }) async {
    List<RepositoryWorkflow> workflows = const [];
    for (var attempt = 0; attempt < verificationAttempts; attempt++) {
      onStatus?.call('Verificando execução do GitHub Actions');
      workflows = await listWorkflows(repositoryFullName);
      final runs = await listWorkflowRunsForCommit(
        repositoryFullName: repositoryFullName,
        commitSha: commitSha,
      );
      final apkWorkflow = _firstApkWorkflow(workflows);
      final apkRuns = apkWorkflow == null
          ? runs.where(_runLooksLikeApk).toList(growable: false)
          : runs.where((run) => run.belongsTo(apkWorkflow)).toList(growable: false);
      if (apkRuns.isNotEmpty) {
        return RepositoryBuildLaunchResult(
          commitSha: commitSha,
          runs: apkRuns,
          workflow: apkWorkflow ?? _workflowForRun(workflows, apkRuns.first),
          dispatchTriggered: false,
        );
      }

      if (attempt + 1 < verificationAttempts) {
        onStatus?.call(
          workflows.isEmpty
              ? 'Aguardando o GitHub indexar os workflows'
              : 'Aguardando o Android APK iniciar pelo push',
        );
        await Future<void>.delayed(verificationDelay);
      }
    }

    if (workflows.isEmpty) {
      const apkPath = '.github/workflows/android-apk.yml';
      try {
        final apkFile = await readTextFile(
          repositoryFullName: repositoryFullName,
          branch: branch,
          path: apkPath,
        );
        if (!_supportsWorkflowDispatchContent(apkFile.content)) {
          throw const RepositoryFileException(
            'O Android APK existe no repositório, mas não possui workflow_dispatch.',
            code: 'APK_WORKFLOW_DISPATCH_UNAVAILABLE',
          );
        }
        onStatus?.call('Workflow ainda indexando. Iniciando Android APK pelo arquivo');
        final workflowRunId = await dispatchWorkflowFile(
          repositoryFullName: repositoryFullName,
          workflowFileName: 'android-apk.yml',
          ref: branch,
        );
        await Future<void>.delayed(const Duration(seconds: 2));
        final runs = await listWorkflowRunsForCommit(
          repositoryFullName: repositoryFullName,
          commitSha: commitSha,
        );
        return RepositoryBuildLaunchResult(
          commitSha: commitSha,
          runs: runs.where(_runLooksLikeApk).toList(growable: false),
          workflow: null,
          dispatchTriggered: true,
          workflowRunId: workflowRunId,
        );
      } on GitHubNotFoundException {
        throw const RepositoryFileException(
          'O projeto foi enviado, mas o GitHub ainda não reconheceu o Android APK como workflow executável. Abra Builds e tente novamente em alguns instantes.',
          code: 'ACTIONS_WORKFLOWS_NOT_INDEXED',
        );
      }
    }

    final workflow = await _selectApkDispatchWorkflow(
      repositoryFullName: repositoryFullName,
      branch: branch,
      workflows: workflows,
    );
    if (workflow == null) {
      throw const RepositoryFileException(
        'O projeto foi enviado, mas não existe um workflow de APK com workflow_dispatch para iniciar a build manualmente.',
        code: 'APK_WORKFLOW_DISPATCH_UNAVAILABLE',
      );
    }

    onStatus?.call('O push não iniciou a build. Iniciando ${workflow.name}');
    final workflowRunId = await dispatchWorkflow(
      repositoryFullName: repositoryFullName,
      workflow: workflow,
      ref: branch,
    );

    await Future<void>.delayed(const Duration(seconds: 2));
    final runs = await listWorkflowRunsForCommit(
      repositoryFullName: repositoryFullName,
      commitSha: commitSha,
    );
    final apkRuns = runs.where((run) => run.belongsTo(workflow)).toList(growable: false);
    return RepositoryBuildLaunchResult(
      commitSha: commitSha,
      runs: apkRuns,
      workflow: workflow,
      dispatchTriggered: true,
      workflowRunId: workflowRunId,
    );
  }

  static RepositoryWorkflow? _firstApkWorkflow(
    List<RepositoryWorkflow> workflows,
  ) {
    for (final workflow in workflows) {
      if (workflow.isActive && _isApkWorkflowCandidate(workflow)) {
        return workflow;
      }
    }
    return null;
  }

  static bool _isApkWorkflowCandidate(RepositoryWorkflow workflow) {
    final fileName = workflow.fileName.toLowerCase();
    final name = workflow.name.trim().toLowerCase();
    if (fileName == 'android-apk.yml' || name == 'android apk') {
      return true;
    }
    final searchable = '$name ${workflow.path}'.toLowerCase();
    return searchable.contains('apk') && !searchable.contains('release');
  }

  static bool _runLooksLikeApk(RepositoryWorkflowRun run) {
    final searchable = '${run.name} ${run.workflowPath}'.toLowerCase();
    return searchable.contains('apk') && !searchable.contains('release');
  }

  static bool _supportsWorkflowDispatchContent(String content) => RegExp(
        r'^\s*workflow_dispatch\s*:',
        multiLine: true,
      ).hasMatch(content);

  Future<RepositoryWorkflow?> _selectApkDispatchWorkflow({
    required String repositoryFullName,
    required String branch,
    required List<RepositoryWorkflow> workflows,
  }) async {
    final preferred = workflows
        .where((workflow) => workflow.isActive && _isApkWorkflowCandidate(workflow))
        .toList(growable: false);

    final seen = <int>{};
    for (final workflow in preferred) {
      if (workflow.id <= 0 || !seen.add(workflow.id)) {
        continue;
      }
      if (await workflowSupportsDispatch(
        repositoryFullName: repositoryFullName,
        branch: branch,
        workflow: workflow,
      )) {
        return workflow;
      }
    }
    return null;
  }

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
    final allRuns = repositoryPage.runs;

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
    return result.runs;
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
