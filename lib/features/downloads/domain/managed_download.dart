enum ManagedDownloadType { apk, projectZip, logs, artifact, file }

enum ManagedDownloadStatus {
  queued,
  downloading,
  paused,
  completed,
  failed,
  interrupted,
  cancelled,
}

class ManagedDownload {
  ManagedDownload({
    required this.id,
    required this.title,
    required this.fileName,
    required this.type,
    required this.status,
    required this.createdAt,
    this.repositoryFullName,
    this.sourceEndpoint,
    this.artifactId,
    this.preferredAbi,
    this.preferredAbis = const <String>[],
    this.inspectedAbis = const <String>[],
    this.localPath,
    this.workingPath,
    this.startedAt,
    this.completedAt,
    this.failedAt,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.bytesPerSecond = 0,
    this.estimatedSecondsRemaining,
    this.errorMessage,
    this.errorCode,
    this.failureStage,
    this.httpStatus,
    this.responseMessage,
  });

  final String id;
  String title;
  String fileName;
  final ManagedDownloadType type;
  ManagedDownloadStatus status;
  final DateTime createdAt;
  final String? repositoryFullName;
  String? sourceEndpoint;
  int? artifactId;
  String? preferredAbi;
  final List<String> preferredAbis;
  List<String> inspectedAbis;
  String? localPath;
  String? workingPath;
  DateTime? startedAt;
  DateTime? completedAt;
  DateTime? failedAt;
  int receivedBytes;
  int totalBytes;
  double bytesPerSecond;
  int? estimatedSecondsRemaining;
  String? errorMessage;
  String? errorCode;
  String? failureStage;
  int? httpStatus;
  String? responseMessage;

  bool get isActive =>
      status == ManagedDownloadStatus.queued ||
      status == ManagedDownloadStatus.downloading;

  bool get isPaused => status == ManagedDownloadStatus.paused;

  bool get isHistoryClearable => !isActive && !isPaused;

  bool get isApk =>
      type == ManagedDownloadType.apk || fileName.toLowerCase().endsWith('.apk');

  String get sourceLabel {
    final endpoint = sourceEndpoint?.toLowerCase() ?? '';
    if (endpoint.contains('/releases/assets/')) {
      return 'Release direta';
    }
    if (endpoint.contains('/actions/artifacts/')) {
      return 'GitHub Actions';
    }
    if (endpoint.startsWith('http://') || endpoint.startsWith('https://')) {
      return 'Link direto';
    }
    return 'GitHub';
  }

  bool get usesContentUri => localPath?.startsWith('content://') == true;

  bool get canRetry =>
      (status == ManagedDownloadStatus.failed ||
          status == ManagedDownloadStatus.interrupted ||
          status == ManagedDownloadStatus.cancelled) &&
      sourceEndpoint != null &&
      sourceEndpoint!.isNotEmpty;

  bool get canResume =>
      (canRetry || isPaused) &&
      workingPath?.isNotEmpty == true &&
      receivedBytes > 0;

  double? get progress {
    if (totalBytes <= 0) {
      return null;
    }
    final value = receivedBytes / totalBytes;
    return value.clamp(0, 1).toDouble();
  }

  String get typeLabel => switch (type) {
        ManagedDownloadType.apk => 'APK',
        ManagedDownloadType.projectZip => 'ZIP do projeto',
        ManagedDownloadType.logs => 'Logs do GitHub Actions',
        ManagedDownloadType.artifact => 'Artifact',
        ManagedDownloadType.file => 'Arquivo',
      };

  String get statusLabel => switch (status) {
        ManagedDownloadStatus.queued => 'Aguardando',
        ManagedDownloadStatus.downloading => 'Baixando',
        ManagedDownloadStatus.paused => 'Pausado',
        ManagedDownloadStatus.completed => 'Concluído',
        ManagedDownloadStatus.failed => 'Falhou',
        ManagedDownloadStatus.interrupted => 'Interrompido',
        ManagedDownloadStatus.cancelled => 'Cancelado',
      };

  String get technicalLog {
    final lines = <String>[
      'GitHub Manager — log de download',
      'Data/hora: ${(failedAt ?? completedAt ?? startedAt ?? createdAt).toLocal().toIso8601String()}',
      'Arquivo: $fileName',
      'Tipo: $typeLabel',
      'Status: $statusLabel',
      if (repositoryFullName != null) 'Repositório: $repositoryFullName',
      if (preferredAbi?.isNotEmpty == true) 'ABI preferida: $preferredAbi',
      if (preferredAbis.isNotEmpty) 'ABIs do aparelho: ${preferredAbis.join(', ')}',
      if (inspectedAbis.isNotEmpty) 'ABIs presentes no APK baixado: ${inspectedAbis.join(', ')}',
      if (sourceEndpoint != null) 'Endpoint: $sourceEndpoint',
      if (workingPath != null) 'Arquivo parcial: preservado para retomada',
      if (httpStatus != null) 'HTTP: $httpStatus',
      if (failureStage != null) 'Etapa: $failureStage',
      if (errorCode != null) 'Código interno: $errorCode',
      'Bytes recebidos: $receivedBytes',
      if (totalBytes > 0) 'Tamanho esperado: $totalBytes',
      if (errorMessage != null) 'Erro: $errorMessage',
      if (responseMessage != null) 'Mensagem da API: $responseMessage',
    ];
    return lines.join('\n');
  }

