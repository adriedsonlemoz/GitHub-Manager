import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:github_manager/core/errors/app_exception.dart';
import 'package:github_manager/core/network/github_api_client.dart';
import 'package:github_manager/core/notifications/app_notification_service.dart';
import 'package:github_manager/core/platform/platform_actions.dart';
import 'package:github_manager/features/builds/domain/action_artifact.dart';
import 'package:github_manager/features/downloads/domain/managed_download.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class DownloadManagerService {
  DownloadManagerService(this._client) {
    unawaited(_restoreHistory());
  }

  final GitHubApiClient _client;
  final _controller = StreamController<List<ManagedDownload>>.broadcast();
  final List<ManagedDownload> _items = [];
  final Map<String, CancelToken> _cancelTokens = {};
  final Map<String, _ProgressSample> _progressSamples = {};
  DateTime? _lastForegroundUpdate;
  int _sequence = 0;

  Stream<List<ManagedDownload>> get stream => _controller.stream;
  List<ManagedDownload> get items => List.unmodifiable(_items);
  int get activeCount => _items.where((item) => item.isActive).length;

  ManagedDownload startRepositoryZip({
    required String repositoryFullName,
    required String branch,
    required String projectName,
    String? version,
  }) {
    final safeName = _safeName(
      projectName.isEmpty ? repositoryFullName.split('/').last : projectName,
    );
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    final stamp =
        '${now.year}${two(now.month)}${two(now.day)}-${two(now.hour)}${two(now.minute)}${two(now.second)}';
    final safeVersion = version?.trim().isNotEmpty == true
        ? '-v${_safeName(version!.trim())}'
        : '';
    final fileName =
        '$safeName$safeVersion-$stamp-${_safeName(branch)}.zip';
    return _startRedirected(
      title: 'Projeto ${projectName.isEmpty ? safeName : projectName}',
      fileName: fileName,
      type: ManagedDownloadType.projectZip,
      repositoryFullName: repositoryFullName,
      endpoint:
          '/repos/$repositoryFullName/zipball/${Uri.encodeComponent(branch)}',
    );
  }

  ManagedDownload startWorkflowLogs({
    required String repositoryFullName,
    required int runId,
    required String runTitle,
  }) {
    return _startRedirected(
      title: 'Logs • $runTitle',
      fileName: '${_safeName(runTitle)}-logs.zip',
      type: ManagedDownloadType.logs,
      repositoryFullName: repositoryFullName,
      endpoint: '/repos/$repositoryFullName/actions/runs/$runId/logs',
    );
  }

  ManagedDownload startArtifactZip({
    required String repositoryFullName,
    required ActionArtifact artifact,
  }) {
    final endpoint =
        '/repos/$repositoryFullName/actions/artifacts/${artifact.id}/zip';
    final artifactName = _safeName(artifact.name, keepExtension: true);
    final fileName = p.extension(artifactName).isEmpty
        ? '$artifactName.zip'
        : artifactName;
    final item = _createItem(
      title: artifact.name,
      fileName: fileName,
      type: ManagedDownloadType.artifact,
      repositoryFullName: repositoryFullName,
      sourceEndpoint: endpoint,
      artifactId: artifact.id,
    );
    unawaited(_runRedirected(item, endpoint));
    return item;
  }

  ManagedDownload startArtifactApk({
    required String repositoryFullName,
    required ActionArtifact artifact,
  }) {
    final endpoint =
        '/repos/$repositoryFullName/actions/artifacts/${artifact.id}/zip';
    final item = _createItem(
      title: artifact.name,
      fileName: '${_safeName(artifact.name)}.apk',
      type: ManagedDownloadType.apk,
      repositoryFullName: repositoryFullName,
      sourceEndpoint: endpoint,
      artifactId: artifact.id,
    );
    unawaited(_runArtifactApk(item, endpoint));
    return item;
  }

  ManagedDownload startGitHubFile({
    required String title,
    required String fileName,
    required String repositoryFullName,
    required String endpoint,
  }) {
    return _startRedirected(
      title: title,
      fileName: fileName,
      type: ManagedDownloadType.file,
      repositoryFullName: repositoryFullName,
      endpoint: endpoint,
    );
  }

  ManagedDownload startReleaseAsset({
    required String title,
    required String fileName,
    required String repositoryFullName,
    required int assetId,
    required bool isApk,
  }) {
    final endpoint = '/repos/$repositoryFullName/releases/assets/$assetId';
    return _startRedirected(
      title: title,
      fileName: fileName,
      type: isApk ? ManagedDownloadType.apk : ManagedDownloadType.file,
      repositoryFullName: repositoryFullName,
      endpoint: endpoint,
    );
  }

  ManagedDownload startPublicUrl({
    required String title,
    required String fileName,
    required String repositoryFullName,
    required String url,
    required bool isApk,
  }) {
    final item = _createItem(
      title: title,
      fileName: fileName,
      type: isApk ? ManagedDownloadType.apk : ManagedDownloadType.file,
      repositoryFullName: repositoryFullName,
      sourceEndpoint: url,
    );
    unawaited(_runDirectUrl(item, url));
    return item;
  }

  Future<void> cancel(String id) async {
    final item = _find(id);
    if (item == null || !item.isActive) {
      return;
    }
    _cancelTokens[id]?.cancel('Cancelado pelo usuário');
    item
      ..status = ManagedDownloadStatus.cancelled
      ..failedAt = DateTime.now()
      ..bytesPerSecond = 0
      ..estimatedSecondsRemaining = null
      ..errorMessage = 'Download cancelado pelo usuário.'
      ..errorCode = 'DOWNLOAD_CANCELLED'
      ..failureStage = 'download';
    _progressSamples.remove(id);
    _emit();
    await _persistHistory();
    await _syncDownloadForegroundService();
  }

  Future<void> retry(String id) async {
    final item = _find(id);
    final endpoint = item?.sourceEndpoint;
    if (item == null || item.isActive || endpoint == null || endpoint.isEmpty) {
      return;
    }
    item.resetForRetry();
    _emit();
    if (endpoint.startsWith('https://') || endpoint.startsWith('http://')) {
      unawaited(_runDirectUrl(item, endpoint));
    } else if (item.isApk && item.artifactId != null) {
      unawaited(_runArtifactApk(item, endpoint));
    } else {
      unawaited(_runRedirected(item, endpoint));
    }
  }

  Future<void> removeFromHistory(String id) async {
    final item = _find(id);
    if (item == null || item.isActive) {
      return;
    }
    await _deleteWorkingFile(item);
    _items.remove(item);
    _emit();
    await _persistHistory();
  }

  Future<void> deleteFileAndHistory(String id) async {
    final item = _find(id);
    if (item == null || item.isActive) {
      return;
    }
    final location = item.localPath;
    if (location != null && location.isNotEmpty) {
      try {
        await PlatformActions.deletePublishedDownload(location);
      } catch (_) {
        // O arquivo pode já ter sido removido pelo usuário fora do app.
      }
    }
    await _deleteWorkingFile(item);
    _items.remove(item);
    _emit();
    await _persistHistory();
  }

  Future<void> clearFinishedHistory() async {
    final finished = _items.where((item) => !item.isActive).toList(growable: false);
    for (final item in finished) {
      await _deleteWorkingFile(item);
    }
    _items.removeWhere((item) => !item.isActive);
    _emit();
    await _persistHistory();
  }

  Future<void> _deleteWorkingFile(ManagedDownload item) async {
    final path = item.workingPath;
    if (path == null || path.isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Arquivo parcial é auxiliar e pode já ter sido limpo pelo Android.
    }
    item.workingPath = null;
  }

  // Compatibilidade com chamadas antigas dentro do projeto.
  Future<void> delete(String id) => deleteFileAndHistory(id);
  Future<void> clearFinished() => clearFinishedHistory();

  ManagedDownload _startRedirected({
    required String title,
    required String fileName,
    required ManagedDownloadType type,
    required String repositoryFullName,
    required String endpoint,
  }) {
    final item = _createItem(
      title: title,
      fileName: fileName,
      type: type,
      repositoryFullName: repositoryFullName,
      sourceEndpoint: endpoint,
    );
    unawaited(_runRedirected(item, endpoint));
    return item;
  }

  ManagedDownload _createItem({
    required String title,
    required String fileName,
    required ManagedDownloadType type,
    String? repositoryFullName,
    String? sourceEndpoint,
    int? artifactId,
  }) {
    final item = ManagedDownload(
      id: '${DateTime.now().microsecondsSinceEpoch}-${_sequence++}',
      title: title,
      fileName: fileName,
      type: type,
      status: ManagedDownloadStatus.queued,
      createdAt: DateTime.now(),
      repositoryFullName: repositoryFullName,
      sourceEndpoint: sourceEndpoint,
      artifactId: artifactId,
    );
    _items.insert(0, item);
    _emit();
    unawaited(_persistHistory());
    return item;
  }

  Future<void> _runDirectUrl(ManagedDownload item, String url) async {
    final cancelToken = CancelToken();
    _cancelTokens[item.id] = cancelToken;
    File? partialFile;
    File? completedFile;
    try {
      final directory = await _workingDirectory();
      completedFile = await _uniqueFile(directory, item.fileName);
      partialFile = await _partialFileFor(item, directory, item.fileName);
      final resumeFrom = await partialFile.exists() ? await partialFile.length() : 0;
      item
        ..fileName = p.basename(completedFile.path)
        ..sourceEndpoint = url
        ..receivedBytes = resumeFrom;
      _markStarted(item, initialBytes: resumeFrom);

      await _downloadPublicUrl(
        url,
        partialFile,
        resumeFrom: resumeFrom,
        cancelToken: cancelToken,
        onProgress: (received, total) => _updateProgress(item, received, total),
      );

      if (item.status == ManagedDownloadStatus.cancelled) return;
      completedFile = await partialFile.rename(completedFile.path);
      partialFile = null;
      item
        ..workingPath = null
        ..receivedBytes = await completedFile.length();
      if (item.totalBytes <= 0) item.totalBytes = item.receivedBytes;
      await _publishCompleted(item, completedFile);
      completedFile = null;
    } catch (error) {
      if (item.status != ManagedDownloadStatus.cancelled) {
        _recordFailure(
          item,
          error is DioException
              ? DownloadFailureException(
                  error.message ?? 'Falha ao baixar arquivo público.',
                  code: 'PUBLIC_DOWNLOAD_FAILED',
                  endpoint: url,
                  stage: 'baixar_arquivo',
                  httpStatus: error.response?.statusCode,
                )
              : error,
          fallbackStage: 'baixar_arquivo',
        );
      }
    } finally {
      _cancelTokens.remove(item.id);
      _progressSamples.remove(item.id);
      if (completedFile != null && await completedFile.exists()) {
        await completedFile.delete();
      }
      _emit();
      await _persistHistory();
      await _syncDownloadForegroundService();
    }
  }

  Future<void> _runRedirected(ManagedDownload item, String endpoint) async {
    final cancelToken = CancelToken();
    _cancelTokens[item.id] = cancelToken;
    File? partialFile;
    File? completedFile;
    try {
      final directory = await _workingDirectory();
      completedFile = await _uniqueFile(directory, item.fileName);
      partialFile = await _partialFileFor(item, directory, item.fileName);
      final resumeFrom = await partialFile.exists() ? await partialFile.length() : 0;
      item
        ..fileName = p.basename(completedFile.path)
        ..sourceEndpoint = endpoint
        ..receivedBytes = resumeFrom;
      _markStarted(item, initialBytes: resumeFrom);
      final onProgress = (int received, int total) =>
          _updateProgress(item, received, total);
      if (endpoint.contains('/releases/assets/')) {
        await _client.downloadReleaseAssetFile(
          endpoint,
          partialFile.path,
          cancelToken: cancelToken,
          onReceiveProgress: onProgress,
          resumeFrom: resumeFrom,
        );
      } else {
        await _client.downloadRedirectedFile(
          endpoint,
          partialFile.path,
          cancelToken: cancelToken,
          onReceiveProgress: onProgress,
          resumeFrom: resumeFrom,
        );
      }
      if (item.status == ManagedDownloadStatus.cancelled) return;
      completedFile = await partialFile.rename(completedFile.path);
      partialFile = null;
      item
        ..workingPath = null
        ..receivedBytes = await completedFile.length();
      if (item.totalBytes <= 0) item.totalBytes = item.receivedBytes;
      await _publishCompleted(item, completedFile);
      completedFile = null;
    } catch (error) {
      if (item.status != ManagedDownloadStatus.cancelled) {
        _recordFailure(
          item,
          error,
          fallbackStage: item.failureStage ?? 'download',
        );
      }
    } finally {
      _cancelTokens.remove(item.id);
      _progressSamples.remove(item.id);
      if (completedFile != null && await completedFile.exists()) {
        await completedFile.delete();
      }
      _emit();
      await _persistHistory();
      await _syncDownloadForegroundService();
    }
  }

  Future<void> _runArtifactApk(
    ManagedDownload item,
    String endpoint,
  ) async {
    final cancelToken = CancelToken();
    _cancelTokens[item.id] = cancelToken;
    File? downloadedFile;
    File? publishFile;
    try {
      final directory = await _workingDirectory();
      downloadedFile = await _partialFileFor(
        item,
        directory,
        'artifact-${item.artifactId ?? 'download'}.zip',
      );
      final resumeFrom = await downloadedFile.exists()
          ? await downloadedFile.length()
          : 0;
      item
        ..sourceEndpoint = endpoint
        ..receivedBytes = resumeFrom;
      _markStarted(item, initialBytes: resumeFrom);
      await _client.downloadRedirectedFile(
        endpoint,
        downloadedFile.path,
        cancelToken: cancelToken,
        resumeFrom: resumeFrom,
        onReceiveProgress: (received, total) =>
            _updateProgress(item, received, total),
      );
      if (item.status == ManagedDownloadStatus.cancelled) return;

      item.failureStage = 'identificar_artifact';
      final input = InputFileStream(downloadedFile.path);
      final archive = ZipDecoder().decodeStream(input, verify: true);
      ArchiveFile? selectedApk;
      var directApk = false;
      try {
        final apks = archive
            .where(
              (entry) =>
                  entry.isFile && entry.name.toLowerCase().endsWith('.apk'),
            )
            .toList(growable: false);
        if (apks.isNotEmpty) {
          selectedApk = apks.firstWhere(
            (entry) {
              final lower = entry.name.toLowerCase();
              return lower.contains('universal') ||
                  (!lower.contains('arm64') &&
                      !lower.contains('armeabi') &&
                      !lower.contains('x86'));
            },
            orElse: () => apks.reduce((a, b) => a.size >= b.size ? a : b),
          );
        } else {
          final names = archive
              .where((entry) => entry.isFile)
              .map((entry) => entry.name.replaceAll('\\', '/').toLowerCase())
              .toSet();
          directApk = names.contains('androidmanifest.xml') &&
              (names.contains('classes.dex') || names.contains('resources.arsc'));
        }

        if (selectedApk == null && !directApk) {
          throw const FormatException(
            'O artifact foi baixado, mas não contém um APK reconhecível.',
          );
        }

        if (selectedApk != null) {
          item.failureStage = 'extrair_apk';
          final bytes = selectedApk.readBytes();
          if (bytes == null) {
            throw const FormatException('Não foi possível extrair o APK.');
          }
          publishFile = await _uniqueFile(
            directory,
            selectedApk.name.split('/').last,
          );
          await publishFile.writeAsBytes(bytes, flush: true);
          item
            ..fileName = p.basename(publishFile.path)
            ..receivedBytes = bytes.length
            ..totalBytes = bytes.length;
        }
      } finally {
        archive.clearSync();
        input.closeSync();
      }

      if (directApk) {
        item.failureStage = 'preparar_apk_direto';
        final desiredName = item.fileName.toLowerCase().endsWith('.apk')
            ? item.fileName
            : '${_safeName(item.title)}.apk';
        publishFile = await _uniqueFile(directory, desiredName);
        publishFile = await downloadedFile.rename(publishFile.path);
        downloadedFile = null;
        item.workingPath = null;
        final length = await publishFile.length();
        item
          ..fileName = p.basename(publishFile.path)
          ..receivedBytes = length
          ..totalBytes = length;
      } else {
        item.workingPath = null;
        if (downloadedFile != null && await downloadedFile.exists()) {
          await downloadedFile.delete();
        }
        downloadedFile = null;
      }

      if (publishFile == null) {
        throw const FormatException('Não foi possível preparar o APK baixado.');
      }
      await _publishCompleted(item, publishFile);
      publishFile = null;
    } catch (error) {
      if (item.status != ManagedDownloadStatus.cancelled) {
        _recordFailure(
          item,
          error,
          fallbackStage: item.failureStage ?? 'identificar_artifact',
        );
      }
    } finally {
      _cancelTokens.remove(item.id);
      _progressSamples.remove(item.id);
      if (publishFile != null && await publishFile.exists()) {
        await publishFile.delete();
      }
      _emit();
      await _persistHistory();
      await _syncDownloadForegroundService();
    }
  }

  Future<File> _partialFileFor(
    ManagedDownload item,
    Directory directory,
    String requestedName,
  ) async {
    final existingPath = item.workingPath;
    if (existingPath != null && existingPath.isNotEmpty) {
      return File(existingPath);
    }
    final safe = _safeName(requestedName, keepExtension: true);
    final partial = File(p.join(directory.path, '.${item.id}-$safe.part'));
    item.workingPath = partial.path;
    await _persistHistory();
    return partial;
  }

  Future<void> _downloadPublicUrl(
    String url,
    File target, {
    required int resumeFrom,
    required CancelToken cancelToken,
    required void Function(int received, int total) onProgress,
  }) async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(minutes: 10),
        followRedirects: true,
      ),
    );
    Future<Response<ResponseBody>> request(int offset) => dio.get<ResponseBody>(
          url,
          cancelToken: cancelToken,
          options: Options(
            responseType: ResponseType.stream,
            validateStatus: (status) =>
                status == 200 || status == 206 || status == 416,
            headers: {if (offset > 0) 'Range': 'bytes=$offset-'},
          ),
        );

    var offset = resumeFrom;
    var response = await request(offset);
    if (response.statusCode == 416 && offset > 0) {
      if (await target.exists()) await target.delete();
      offset = 0;
      response = await request(0);
    }
    if (response.statusCode != 200 && response.statusCode != 206) {
      throw DownloadFailureException(
        'O servidor não aceitou a retomada do download.',
        code: 'PUBLIC_DOWNLOAD_RESUME_FAILED',
        endpoint: url,
        stage: 'retomar_download',
        httpStatus: response.statusCode,
      );
    }
    final body = response.data;
    if (body == null) {
      throw const FormatException('O servidor retornou um download vazio.');
    }
    final acceptedResume = response.statusCode == 206 && offset > 0;
    final startingBytes = acceptedResume ? offset : 0;
    final contentRange = response.headers.value('content-range');
    final rangeTotal = contentRange == null
        ? null
        : int.tryParse(contentRange.split('/').last.trim());
    final contentLength =
        int.tryParse(response.headers.value('content-length') ?? '');
    final total = rangeTotal ??
        (contentLength == null ? -1 : startingBytes + contentLength);
    final sink = target.openWrite(
      mode: acceptedResume ? FileMode.append : FileMode.write,
    );
    var received = startingBytes;
    try {
      await for (final chunk in body.stream) {
        if (cancelToken.isCancelled) return;
        sink.add(chunk);
        received += chunk.length;
        onProgress(received, total);
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
  }

  void _markStarted(ManagedDownload item, {int initialBytes = 0}) {
    final now = DateTime.now();
    item
      ..status = ManagedDownloadStatus.downloading
      ..startedAt = now
      ..failedAt = null
      ..completedAt = null
      ..errorMessage = null
      ..errorCode = null
      ..failureStage = null
      ..httpStatus = null
      ..responseMessage = null
      ..bytesPerSecond = 0
      ..estimatedSecondsRemaining = null;
    _progressSamples[item.id] = _ProgressSample(now, initialBytes, 0);
    _emit();
    unawaited(_persistHistory());
    unawaited(AppNotificationService.requestPermission());
    unawaited(_syncDownloadForegroundService(startService: true));
  }

  void _updateProgress(ManagedDownload item, int received, int total) {
    final now = DateTime.now();
    final previous = _progressSamples[item.id];
    var speed = item.bytesPerSecond;
    if (previous != null) {
      final elapsedMicros = now.difference(previous.at).inMicroseconds;
      final deltaBytes = received - previous.bytes;
      if (elapsedMicros > 0 && deltaBytes >= 0) {
        final instantaneous = deltaBytes / (elapsedMicros / 1000000);
        speed = previous.smoothedSpeed <= 0
            ? instantaneous
            : (previous.smoothedSpeed * 0.7) + (instantaneous * 0.3);
      }
    }
    item
      ..receivedBytes = received
      ..totalBytes = total
      ..bytesPerSecond = speed;
    if (total > received && speed > 1) {
      item.estimatedSecondsRemaining = ((total - received) / speed).ceil();
    } else {
      item.estimatedSecondsRemaining = null;
    }
    _progressSamples[item.id] = _ProgressSample(now, received, speed);
    _emit();
    final last = _lastForegroundUpdate;
    if (last == null || now.difference(last) >= const Duration(milliseconds: 500)) {
      _lastForegroundUpdate = now;
      unawaited(_syncDownloadForegroundService());
    }
  }

  Future<void> _syncDownloadForegroundService({bool startService = false}) async {
    final active = _items.where((item) => item.isActive).toList(growable: false);
    if (active.isEmpty) {
      _lastForegroundUpdate = null;
      try {
        await PlatformActions.stopDownloadForegroundService();
      } catch (_) {
        // O canal nativo pode não existir fora do Android/testes.
      }
      return;
    }
    final item = active.first;
    try {
      await PlatformActions.showDownloadForegroundService(
        startService: startService,
        downloadId: item.id,
        fileName: item.fileName,
        repositoryFullName: item.repositoryFullName ?? '',
        current: item.receivedBytes,
        total: item.totalBytes,
        indeterminate: item.totalBytes <= 0,
        activeCount: active.length,
      );
    } catch (_) {
      // A notificação auxilia o segundo plano, mas não invalida o download.
    }
  }

  Future<void> _publishCompleted(
    ManagedDownload item,
    File source,
  ) async {
    item.failureStage = 'salvar_downloads';
    final projectFolder = _projectFolderName(item.repositoryFullName);
    Future<String> publish() => PlatformActions.publishToDownloads(
          sourcePath: source.path,
          fileName: item.fileName,
          mimeType: _mimeType(item),
          relativeFolder: projectFolder,
        );

    String location;
    try {
      location = await publish();
    } on PlatformException catch (error) {
      if (error.code != 'STORAGE_PERMISSION_REQUIRED') {
        rethrow;
      }
      final granted = await PlatformActions.requestLegacyDownloadsPermission();
      if (!granted) {
        throw FileSystemException(
          'Permissão negada para salvar na pasta Downloads.',
        );
      }
      location = await publish();
    }

    item
      ..localPath = location
      ..workingPath = null
      ..status = ManagedDownloadStatus.completed
      ..completedAt = DateTime.now()
      ..failedAt = null
      ..errorMessage = null
      ..errorCode = null
      ..failureStage = null
      ..httpStatus = null
      ..responseMessage = null
      ..bytesPerSecond = 0
      ..estimatedSecondsRemaining = null;
    await AppNotificationService.showDownloadCompleted(
      id: item.id,
      fileName: item.fileName,
      repository: item.repositoryFullName ?? '',
    );
    if (await source.exists()) {
      await source.delete();
    }
  }

  void _recordFailure(
    ManagedDownload item,
    Object error, {
    required String fallbackStage,
  }) {
    item
      ..status = ManagedDownloadStatus.failed
      ..failedAt = DateTime.now()
      ..completedAt = null
      ..bytesPerSecond = 0
      ..estimatedSecondsRemaining = null;

    if (error is DownloadFailureException) {
      final partialPreserved = item.workingPath?.isNotEmpty == true &&
          item.receivedBytes > 0;
      item
        ..errorMessage = partialPreserved
            ? '${error.message} O progresso parcial foi preservado para retomada.'
            : error.message
        ..errorCode = error.technicalCode
        ..sourceEndpoint = error.endpoint
        ..failureStage = error.stage
        ..httpStatus = error.httpStatus
        ..responseMessage = _cleanTechnicalMessage(error.apiMessage);
      _notifyDownloadFailure(item);
      return;
    }

    if (error is PlatformException) {
      item
        ..errorMessage = _platformFriendlyError(error)
        ..errorCode = error.code
        ..failureStage = fallbackStage
        ..responseMessage = _cleanTechnicalMessage(error.message);
      _notifyDownloadFailure(item);
      return;
    }

    if (error is FileSystemException) {
      final message = '${error.message} ${error.osError?.message ?? ''}'.trim();
      final full = message.toLowerCase();
      final fullStorage = full.contains('no space left') ||
          full.contains('enospc') ||
          full.contains('espaço insuficiente');
      final permissionDenied = full.contains('permissão negada') ||
          full.contains('permission denied');
      item
        ..errorMessage = fullStorage
            ? 'Não há espaço suficiente no aparelho para concluir o download.'
            : permissionDenied
                ? 'Sem permissão para gravar o arquivo na pasta Downloads.'
                : 'Erro ao gravar o arquivo na pasta Downloads.'
        ..errorCode = fullStorage
            ? 'STORAGE_FULL'
            : permissionDenied
                ? 'DOWNLOAD_STORAGE_PERMISSION'
                : 'DOWNLOAD_WRITE_FAILED'
        ..failureStage = fallbackStage
        ..responseMessage = _cleanTechnicalMessage(message);
      _notifyDownloadFailure(item);
      return;
    }

    if (error is FormatException) {
      item
        ..errorMessage = error.message
        ..errorCode = 'DOWNLOAD_CONTENT_INVALID'
        ..failureStage = fallbackStage
        ..responseMessage = null;
      _notifyDownloadFailure(item);
      return;
    }

    item
      ..errorMessage = 'Erro desconhecido ao concluir o download.'
      ..errorCode = 'DOWNLOAD_UNKNOWN'
      ..failureStage = fallbackStage
      ..responseMessage = _cleanTechnicalMessage(error.toString());
    _notifyDownloadFailure(item);
  }

  void _notifyDownloadFailure(ManagedDownload item) {
    unawaited(
      AppNotificationService.showDownloadFailed(
        id: item.id,
        fileName: item.fileName,
        message: item.errorMessage ?? 'Não foi possível concluir o download.',
      ),
    );
  }

  static String _platformFriendlyError(PlatformException error) {
    final message = (error.message ?? '').toLowerCase();
    if (error.code == 'STORAGE_FULL' ||
        message.contains('no space left') ||
        message.contains('enospc')) {
      return 'Não há espaço suficiente no aparelho para concluir o download.';
    }
    if (error.code == 'STORAGE_PERMISSION_REQUIRED') {
      return 'O Android não permitiu gravar o arquivo na pasta Downloads.';
    }
    if (error.code == 'DOWNLOAD_SOURCE_NOT_FOUND') {
      return 'O arquivo temporário do download não foi encontrado.';
    }
    return 'Erro ao gravar o arquivo na pasta Downloads.';
  }

  static String? _cleanTechnicalMessage(String? value) {
    if (value == null) {
      return null;
    }
    var result = value.trim();
    if (result.isEmpty) {
      return null;
    }
    result = result.replaceAll(
      RegExp(
        r'authorization\s*[:=]\s*(bearer\s+)?[^\s,;]+',
        caseSensitive: false,
      ),
      'Authorization=[REMOVIDO]',
    );
    result = result.replaceAllMapped(
      RegExp(
        r'(token|secret|api[_ -]?key|password)\s*[:=]\s*[^\s,;]+',
        caseSensitive: false,
      ),
      (match) => '${match.group(1)}=[REMOVIDO]',
    );
    return result.length > 700 ? '${result.substring(0, 700)}…' : result;
  }

  Future<void> _restoreHistory() async {
    try {
      await _workingDirectory();
      final file = await _historyFile();
      if (!await file.exists()) {
        _emit();
        return;
      }
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! List) {
        return;
      }
      final restored = decoded
          .whereType<Map>()
          .map(
            (json) => ManagedDownload.fromJson(
              Map<String, dynamic>.from(json),
            ),
          )
          .toList(growable: false);
      final autoResumeIds = <String>[];
      for (final item in restored) {
        if (item.isActive) {
          item.markInterruptedByAppExit();
          final partialPath = item.workingPath;
          if (partialPath != null &&
              partialPath.isNotEmpty &&
              item.sourceEndpoint?.isNotEmpty == true &&
              await File(partialPath).exists()) {
            item.receivedBytes = await File(partialPath).length();
            autoResumeIds.add(item.id);
          }
        }
      }
      final liveItems = List<ManagedDownload>.from(_items);
      final liveIds = liveItems.map((item) => item.id).toSet();
      final merged = <ManagedDownload>[
        ...liveItems,
        ...restored.where((item) => !liveIds.contains(item.id)),
      ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _items
        ..clear()
        ..addAll(merged);
      _emit();
      await _persistHistory();
      for (final id in autoResumeIds) {
        unawaited(retry(id));
      }
    } catch (_) {
      // Histórico é auxiliar e nunca bloqueia o restante do aplicativo.
    }
  }

  Future<void> _persistHistory() async {
    try {
      final file = await _historyFile();
      final history = _items
          .take(100)
          .map((item) => item.toJson())
          .toList(growable: false);
      await file.writeAsString(jsonEncode(history), flush: true);
    } catch (_) {
      // Falha de histórico não invalida o download já concluído no Android.
    }
  }

  Future<Directory> _workingDirectory() async {
    final root = await getApplicationSupportDirectory();
    final directory = Directory(p.join(root.path, 'download_work'));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<File> _historyFile() async {
    final root = await getApplicationSupportDirectory();
    return File(p.join(root.path, 'downloads_history.json'));
  }

  Future<File> _uniqueFile(Directory directory, String requestedName) async {
    final safe = _safeName(requestedName, keepExtension: true);
    var candidate = File(p.join(directory.path, safe));
    if (!await candidate.exists()) {
      return candidate;
    }
    final extension = p.extension(safe);
    final stem = p.basenameWithoutExtension(safe);
    var index = 2;
    while (await candidate.exists()) {
      candidate = File(p.join(directory.path, '$stem-$index$extension'));
      index++;
    }
    return candidate;
  }

  ManagedDownload? _find(String id) {
    for (final item in _items) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  void _emit() {
    if (!_controller.isClosed) {
      _controller.add(List.unmodifiable(_items));
    }
  }

  static String _mimeType(ManagedDownload item) {
    if (item.isApk) {
      return 'application/vnd.android.package-archive';
    }
    if (item.fileName.toLowerCase().endsWith('.zip')) {
      return 'application/zip';
    }
    return 'application/octet-stream';
  }

  static String? _projectFolderName(String? repositoryFullName) {
    if (repositoryFullName == null || repositoryFullName.trim().isEmpty) {
      return null;
    }
    final raw = repositoryFullName.split('/').last.trim();
    if (raw.isEmpty) return null;
    final readable = raw.replaceAll(RegExp(r'[-_]+'), ' ').trim();
    return _safeName(readable, keepExtension: true);
  }

  static String _safeName(String raw, {bool keepExtension = false}) {
    final source = raw.trim().isEmpty ? 'download' : raw.trim();
    final replaced = source.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '-');
    final collapsed = replaced.replaceAll(RegExp(r'-+'), '-');
    final clean = collapsed.replaceAll(RegExp(r'^[-.]+|[-.]+$'), '');
    if (clean.isEmpty) {
      return 'download';
    }
    if (keepExtension) {
      return clean;
    }
    return clean.replaceAll(RegExp(r'\.(zip|apk)$', caseSensitive: false), '');
  }

  void dispose() {
    for (final token in _cancelTokens.values) {
      token.cancel('Download manager encerrado');
    }
    _cancelTokens.clear();
    _progressSamples.clear();
    unawaited(_stopDownloadForegroundService());
    _controller.close();
  }

  Future<void> _stopDownloadForegroundService() async {
    try {
      await PlatformActions.stopDownloadForegroundService();
    } catch (_) {
      // O app pode estar encerrando antes do canal nativo responder.
    }
  }
}

class _ProgressSample {
  const _ProgressSample(this.at, this.bytes, this.smoothedSpeed);

  final DateTime at;
  final int bytes;
  final double smoothedSpeed;
}
