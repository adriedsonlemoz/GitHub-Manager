import 'package:github_manager/features/projects/domain/zip_project.dart';

enum ManagedUploadStatus {
  queued,
  syncing,
  startingBuild,
  completed,
  noChanges,
  failed,
  interrupted,
}

class ManagedUpload {
  ManagedUpload({
    required this.id,
    required this.repositoryFullName,
    required this.branch,
    required this.zipPath,
    String? sourceZipPath,
    required this.zipName,
    required this.projectName,
    required this.projectType,
    required this.archiveBytes,
    required this.uncompressedBytes,
    required this.fileCount,
    required this.folderCount,
    required this.importantFiles,
    required this.commonRoot,
    required this.status,
    required this.createdAt,
    this.packageName,
    this.applicationId,
    this.version,
    this.versionCode,
    this.phase = 'Aguardando envio',
    this.current = 0,
    this.total = 0,
    this.currentFile,
    this.startedAt,
    this.completedAt,
    this.failedAt,
    this.commitSha,
    this.changed,
    this.workflowName,
    this.workflowPath,
    this.workflowRunId,
    this.dispatchTriggered,
    this.errorMessage,
    this.errorCode,
    this.failureStage,
    this.failedFilePath,
    this.unchangedFiles = 0,
    this.changedFiles = 0,
    this.resumedFiles = 0,
    this.removedFiles = 0,
    Map<String, String>? uploadedBlobShas,
    List<String>? changedFileSamples,
    List<String>? logLines,
  }) : sourceZipPath = sourceZipPath ?? zipPath,
        uploadedBlobShas = Map<String, String>.from(
          uploadedBlobShas ?? const <String, String>{},
        ),
        changedFileSamples = List<String>.from(
          changedFileSamples ?? const <String>[],
        ),
        logLines = logLines ?? <String>[];

  final String id;
  final String repositoryFullName;
  final String branch;
  String zipPath;
  final String sourceZipPath;
  final String zipName;
  final String projectName;
  final String projectType;
  final int archiveBytes;
  final int uncompressedBytes;
  final int fileCount;
  final int folderCount;
  final List<String> importantFiles;
  final String? commonRoot;
  final String? packageName;
  final String? applicationId;
  final String? version;
  final int? versionCode;
  ManagedUploadStatus status;
  final DateTime createdAt;
  String phase;
  int current;
  int total;
  String? currentFile;
  DateTime? startedAt;
  DateTime? completedAt;
  DateTime? failedAt;
  String? commitSha;
  bool? changed;
  String? workflowName;
  String? workflowPath;
  int? workflowRunId;
  bool? dispatchTriggered;
  String? errorMessage;
  String? errorCode;
  String? failureStage;
  String? failedFilePath;
  int unchangedFiles;
  int changedFiles;
  int resumedFiles;
  int removedFiles;
  final Map<String, String> uploadedBlobShas;
  final List<String> changedFileSamples;
  final List<String> logLines;

  bool get isActive =>
      status == ManagedUploadStatus.queued ||
      status == ManagedUploadStatus.syncing ||
      status == ManagedUploadStatus.startingBuild;

  bool get canRetry =>
      status == ManagedUploadStatus.failed ||
      status == ManagedUploadStatus.interrupted;

  bool get canRunBuildAnyway =>
      status == ManagedUploadStatus.noChanges &&
      commitSha != null &&
      commitSha!.isNotEmpty;

  bool get hasCheckpoint =>
      uploadedBlobShas.isNotEmpty || (commitSha?.isNotEmpty ?? false);

  bool get hasBuildCheckpoint {
    if (commitSha?.isNotEmpty != true) return false;
    if (status == ManagedUploadStatus.startingBuild || changed == true) {
      return true;
    }
    return phase.toLowerCase().contains('build');
  }

  String get checkpointLabel {
    if (commitSha?.isNotEmpty == true) {
      return 'Commit salvo • retomada direta da build disponível';
    }
    if (uploadedBlobShas.isNotEmpty) {
      return '${uploadedBlobShas.length} arquivo(s) já enviado(s) no checkpoint';
    }
    return 'Checkpoint preparado';
  }

