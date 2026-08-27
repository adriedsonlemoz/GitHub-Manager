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
    Map<String, String>? uploadedBlobShas,
    List<String>? logLines,
  }) : sourceZipPath = sourceZipPath ?? zipPath,
        uploadedBlobShas = Map<String, String>.from(
          uploadedBlobShas ?? const <String, String>{},
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
  final Map<String, String> uploadedBlobShas;
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
    return <String>[
      'GitHub Manager — log de envio',
      'Data/hora: ${when.toLocal().toIso8601String()}',
      'Projeto: $projectName',
      'Versão: $versionLabel',
      'Repositório: $repositoryFullName',
      'Branch: $branch',
      'ZIP: $zipName',
      if (zipPath != sourceZipPath) 'Cópia segura: ativa',
      'Status: $statusLabel',
      'Etapa: $phase',
      if (commitSha != null) 'Commit: $commitSha',
      if (workflowName != null) 'Workflow: $workflowName',
      if (workflowPath != null) 'Workflow path: $workflowPath',
      if (workflowRunId != null) 'Workflow run ID: $workflowRunId',
      if (dispatchTriggered != null)
        'Dispatch manual: ${dispatchTriggered! ? 'sim' : 'não'}',
      if (failureStage != null) 'Falha na etapa: $failureStage',
      if (uploadedBlobShas.isNotEmpty)
        'Checkpoint de blobs: ${uploadedBlobShas.length}',
      if (errorCode != null) 'Código interno: $errorCode',
      if (errorMessage != null) 'Erro: $errorMessage',
      if (logLines.isNotEmpty) ...[
        '',
        'Processo:',
        ...logLines.map((line) => '- $line'),
      ],
    ].join('\n');
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
        'uploadedBlobShas': uploadedBlobShas,
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
      uploadedBlobShas: (json['uploadedBlobShas'] as Map?)?.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          ) ??
          <String, String>{},
      logLines: (json['logLines'] as List?)
              ?.map((value) => value.toString())
              .toList(growable: true) ??
          <String>[],
    );
  }
}
