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
    this.errorHttpStatus,
    this.errorEndpoint,
    this.errorApiMessage,
    this.failureStage,
    this.failureOperation,
    this.failedFilePath,
    this.unchangedFiles = 0,
    this.changedFiles = 0,
    this.resumedFiles = 0,
    this.removedFiles = 0,
    this.uploadMethod = ProjectUploadMethod.incremental,
    this.fallbackCommitCount = 0,
    Map<String, String>? uploadedBlobShas,
    List<String>? changedFileSamples,
    List<String>? recoveryEvents,
    List<String>? logLines,
  }) : sourceZipPath = sourceZipPath ?? zipPath,
        uploadedBlobShas = Map<String, String>.from(
          uploadedBlobShas ?? const <String, String>{},
        ),
        changedFileSamples = List<String>.from(
          changedFileSamples ?? const <String>[],
        ),
        recoveryEvents = List<String>.from(
          recoveryEvents ?? const <String>[],
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
  int? errorHttpStatus;
  String? errorEndpoint;
  String? errorApiMessage;
  String? failureStage;
  String? failureOperation;
  String? failedFilePath;
  int unchangedFiles;
  int changedFiles;
  int resumedFiles;
  int removedFiles;
  ProjectUploadMethod uploadMethod;
  int fallbackCommitCount;
  final Map<String, String> uploadedBlobShas;
  final List<String> changedFileSamples;
  final List<String> recoveryEvents;
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

  String get failureOperationLabel {
    final value = failureOperation?.trim();
    if (value != null && value.isNotEmpty) return value;
    if (failureStage == 'build') return 'Inicialização da build';
    return 'Sincronização com o repositório';
  }

  String get githubFailureResponse {
    final parts = <String>[
      if (errorHttpStatus != null) 'HTTP $errorHttpStatus',
      if (errorApiMessage?.trim().isNotEmpty == true) errorApiMessage!.trim(),
    ];
    if (parts.isEmpty) return 'O GitHub não retornou detalhes adicionais.';
    return parts.join(' • ');
  }

  int get recoveryOperationEstimate =>
      changedFiles + resumedFiles + removedFiles;

  bool get canSuggestContentsRecovery =>
      recoveryOperationEstimate == 0 || recoveryOperationEstimate <= 12;

  ProjectUploadMethod? get recommendedRecoveryMethod {
    if (failureStage != 'upload') return null;
    final code = errorCode ?? '';
    final endpoint = (errorEndpoint ?? '').toLowerCase();

    if (code == 'NETWORK_REQUIRED' ||
        code == 'GITHUB_RATE_LIMIT' ||
        (code.startsWith('GITHUB_HTTP_') &&
            errorHttpStatus != null &&
            errorHttpStatus! >= 500)) {
      return uploadMethod;
    }
    if (code == 'UPLOAD_BRANCH_CHANGED' || code == 'GITHUB_CONFLICT') {
      return ProjectUploadMethod.incremental;
    }
    if (endpoint.contains('/git/trees') && code == 'GITHUB_VALIDATION') {
      return switch (uploadMethod) {
        ProjectUploadMethod.incremental => ProjectUploadMethod.fullTree,
        ProjectUploadMethod.fullTree => canSuggestContentsRecovery
            ? ProjectUploadMethod.contentsApi
            : null,
        ProjectUploadMethod.contentsApi => null,
      };
    }
    if (code == 'UPLOAD_CONTENTS_FALLBACK_UNAVAILABLE' ||
        code == 'UPLOAD_CONTENTS_FALLBACK_TOO_LARGE' ||
        code == 'UPLOAD_CONTENTS_FALLBACK_EXECUTABLE') {
      return ProjectUploadMethod.fullTree;
    }
    return null;
  }

  bool get hasAlternativeRecoveryMethod {
    final method = recommendedRecoveryMethod;
    return method != null && method != uploadMethod;
  }

  bool get shouldRetrySameMethod => recommendedRecoveryMethod == uploadMethod;

  String get recoveryRecommendationLabel {
    final method = recommendedRecoveryMethod;
    if (method == null) return 'Nenhum método alternativo foi identificado com segurança.';
    if (method == uploadMethod) {
      return 'A falha parece temporária. A recomendação é repetir ${uploadMethod.label.toLowerCase()}.';
    }
    return 'Próxima tentativa recomendada: ${method.label}.';
  }

  String get failureProgressExplanation {
    if (total <= 0) {
      return 'O envio parou durante “$failureOperationLabel”.';
    }
    final done = current.clamp(0, total);
    if (done >= total) {
      return 'Os $total arquivos do ZIP já tinham sido analisados. A falha aconteceu depois dessa análise, durante “$failureOperationLabel”.';
    }
    return 'O processo chegou a $done de $total arquivos antes de parar durante “$failureOperationLabel”.';
  }

  String? get failureRepositoryImpact {
    if (errorCode == 'UPLOAD_BRANCH_CHANGED') {
      final operation = (failureOperation ?? '').toLowerCase();
      if (operation.contains('publicar o commit')) {
        return 'O novo commit já pode ter sido criado como objeto Git, mas o GitHub Manager não moveu a branch porque detectou uma alteração concorrente. O conteúdo visível da branch foi preservado.';
      }
      return 'O GitHub Manager detectou que a branch mudou e interrompeu a tentativa antes de publicar sobre o novo estado. Uma nova tentativa refará toda a comparação.';
    }
    if (fallbackCommitCount > 0) {
      return 'O método de arquivos individuais já publicou $fallbackCommitCount commit(s) antes da falha. A branch pode estar parcialmente atualizada; a próxima tentativa deve refazer a comparação antes de continuar.';
    }
    if (uploadMethod == ProjectUploadMethod.contentsApi) {
      return 'O método de arquivos individuais cria um commit por operação. Se a conexão caiu depois de o GitHub aceitar a última chamada, a branch pode ter mudado mesmo sem resposta no aplicativo. A próxima tentativa reconsulta a branch antes de continuar.';
    }
    final endpoint = (errorEndpoint ?? '').toLowerCase();
    if (endpoint.contains('/git/trees')) {
      return 'A nova árvore não foi aceita; nenhum commit novo desta tentativa foi criado e a branch não foi alterada.';
    }
    if (endpoint.contains('/git/commits')) {
      return 'A branch não foi atualizada por esta tentativa, porque a criação do commit falhou.';
    }
    if (endpoint.contains('/git/refs/heads/')) {
      return 'O commit pode ter sido criado, mas a branch não foi movida para ele; os arquivos visíveis na branch permanecem no commit anterior.';
    }
    if (endpoint.contains('/git/blobs')) {
      return 'A falha ocorreu antes da criação do commit; a branch não foi atualizada por esta tentativa.';
    }
    return null;
  }

  String get failureMeaning {
    final code = errorCode ?? '';
    final endpoint = (errorEndpoint ?? '').toLowerCase();

    if (code == 'UPLOAD_BRANCH_CHANGED') {
      return 'A branch mudou enquanto o GitHub Manager preparava ou recuperava o envio. O aplicativo interrompeu a operação para não publicar sobre um estado diferente do que foi comparado.';
    }
    if (code == 'UPLOAD_CONTENTS_FALLBACK_UNAVAILABLE' ||
        code == 'UPLOAD_CONTENTS_FALLBACK_TOO_LARGE' ||
        code == 'UPLOAD_CONTENTS_FALLBACK_EXECUTABLE') {
      return errorMessage ?? 'O método de arquivos individuais não é seguro para este conjunto de alterações.';
    }
    if (code == 'AUTH_REQUIRED' || code == 'GITHUB_TOKEN_INVALID') {
      return 'A autenticação deixou de ser aceita pelo GitHub. O token pode ter expirado, sido revogado ou não estar mais disponível.';
    }
    if (code == 'GITHUB_RATE_LIMIT') {
      return 'O GitHub bloqueou temporariamente novas chamadas porque o limite da API foi atingido.';
    }
    if (code == 'GITHUB_PERMISSION') {
      return 'O GitHub recebeu a solicitação, mas o token não tem permissão suficiente para concluir esta operação.';
    }
    if (code == 'GITHUB_NOT_FOUND') {
      return 'O recurso usado nesta etapa não foi encontrado ou não está visível para o token atual.';
    }
    if (code == 'GITHUB_CONFLICT') {
      return 'O estado do repositório mudou durante o envio e o GitHub recusou continuar com dados que já não correspondem ao estado atual.';
    }
    if (code == 'GITHUB_VALIDATION') {
      if (endpoint.contains('/git/trees')) {
        return 'O GitHub recusou a árvore Git que reunia os arquivos do ZIP e as remoções detectadas. A falha ocorreu ao montar a nova estrutura do repositório, antes de criar o commit.';
      }
      if (endpoint.contains('/git/commits')) {
        return 'O GitHub recusou a criação do novo commit. A árvore já havia sido preparada, mas os dados do commit não passaram pela validação da API.';
      }
      if (endpoint.contains('/git/refs/heads/')) {
        return 'O commit foi preparado, mas o GitHub recusou atualizar a branch para apontar para ele. Proteções, rulesets ou uma mudança concorrente na branch podem causar esse tipo de rejeição.';
      }
      if (endpoint.contains('/git/blobs')) {
        return 'O GitHub recusou um dos conteúdos de arquivo enviados antes da criação da árvore do commit.';
      }
      if (endpoint.contains('/contents')) {
        return 'O GitHub recusou uma alteração de arquivo feita pela API de conteúdo do repositório.';
      }
      return 'O GitHub recebeu os dados, mas recusou a operação porque eles não passaram pelas regras de validação da API.';
    }
    if (code == 'NETWORK_REQUIRED') {
      return 'A comunicação com o GitHub foi interrompida ou não pôde ser estabelecida nesta etapa.';
    }
    if (code.startsWith('GITHUB_HTTP_')) {
      return 'O GitHub respondeu com um status HTTP que o aplicativo não classificou como um dos casos comuns. A resposta e o endpoint abaixo mostram exatamente qual chamada falhou.';
    }
    if (code.startsWith('UPLOAD_')) {
      return errorMessage ?? 'O GitHub Manager não conseguiu concluir esta etapa do envio.';
    }
    return 'O envio parou nesta etapa antes de ser concluído. Os detalhes técnicos abaixo ajudam a identificar a origem exata.';
  }

  String get failureSuggestedAction {
    final code = errorCode ?? '';
    final endpoint = (errorEndpoint ?? '').toLowerCase();

    if (code == 'UPLOAD_BRANCH_CHANGED') {
      return 'Tente novamente pelo método incremental. O projeto será comparado de novo com o SHA atual da branch antes de qualquer publicação.';
    }
    if (code == 'UPLOAD_CONTENTS_FALLBACK_UNAVAILABLE' ||
        code == 'UPLOAD_CONTENTS_FALLBACK_TOO_LARGE' ||
        code == 'UPLOAD_CONTENTS_FALLBACK_EXECUTABLE') {
      return 'Use a reconstrução da árvore ou corrija a causa indicada. O GitHub Manager não fará atualização individual quando houver risco de perder modo executável, exceder o limite seguro ou gerar alterações demais.';
    }
    if (code == 'AUTH_REQUIRED' || code == 'GITHUB_TOKEN_INVALID') {
      return 'Reconecte a conta ou gere um token válido e tente novamente.';
    }
    if (code == 'GITHUB_RATE_LIMIT') {
      return 'Aguarde o limite da API liberar e tente novamente depois.';
    }
    if (code == 'GITHUB_PERMISSION') {
      return 'Abra o Diagnóstico do token e confirme principalmente a permissão Contents: write para este repositório.';
    }
    if (code == 'GITHUB_NOT_FOUND') {
      return 'Confirme o repositório, a branch e se o token possui acesso a esse repositório.';
    }
    if (code == 'GITHUB_CONFLICT') {
      return 'Atualize os dados do repositório e tente novamente para refazer a sincronização sobre o estado atual.';
    }
    if (code == 'GITHUB_VALIDATION') {
      if (endpoint.contains('/git/refs/heads/')) {
        return 'Confira as regras/proteções da branch e tente novamente. Se a branch mudou durante o envio, uma nova tentativa refaz a comparação.';
      }
      if (endpoint.contains('/git/trees')) {
        if (uploadMethod == ProjectUploadMethod.incremental) {
          return 'O método incremental foi recusado. Use “Tentar método alternativo” para reconstruir a árvore final do projeto sem reaproveitar a árvore anterior.';
        }
        if (uploadMethod == ProjectUploadMethod.fullTree) {
          if (!canSuggestContentsRecovery) {
            return 'A reconstrução completa também foi recusada. O método individual não é recomendado porque foram detectadas cerca de $recoveryOperationEstimate alterações, acima do limite seguro de 12 operações. Copie o diagnóstico para investigar a validação retornada pelo GitHub.';
          }
          return 'A reconstrução completa também foi recusada. O conjunto de mudanças é pequeno o suficiente para oferecer, manualmente, a API de arquivos individuais; o método ainda fará validações de tamanho, modo executável e tipo Git antes de alterar a branch.';
        }
        return 'O método individual também falhou. Copie o diagnóstico antes de repetir para evitar uma sequência de commits parciais.';
      }
      return 'Tente novamente uma vez. Se a rejeição se repetir, copie o diagnóstico completo para identificar a validação exata retornada pelo GitHub.';
    }
    if (code == 'NETWORK_REQUIRED') {
      return 'Verifique a conexão e tente novamente. O checkpoint evita reenviar o que já foi concluído quando possível.';
    }
    if (code.startsWith('GITHUB_HTTP_')) {
      if (errorHttpStatus != null && errorHttpStatus! >= 500) {
        return 'Tente novamente depois de alguns instantes. Se continuar, copie o diagnóstico para conferir a resposta do serviço do GitHub.';
      }
      return 'Confira a resposta do GitHub e o endpoint nos detalhes técnicos. Se repetir, copie o diagnóstico antes de tentar novamente.';
    }
    return 'Tente novamente. Se a falha persistir, use “Copiar diagnóstico” para registrar a etapa, o código e a resposta recebida.';
  }

  String get failureDiagnosticText {
    final lines = <String>[
      'DIAGNÓSTICO DA FALHA',
      'Onde parou: $failureOperationLabel',
      'Método usado: ${uploadMethod.label}',
      'Progresso: $failureProgressExplanation',
      'Recomendação: $recoveryRecommendationLabel',
      if (failureRepositoryImpact != null) 'Impacto: $failureRepositoryImpact',
      if (failureStage?.isNotEmpty == true) 'Etapa interna: $failureStage',
      if (failedFilePath?.isNotEmpty == true) 'Arquivo: $failedFilePath',
      if (errorCode?.isNotEmpty == true) 'Código: $errorCode',
      if (errorHttpStatus != null) 'HTTP: $errorHttpStatus',
      if (errorEndpoint?.isNotEmpty == true) 'Endpoint: $errorEndpoint',
      if (errorApiMessage?.isNotEmpty == true) 'GitHub: $errorApiMessage',
      if (errorMessage?.isNotEmpty == true) 'Mensagem do app: $errorMessage',
      if (recoveryEvents.isNotEmpty) ...[
        '',
        'Tentativas de recuperação:',
        ...recoveryEvents.map((event) => '• $event'),
      ],
      '',
      'O que significa:',
      failureMeaning,
      '',
      'O que fazer:',
      failureSuggestedAction,
    ];
    return lines.join('\n');
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
    fallbackCommitCount = 0;
    changedFileSamples.clear();
  }

  void recordProgress(ProjectUploadProgress progress) {
    if (progress.method != null) {
      uploadMethod = progress.method!;
    }
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
      case ProjectUploadProgressKind.recovery:
        _addRecoveryEvent(progress.phase);
        break;
      case ProjectUploadProgressKind.commitCreated:
        fallbackCommitCount += progress.affectedCount <= 0 ? 1 : progress.affectedCount;
        _addRecoveryEvent(progress.phase);
        break;
      case ProjectUploadProgressKind.stage:
      case ProjectUploadProgressKind.transferStarted:
        break;
    }
  }

  void _addRecoveryEvent(String value) {
    final text = value.trim();
    if (text.isEmpty || (recoveryEvents.isNotEmpty && recoveryEvents.last == text)) {
      return;
    }
    recoveryEvents.add(text);
    if (recoveryEvents.length > 20) {
      recoveryEvents.removeRange(0, recoveryEvents.length - 20);
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
    errorHttpStatus = null;
    errorEndpoint = null;
    errorApiMessage = null;
    failureStage = null;
    failureOperation = null;
    failedFilePath = null;
    addLog(
      buildOnly
          ? 'Retomada automática: commit já existente, seguindo para a build'
          : uploadedBlobShas.isEmpty
              ? 'Retomada automática do envio iniciada'
              : 'Retomada automática usando ${uploadedBlobShas.length} blob(s) do checkpoint',
    );
  }

  void resetForRetry({
    required bool buildOnly,
    ProjectUploadMethod? method,
  }) {
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
    errorHttpStatus = null;
    errorEndpoint = null;
    errorApiMessage = null;
    failureStage = null;
    failureOperation = null;
    failedFilePath = null;
    fallbackCommitCount = 0;
    if (!buildOnly && method != null) {
      uploadMethod = method;
    }
    if (!buildOnly) {
      commitSha = null;
      changed = null;
      workflowName = null;
      workflowPath = null;
      workflowRunId = null;
      dispatchTriggered = null;
    }
    addLog(
      buildOnly
          ? 'Nova tentativa da build solicitada'
          : 'Reenvio solicitado • método: ${uploadMethod.label}',
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
        'errorHttpStatus': errorHttpStatus,
        'errorEndpoint': errorEndpoint,
        'errorApiMessage': errorApiMessage,
        'failureStage': failureStage,
        'failureOperation': failureOperation,
        'failedFilePath': failedFilePath,
        'unchangedFiles': unchangedFiles,
        'changedFiles': changedFiles,
        'resumedFiles': resumedFiles,
        'removedFiles': removedFiles,
        'uploadMethod': uploadMethod.name,
        'fallbackCommitCount': fallbackCommitCount,
        'uploadedBlobShas': uploadedBlobShas,
        'changedFileSamples': changedFileSamples,
        'recoveryEvents': recoveryEvents,
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
      errorHttpStatus: (json['errorHttpStatus'] as num?)?.toInt(),
      errorEndpoint: json['errorEndpoint']?.toString(),
      errorApiMessage: json['errorApiMessage']?.toString(),
      failureStage: json['failureStage']?.toString(),
      failureOperation: json['failureOperation']?.toString(),
      failedFilePath: json['failedFilePath']?.toString(),
      unchangedFiles: (json['unchangedFiles'] as num?)?.toInt() ?? 0,
      changedFiles: (json['changedFiles'] as num?)?.toInt() ?? 0,
      resumedFiles: (json['resumedFiles'] as num?)?.toInt() ?? 0,
      removedFiles: (json['removedFiles'] as num?)?.toInt() ?? 0,
      uploadMethod: ProjectUploadMethod.values.firstWhere(
        (value) => value.name == json['uploadMethod']?.toString(),
        orElse: () => ProjectUploadMethod.incremental,
      ),
      fallbackCommitCount: (json['fallbackCommitCount'] as num?)?.toInt() ?? 0,
      uploadedBlobShas: (json['uploadedBlobShas'] as Map?)?.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          ) ??
          <String, String>{},
      changedFileSamples: (json['changedFileSamples'] as List?)
              ?.map((value) => value.toString())
              .toList(growable: true) ??
          <String>[],
      recoveryEvents: (json['recoveryEvents'] as List?)
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