  int get analyzedFiles => unchangedFiles + changedFiles + resumedFiles;

  /// Arquivos que precisaram ser sincronizados com conteúdo novo nesta tentativa.
  int get sentFiles => changedFiles;

  String get syncSummaryLabel {
    if (fileCount <= 0) return 'Sem arquivos contabilizados';
    if (analyzedFiles <= 0) return '$fileCount arquivos no ZIP';
    final parts = <String>[
      '$analyzedFiles analisados',
      if (sentFiles > 0) '$sentFiles enviados',
      if (unchangedFiles > 0) '$unchangedFiles já atualizados',
      if (resumedFiles > 0) '$resumedFiles retomados',
      if (removedFiles > 0) '$removedFiles removidos',
    ];
    return parts.join(' • ');
  }

  Duration? get elapsed {
    final start = startedAt;
    if (start == null) return null;
    final end = completedAt ?? failedAt ?? DateTime.now();
    final value = end.difference(start);
    return value.isNegative ? Duration.zero : value;
  }

  String get elapsedLabel {
    final value = elapsed;
    if (value == null) return '—';
    final seconds = value.inSeconds;
    if (seconds < 60) return '${seconds}s';
    final minutes = value.inMinutes;
    final remainingSeconds = seconds % 60;
    if (minutes < 60) return '${minutes}min ${remainingSeconds}s';
    final hours = value.inHours;
    final remainingMinutes = minutes % 60;
    return '${hours}h ${remainingMinutes}min';
  }

  String get buildTriggerLabel {
    if (workflowRunId == null && workflowName == null) return 'Não iniciada';
    if (dispatchTriggered == true) return 'Iniciada manualmente';
    if (dispatchTriggered == false) return 'Iniciada automaticamente pelo push';
    return 'Iniciada';
  }

  List<String> get timelineLines {
    final result = <String>[];
    for (final line in logLines) {
      final lower = line.toLowerCase();
      if (lower.startsWith('arquivo já está atualizado:') ||
          lower.startsWith('processando arquivos do projeto:') ||
          lower.startsWith('enviando arquivo para o github:') ||
          lower.startsWith('retomando arquivo já enviado:') ||
          lower.startsWith('checkpoint salvo:')) {
        continue;
      }
      final friendly = _friendlyTimelineLine(line);
      if (friendly.isEmpty || (result.isNotEmpty && result.last == friendly)) {
        continue;
      }
      result.add(friendly);
    }
    return result;
  }

  String _friendlyTimelineLine(String line) {
    final normalized = line.trim();
    if (normalized == 'Preparando arquivo durável para o envio') {
      return 'Preparando uma cópia segura do ZIP';
    }
    if (normalized == 'Cópia segura do ZIP pronta para retomada') {
      return 'ZIP protegido para retomada em caso de interrupção';
    }
    if (normalized == 'Sincronização iniciada') {
      return 'Comparando o projeto com o repositório';
    }
    if (normalized == 'Preparando branch') {
      return 'Branch $branch localizada';
    }
    if (normalized == 'Preparando sincronização no GitHub') {
      return 'Comparação de arquivos concluída';
    }
    if (normalized == 'Criando commit') {
      return 'Criando commit com as alterações';
    }
    if (normalized == 'Atualizando branch') {
      return 'Publicando o commit na branch $branch';
    }
    if (normalized == 'Checkpoint do commit salvo em disco') {
      return 'Commit salvo para permitir retomada segura';
    }
    if (normalized == 'Concluído') {
      return '';
    }
    return normalized;
  }

  void resetFileSummary() {
    unchangedFiles = 0;
    changedFiles = 0;
    resumedFiles = 0;
    removedFiles = 0;
    changedFileSamples.clear();
  }

