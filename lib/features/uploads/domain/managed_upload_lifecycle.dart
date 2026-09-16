part of 'managed_upload.dart';

class _ManagedUploadLifecycle {
  const _ManagedUploadLifecycle(this.item);

  final ManagedUpload item;

  int get unchangedFiles => item.unchangedFiles;
  set unchangedFiles(int value) => item.unchangedFiles = value;
  int get changedFiles => item.changedFiles;
  set changedFiles(int value) => item.changedFiles = value;
  int get resumedFiles => item.resumedFiles;
  set resumedFiles(int value) => item.resumedFiles = value;
  int get removedFiles => item.removedFiles;
  set removedFiles(int value) => item.removedFiles = value;
  int get fallbackCommitCount => item.fallbackCommitCount;
  set fallbackCommitCount(int value) => item.fallbackCommitCount = value;
  List<String> get changedFileSamples => item.changedFileSamples;
  List<String> get recoveryEvents => item.recoveryEvents;
  List<String> get logLines => item.logLines;
  Map<String, String> get uploadedBlobShas => item.uploadedBlobShas;
  int get fileCount => item.fileCount;

  ProjectUploadMethod get uploadMethod => item.uploadMethod;
  set uploadMethod(ProjectUploadMethod value) => item.uploadMethod = value;
  ManagedUploadStatus get status => item.status;
  set status(ManagedUploadStatus value) => item.status = value;
  String get phase => item.phase;
  set phase(String value) => item.phase = value;
  int get current => item.current;
  set current(int value) => item.current = value;
  int get total => item.total;
  set total(int value) => item.total = value;
  String? get currentFile => item.currentFile;
  set currentFile(String? value) => item.currentFile = value;
  DateTime? get startedAt => item.startedAt;
  set startedAt(DateTime? value) => item.startedAt = value;
  DateTime? get completedAt => item.completedAt;
  set completedAt(DateTime? value) => item.completedAt = value;
  DateTime? get failedAt => item.failedAt;
  set failedAt(DateTime? value) => item.failedAt = value;
  String? get commitSha => item.commitSha;
  set commitSha(String? value) => item.commitSha = value;
  bool? get changed => item.changed;
  set changed(bool? value) => item.changed = value;
  String? get workflowName => item.workflowName;
  set workflowName(String? value) => item.workflowName = value;
  String? get workflowPath => item.workflowPath;
  set workflowPath(String? value) => item.workflowPath = value;
  int? get workflowRunId => item.workflowRunId;
  set workflowRunId(int? value) => item.workflowRunId = value;
  bool? get dispatchTriggered => item.dispatchTriggered;
  set dispatchTriggered(bool? value) => item.dispatchTriggered = value;
  String? get errorMessage => item.errorMessage;
  set errorMessage(String? value) => item.errorMessage = value;
  String? get errorCode => item.errorCode;
  set errorCode(String? value) => item.errorCode = value;
  int? get errorHttpStatus => item.errorHttpStatus;
  set errorHttpStatus(int? value) => item.errorHttpStatus = value;
  String? get errorEndpoint => item.errorEndpoint;
  set errorEndpoint(String? value) => item.errorEndpoint = value;
  String? get errorApiMessage => item.errorApiMessage;
  set errorApiMessage(String? value) => item.errorApiMessage = value;
  String? get failureStage => item.failureStage;
  set failureStage(String? value) => item.failureStage = value;
  String? get failureOperation => item.failureOperation;
  set failureOperation(String? value) => item.failureOperation = value;
  String? get failedFilePath => item.failedFilePath;
  set failedFilePath(String? value) => item.failedFilePath = value;

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
}