  void markPaused() {
    status = ManagedDownloadStatus.paused;
    bytesPerSecond = 0;
    estimatedSecondsRemaining = null;
    errorMessage = null;
    errorCode = null;
    failureStage = null;
    httpStatus = null;
    responseMessage = null;
  }

  void markInterruptedByAppExit() {
    status = ManagedDownloadStatus.interrupted;
    failedAt = DateTime.now();
    bytesPerSecond = 0;
    estimatedSecondsRemaining = null;
    errorMessage = workingPath?.isNotEmpty == true
        ? 'Download interrompido. O progresso parcial foi preservado para retomar.'
        : 'Download interrompido porque o aplicativo foi encerrado.';
    errorCode = 'DOWNLOAD_APP_INTERRUPTED';
    failureStage = 'download';
  }

  void resetForRetry({bool preserveProgress = false}) {
    status = ManagedDownloadStatus.queued;
    localPath = null;
    startedAt = null;
    completedAt = null;
    failedAt = null;
    if (!preserveProgress) {
      receivedBytes = 0;
      totalBytes = 0;
    }
    bytesPerSecond = 0;
    estimatedSecondsRemaining = null;
    errorMessage = null;
    inspectedAbis = const <String>[];
    errorCode = null;
    failureStage = null;
    httpStatus = null;
    responseMessage = null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'fileName': fileName,
        'type': type.name,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'repositoryFullName': repositoryFullName,
        'sourceEndpoint': sourceEndpoint,
        'artifactId': artifactId,
        'preferredAbi': preferredAbi,
        'preferredAbis': preferredAbis,
        'inspectedAbis': inspectedAbis,
        'localPath': localPath,
        'workingPath': workingPath,
        'startedAt': startedAt?.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'failedAt': failedAt?.toIso8601String(),
        'receivedBytes': receivedBytes,
        'totalBytes': totalBytes,
        'bytesPerSecond': bytesPerSecond,
        'estimatedSecondsRemaining': estimatedSecondsRemaining,
        'errorMessage': errorMessage,
        'errorCode': errorCode,
        'failureStage': failureStage,
        'httpStatus': httpStatus,
        'responseMessage': responseMessage,
      };

  factory ManagedDownload.fromJson(Map<String, dynamic> json) {
    final typeName = json['type']?.toString();
    final statusName = json['status']?.toString();
    return ManagedDownload(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Download',
      fileName: json['fileName']?.toString() ?? 'download',
      type: ManagedDownloadType.values.firstWhere(
        (value) => value.name == typeName,
        orElse: () => ManagedDownloadType.file,
      ),
      status: ManagedDownloadStatus.values.firstWhere(
        (value) => value.name == statusName,
        orElse: () => ManagedDownloadStatus.completed,
      ),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      repositoryFullName: json['repositoryFullName']?.toString(),
      sourceEndpoint: json['sourceEndpoint']?.toString(),
      artifactId: (json['artifactId'] as num?)?.toInt(),
      preferredAbi: json['preferredAbi']?.toString(),
      preferredAbis: (json['preferredAbis'] as List?)
              ?.map((value) => value.toString())
              .where((value) => value.isNotEmpty)
              .toList(growable: false) ??
          const <String>[],
      inspectedAbis: (json['inspectedAbis'] as List?)
              ?.map((value) => value.toString())
              .where((value) => value.isNotEmpty)
              .toList(growable: false) ??
          const <String>[],
      localPath: json['localPath']?.toString(),
      workingPath: json['workingPath']?.toString(),
      startedAt: DateTime.tryParse(json['startedAt']?.toString() ?? ''),
      completedAt: DateTime.tryParse(json['completedAt']?.toString() ?? ''),
      failedAt: DateTime.tryParse(json['failedAt']?.toString() ?? ''),
      receivedBytes: (json['receivedBytes'] as num?)?.toInt() ?? 0,
      totalBytes: (json['totalBytes'] as num?)?.toInt() ?? 0,
      bytesPerSecond: (json['bytesPerSecond'] as num?)?.toDouble() ?? 0,
      estimatedSecondsRemaining:
          (json['estimatedSecondsRemaining'] as num?)?.toInt(),
      errorMessage: json['errorMessage']?.toString(),
      errorCode: json['errorCode']?.toString(),
      failureStage: json['failureStage']?.toString(),
      httpStatus: (json['httpStatus'] as num?)?.toInt(),
      responseMessage: json['responseMessage']?.toString(),
    );
  }
}