  void recordProgress(ProjectUploadProgress progress) {
    switch (progress.kind) {
      case ProjectUploadProgressKind.unchanged:
        unchangedFiles++;
        break;
      case ProjectUploadProgressKind.changed:
        changedFiles++;
        final path = progress.fileName?.trim();
        if (path != null &&
            path.isNotEmpty &&
            changedFileSamples.length < 20 &&
            !changedFileSamples.contains(path)) {
          changedFileSamples.add(path);
        }
        break;
      case ProjectUploadProgressKind.resumed:
        resumedFiles++;
        break;
      case ProjectUploadProgressKind.removed:
        removedFiles = progress.affectedCount;
        break;
      case ProjectUploadProgressKind.stage:
      case ProjectUploadProgressKind.transferStarted:
        break;
    }
  }

  double? get progress {
    if (status == ManagedUploadStatus.startingBuild) {
      return null;
    }
    if (total <= 0) {
      return null;
    }
    return (current / total).clamp(0, 1).toDouble();
  }

  String get versionLabel {
    final value = version?.trim();
    if (value == null || value.isEmpty) return 'Não identificada';
    if (versionCode == null || value.contains('+')) return value;
    return '$value+$versionCode';
  }

  String get statusLabel => switch (status) {
        ManagedUploadStatus.queued => 'Na fila',
        ManagedUploadStatus.syncing => 'Enviando',
        ManagedUploadStatus.startingBuild => 'Iniciando build',
        ManagedUploadStatus.completed => 'Concluído',
        ManagedUploadStatus.noChanges => 'Sem alterações',
        ManagedUploadStatus.failed => 'Falhou',
        ManagedUploadStatus.interrupted => 'Interrompido',
      };

  ZipProjectPreview toProjectPreview() => ZipProjectPreview(
        path: zipPath,
        name: zipName,
        archiveBytes: archiveBytes,
        uncompressedBytes: uncompressedBytes,
        fileCount: fileCount,
        folderCount: folderCount,
        projectType: projectType,
        importantFiles: List<String>.from(importantFiles),
        commonRoot: commonRoot,
        projectName: projectName,
        packageName: packageName,
        applicationId: applicationId,
        version: version,
        versionCode: versionCode,
      );

  void addLog(String text) {
    final value = text.trim();
    if (value.isEmpty || (logLines.isNotEmpty && logLines.last == value)) {
      return;
    }
    logLines.add(value);
    if (logLines.length > 40) {
      logLines.removeRange(0, logLines.length - 40);
    }
  }

  void markInterruptedByAppExit() {
    final previousStatus = status;
    status = ManagedUploadStatus.interrupted;
    failedAt = DateTime.now();
    phase = 'Envio interrompido';
    currentFile = null;
    errorMessage =
        'O envio foi interrompido porque o aplicativo foi encerrado antes da conclusão.';
    errorCode = 'UPLOAD_APP_INTERRUPTED';
    failureStage = failureStage ??
        (previousStatus == ManagedUploadStatus.startingBuild
            ? 'build'
            : 'upload');
    addLog('Envio interrompido ao encerrar o aplicativo');
  }

  void prepareAutomaticResume({required bool buildOnly}) {
    status = ManagedUploadStatus.queued;
    phase = buildOnly
        ? 'Retomando a build pelo checkpoint'
        : 'Retomando envio pelo checkpoint';
    current = buildOnly ? fileCount : 0;
    total = fileCount;
    currentFile = null;
    completedAt = null;
    failedAt = null;
    errorMessage = null;
    errorCode = null;
    failureStage = null;
    failedFilePath = null;
    addLog(
      buildOnly
          ? 'Retomada automática: commit já existente, seguindo para a build'
          : uploadedBlobShas.isEmpty
              ? 'Retomada automática do envio iniciada'
              : 'Retomada automática usando ${uploadedBlobShas.length} blob(s) do checkpoint',
    );
  }

  void resetForRetry({required bool buildOnly}) {
    status = ManagedUploadStatus.queued;
    phase = buildOnly
        ? 'Aguardando nova tentativa da build'
        : 'Aguardando reenvio';
    current = buildOnly ? fileCount : 0;
    total = fileCount;
    currentFile = null;
    startedAt = null;
    completedAt = null;
    failedAt = null;
    errorMessage = null;
    errorCode = null;
    failureStage = null;
    failedFilePath = null;
    if (!buildOnly) {
      commitSha = null;
      changed = null;
      workflowName = null;
      workflowPath = null;
      workflowRunId = null;
      dispatchTriggered = null;
    }
    addLog(
      buildOnly ? 'Nova tentativa da build solicitada' : 'Reenvio solicitado',
    );
  }

