import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:github_manager/core/network/github_api_client.dart';
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
  int _sequence = 0;

  Stream<List<ManagedDownload>> get stream => _controller.stream;
  List<ManagedDownload> get items => List.unmodifiable(_items);
  int get activeCount => _items.where((item) => item.isActive).length;

  ManagedDownload startRepositoryZip({
    required String repositoryFullName,
    required String branch,
    required String projectName,
  }) {
    final safeName = _safeName(
      projectName.isEmpty ? repositoryFullName.split('/').last : projectName,
    );
    final fileName = '$safeName-${_safeName(branch)}-${_stamp()}.zip';
    return _startRedirected(
      title: 'Projeto $projectName',
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

  ManagedDownload startArtifactApk({
    required String repositoryFullName,
    required ActionArtifact artifact,
  }) {
    final item = _createItem(
      title: artifact.name,
      fileName: '${_safeName(artifact.name)}.apk',
      type: ManagedDownloadType.apk,
      repositoryFullName: repositoryFullName,
    );
    unawaited(_runArtifactApk(item, repositoryFullName, artifact));
    return item;
  }

  Future<void> cancel(String id) async {
    final item = _find(id);
    if (item == null || !item.isActive) {
      return;
    }
    _cancelTokens[id]?.cancel('Cancelado pelo usuário');
    item.status = ManagedDownloadStatus.cancelled;
    item.errorMessage = null;
    _emit();
    await _persistHistory();
  }

  Future<void> delete(String id) async {
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
    _items.remove(item);
    _emit();
    await _persistHistory();
  }

  Future<void> clearFinished() async {
    final finished = _items.where((item) => !item.isActive).toList();
    for (final item in finished) {
      await delete(item.id);
    }
  }

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
    );
    unawaited(_runRedirected(item, endpoint));
    return item;
  }

  ManagedDownload _createItem({
    required String title,
    required String fileName,
    required ManagedDownloadType type,
    String? repositoryFullName,
  }) {
    final item = ManagedDownload(
      id: '${DateTime.now().microsecondsSinceEpoch}-${_sequence++}',
      title: title,
      fileName: fileName,
      type: type,
      status: ManagedDownloadStatus.queued,
      createdAt: DateTime.now(),
      repositoryFullName: repositoryFullName,
    );
    _items.insert(0, item);
    _emit();
    return item;
  }

  Future<void> _runRedirected(ManagedDownload item, String endpoint) async {
    final cancelToken = CancelToken();
    _cancelTokens[item.id] = cancelToken;
    File? partialFile;
    File? completedFile;
    try {
      final directory = await _workingDirectory();
      completedFile = await _uniqueFile(directory, item.fileName);
      partialFile = File('${completedFile.path}.part');
      item.fileName = p.basename(completedFile.path);
      item.status = ManagedDownloadStatus.downloading;
      _emit();
      await _client.downloadRedirectedFile(
        endpoint,
        partialFile.path,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          item.receivedBytes = received;
          item.totalBytes = total;
          _emit();
        },
      );
      if (item.status == ManagedDownloadStatus.cancelled) {
        return;
      }
      completedFile = await partialFile.rename(completedFile.path);
      partialFile = null;
      item.receivedBytes = await completedFile.length();
      if (item.totalBytes <= 0) {
        item.totalBytes = item.receivedBytes;
      }
      await _publishCompleted(item, completedFile);
      completedFile = null;
    } catch (error) {
      if (item.status != ManagedDownloadStatus.cancelled) {
        item.status = ManagedDownloadStatus.failed;
        item.errorMessage = _friendlyError(error);
      }
    } finally {
      _cancelTokens.remove(item.id);
      if (partialFile != null && await partialFile.exists()) {
        await partialFile.delete();
      }
      if (completedFile != null && await completedFile.exists()) {
        await completedFile.delete();
      }
      _emit();
      await _persistHistory();
    }
  }

  Future<void> _runArtifactApk(
    ManagedDownload item,
    String repositoryFullName,
    ActionArtifact artifact,
  ) async {
    final cancelToken = CancelToken();
    _cancelTokens[item.id] = cancelToken;
    File? archiveFile;
    File? extractedFile;
    try {
      final directory = await _workingDirectory();
      archiveFile = File(
        p.join(directory.path, '.artifact-${artifact.id}-${item.id}.zip.part'),
      );
      item.status = ManagedDownloadStatus.downloading;
      _emit();
      await _client.downloadRedirectedFile(
        '/repos/$repositoryFullName/actions/artifacts/${artifact.id}/zip',
        archiveFile.path,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          item.receivedBytes = received;
          item.totalBytes = total;
          _emit();
        },
      );
      if (item.status == ManagedDownloadStatus.cancelled) {
        return;
      }

      final input = InputFileStream(archiveFile.path);
      final archive = ZipDecoder().decodeStream(input, verify: true);
      try {
        final apks = archive
            .where(
              (entry) =>
                  entry.isFile && entry.name.toLowerCase().endsWith('.apk'),
            )
            .toList(growable: false);
        if (apks.isEmpty) {
          throw const FormatException('O artifact não contém APK.');
        }
        final selected = apks.firstWhere(
          (entry) {
            final lower = entry.name.toLowerCase();
            return lower.contains('universal') ||
                (!lower.contains('arm64') &&
                    !lower.contains('armeabi') &&
                    !lower.contains('x86'));
          },
          orElse: () => apks.reduce((a, b) => a.size >= b.size ? a : b),
        );
        final bytes = selected.readBytes();
        if (bytes == null) {
          throw const FormatException('Não foi possível extrair o APK.');
        }
        extractedFile = await _uniqueFile(
          directory,
          selected.name.split('/').last,
        );
        await extractedFile.writeAsBytes(bytes, flush: true);
        item.fileName = p.basename(extractedFile.path);
        item.receivedBytes = bytes.length;
        item.totalBytes = bytes.length;
        await _publishCompleted(item, extractedFile);
        extractedFile = null;
      } finally {
        archive.clearSync();
        input.closeSync();
      }
    } catch (error) {
      if (item.status != ManagedDownloadStatus.cancelled) {
        item.status = ManagedDownloadStatus.failed;
        item.errorMessage = _friendlyError(error);
      }
    } finally {
      _cancelTokens.remove(item.id);
      if (archiveFile != null && await archiveFile.exists()) {
        await archiveFile.delete();
      }
      if (extractedFile != null && await extractedFile.exists()) {
        await extractedFile.delete();
      }
      _emit();
      await _persistHistory();
    }
  }

  Future<void> _publishCompleted(
    ManagedDownload item,
    File source,
  ) async {
    Future<String> publish() => PlatformActions.publishToDownloads(
          sourcePath: source.path,
          fileName: item.fileName,
          mimeType: _mimeType(item),
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

    item.localPath = location;
    item.status = ManagedDownloadStatus.completed;
    item.errorMessage = null;
    if (await source.exists()) {
      await source.delete();
    }
  }

  Future<void> _restoreHistory() async {
    try {
      final directory = await _workingDirectory();
      for (final file in directory.listSync().whereType<File>()) {
        try {
          file.deleteSync();
        } catch (_) {
          // Temporários antigos não devem bloquear a inicialização.
        }
      }
      final file = await _historyFile();
      if (!await file.exists()) {
        _emit();
        return;
      }
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! List) {
        return;
      }
      _items
        ..clear()
        ..addAll(
          decoded
              .whereType<Map>()
              .map(
                (json) => ManagedDownload.fromJson(
                  Map<String, dynamic>.from(json),
                ),
              )
              .where((item) => !item.isActive),
        );
      _emit();
    } catch (_) {
      // Histórico é auxiliar e nunca bloqueia o restante do aplicativo.
    }
  }

  Future<void> _persistHistory() async {
    try {
      final file = await _historyFile();
      final history = _items
          .where((item) => !item.isActive)
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

  static String _stamp() {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}-'
        '${two(now.hour)}${two(now.minute)}';
  }

  static String _friendlyError(Object error) {
    final message = error.toString();
    if (message.contains('REQUEST_CANCELLED')) {
      return 'Download cancelado.';
    }
    if (message.contains('Permissão negada')) {
      return 'Permissão negada para salvar na pasta Downloads.';
    }
    return 'Não foi possível concluir o download.';
  }

  void dispose() {
    for (final token in _cancelTokens.values) {
      token.cancel('Download manager encerrado');
    }
    _cancelTokens.clear();
    _controller.close();
  }
}
