part of 'managed_upload.dart';

class _ManagedUploadReport {
  const _ManagedUploadReport(this.item);

  final ManagedUpload item;

  List<String> get logLines => item.logLines;
  String get branch => item.branch;
  DateTime? get completedAt => item.completedAt;
  DateTime? get failedAt => item.failedAt;
  DateTime? get startedAt => item.startedAt;
  DateTime get createdAt => item.createdAt;
  ManagedUploadStatus get status => item.status;
  String get statusLabel => item.statusLabel;
  String get phase => item.phase;
  String get projectName => item.projectName;
  String get versionLabel => item.versionLabel;
  String get repositoryFullName => item.repositoryFullName;
  String get elapsedLabel => item.elapsedLabel;
  String get zipName => item.zipName;
  ProjectUploadMethod get uploadMethod => item.uploadMethod;
  String get zipPath => item.zipPath;
  String get sourceZipPath => item.sourceZipPath;
  int get analyzedFiles => item.analyzedFiles;
  int get fileCount => item.fileCount;
  int get unchangedFiles => item.unchangedFiles;
  int get sentFiles => item.sentFiles;
  int get resumedFiles => item.resumedFiles;
  int get removedFiles => item.removedFiles;
  List<String> get changedFileSamples => item.changedFileSamples;
  int get changedFiles => item.changedFiles;
  String? get commitSha => item.commitSha;
  String get buildTriggerLabel => item.buildTriggerLabel;
  String? get workflowName => item.workflowName;
  String? get workflowPath => item.workflowPath;
  int? get workflowRunId => item.workflowRunId;
  Map<String, String> get uploadedBlobShas => item.uploadedBlobShas;
  String? get failureStage => item.failureStage;
  String? get failureOperation => item.failureOperation;
  String? get failedFilePath => item.failedFilePath;
  String? get errorCode => item.errorCode;
  int? get errorHttpStatus => item.errorHttpStatus;
  String? get errorEndpoint => item.errorEndpoint;
  String? get errorApiMessage => item.errorApiMessage;
  String? get errorMessage => item.errorMessage;
  List<String> get recoveryEvents => item.recoveryEvents;
  String get failureDiagnosticText => item.failureDiagnosticText;

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
      'Método de sincronização: ${uploadMethod.label}',
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
      if (failureOperation?.isNotEmpty == true) 'Onde parou: $failureOperation',
      if (failedFilePath?.isNotEmpty == true) 'Arquivo da falha: $failedFilePath',
      if (errorCode != null) 'Código interno: $errorCode',
      if (errorHttpStatus != null) 'HTTP: $errorHttpStatus',
      if (errorEndpoint?.isNotEmpty == true) 'Endpoint: $errorEndpoint',
      if (errorApiMessage?.isNotEmpty == true) 'Resposta do GitHub: $errorApiMessage',
      if (errorMessage != null) 'Erro: $errorMessage',
      if (recoveryEvents.isNotEmpty) ...[
        '',
        'RECUPERAÇÃO',
        ...recoveryEvents.map((event) => '• $event'),
      ],
      if (errorMessage != null) ...[
        '',
        failureDiagnosticText,
      ],
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
        ManagedUploadStatus.buildPending => '!',
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

}