  String get technicalLog {
    final when = completedAt ?? failedAt ?? startedAt ?? createdAt;
    final lines = <String>[
      'GITHUB MANAGER • RELATÓRIO DE ENVIO',
      '==================================',
      '',
      '${_statusSymbol()} $statusLabel'.toUpperCase(),
      phase,
      '',
      'RESUMO',
      'Projeto: $projectName',
      'Versão: $versionLabel',
      'Repositório: $repositoryFullName',
      'Branch: $branch',
      'Data: ${_formatDateTime(when)}',
      'Duração: $elapsedLabel',
      'ZIP: $zipName',
      if (zipPath != sourceZipPath) 'Cópia segura: ativa',
      '',
      'ARQUIVOS',
      'Analisados: ${analyzedFiles > 0 ? analyzedFiles : fileCount}',
      'Já atualizados: $unchangedFiles',
      'Alterados nesta tentativa: $sentFiles',
      'Retomados do checkpoint: $resumedFiles',
      'Removidos do repositório: $removedFiles',
      if (changedFileSamples.isNotEmpty) ...[
        '',
        'Arquivos alterados${changedFiles > changedFileSamples.length ? ' (amostra)' : ''}:',
        ...changedFileSamples.map((path) => '• $path'),
      ],
      '',
      'GITHUB',
      if (commitSha?.isNotEmpty == true) 'Commit: $commitSha',
      if (commitSha?.isNotEmpty == true) 'Commit curto: ${_shortSha(commitSha!)}',
      'Build: $buildTriggerLabel',
      if (workflowName?.isNotEmpty == true) 'Workflow: $workflowName',
      if (workflowPath?.isNotEmpty == true) 'Arquivo do workflow: $workflowPath',
      if (workflowRunId != null) 'Run ID: $workflowRunId',
      if (uploadedBlobShas.isNotEmpty)
        'Checkpoint ativo: ${uploadedBlobShas.length} blob(s)',
      if (failureStage != null) 'Falha na etapa: $failureStage',
      if (failedFilePath?.isNotEmpty == true) 'Arquivo da falha: $failedFilePath',
      if (errorCode != null) 'Código interno: $errorCode',
      if (errorMessage != null) 'Erro: $errorMessage',
      if (timelineLines.isNotEmpty) ...[
        '',
        'LINHA DO TEMPO',
        ...timelineLines.map((line) => '• $line'),
      ],
    ];
    return lines.join('\n');
  }

  String _statusSymbol() => switch (status) {
        ManagedUploadStatus.completed => '✓',
        ManagedUploadStatus.noChanges => '•',
        ManagedUploadStatus.failed => '✕',
        ManagedUploadStatus.interrupted => '!',
        ManagedUploadStatus.queued => '…',
        ManagedUploadStatus.syncing => '↑',
        ManagedUploadStatus.startingBuild => '▶',
      };

  static String _shortSha(String sha) =>
      sha.length > 7 ? sha.substring(0, 7) : sha;

  static String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'repositoryFullName': repositoryFullName,
        'branch': branch,
        'zipPath': zipPath,
        'sourceZipPath': sourceZipPath,
        'zipName': zipName,
        'projectName': projectName,
        'projectType': projectType,
        'archiveBytes': archiveBytes,
        'uncompressedBytes': uncompressedBytes,
        'fileCount': fileCount,
        'folderCount': folderCount,
        'importantFiles': importantFiles,
        'commonRoot': commonRoot,
        'packageName': packageName,
        'applicationId': applicationId,
        'version': version,
        'versionCode': versionCode,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'phase': phase,
        'current': current,
        'total': total,
        'currentFile': currentFile,
        'startedAt': startedAt?.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'failedAt': failedAt?.toIso8601String(),
        'commitSha': commitSha,
        'changed': changed,
        'workflowName': workflowName,
        'workflowPath': workflowPath,
        'workflowRunId': workflowRunId,
        'dispatchTriggered': dispatchTriggered,
        'errorMessage': errorMessage,
        'errorCode': errorCode,
        'failureStage': failureStage,
        'failedFilePath': failedFilePath,
        'unchangedFiles': unchangedFiles,
        'changedFiles': changedFiles,
        'resumedFiles': resumedFiles,
        'removedFiles': removedFiles,
        'uploadedBlobShas': uploadedBlobShas,
        'changedFileSamples': changedFileSamples,
        'logLines': logLines,
      };

  factory ManagedUpload.fromJson(Map<String, dynamic> json) {
    final statusName = json['status']?.toString();
    return ManagedUpload(
      id: json['id']?.toString() ?? '',
      repositoryFullName: json['repositoryFullName']?.toString() ?? '',
      branch: json['branch']?.toString() ?? 'main',
      zipPath: json['zipPath']?.toString() ?? '',
      sourceZipPath: json['sourceZipPath']?.toString() ??
          json['zipPath']?.toString() ??
          '',
      zipName: json['zipName']?.toString() ?? 'projeto.zip',
      projectName: json['projectName']?.toString() ?? 'Projeto',
      projectType: json['projectType']?.toString() ?? 'Projeto',
      archiveBytes: (json['archiveBytes'] as num?)?.toInt() ?? 0,
      uncompressedBytes: (json['uncompressedBytes'] as num?)?.toInt() ?? 0,
      fileCount: (json['fileCount'] as num?)?.toInt() ?? 0,
      folderCount: (json['folderCount'] as num?)?.toInt() ?? 0,
      importantFiles: (json['importantFiles'] as List?)
              ?.map((value) => value.toString())
              .toList(growable: false) ??
          const <String>[],
      commonRoot: json['commonRoot']?.toString(),
      packageName: json['packageName']?.toString(),
      applicationId: json['applicationId']?.toString(),
      version: json['version']?.toString(),
      versionCode: (json['versionCode'] as num?)?.toInt(),
      status: ManagedUploadStatus.values.firstWhere(
        (value) => value.name == statusName,
        orElse: () => ManagedUploadStatus.interrupted,
      ),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      phase: json['phase']?.toString() ?? 'Aguardando envio',
      current: (json['current'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt() ?? 0,
      currentFile: json['currentFile']?.toString(),
      startedAt: DateTime.tryParse(json['startedAt']?.toString() ?? ''),
      completedAt: DateTime.tryParse(json['completedAt']?.toString() ?? ''),
      failedAt: DateTime.tryParse(json['failedAt']?.toString() ?? ''),
      commitSha: json['commitSha']?.toString(),
      changed: json['changed'] as bool?,
      workflowName: json['workflowName']?.toString(),
      workflowPath: json['workflowPath']?.toString(),
      workflowRunId: (json['workflowRunId'] as num?)?.toInt(),
      dispatchTriggered: json['dispatchTriggered'] as bool?,
      errorMessage: json['errorMessage']?.toString(),
      errorCode: json['errorCode']?.toString(),
      failureStage: json['failureStage']?.toString(),
      failedFilePath: json['failedFilePath']?.toString(),
      unchangedFiles: (json['unchangedFiles'] as num?)?.toInt() ?? 0,
      changedFiles: (json['changedFiles'] as num?)?.toInt() ?? 0,
      resumedFiles: (json['resumedFiles'] as num?)?.toInt() ?? 0,
      removedFiles: (json['removedFiles'] as num?)?.toInt() ?? 0,
      uploadedBlobShas: (json['uploadedBlobShas'] as Map?)?.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          ) ??
          <String, String>{},
      changedFileSamples: (json['changedFileSamples'] as List?)
              ?.map((value) => value.toString())
              .toList(growable: true) ??
          <String>[],
      logLines: (json['logLines'] as List?)
              ?.map((value) => value.toString())
              .toList(growable: true) ??
          <String>[],
    );
  }
}
