import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:github_manager/core/errors/app_exception.dart';
import 'package:github_manager/features/projects/data/git_project_upload_service.dart';
import 'package:github_manager/features/projects/domain/zip_project.dart';
import 'package:github_manager/features/repositories/data/repository_git_service.dart';
import 'package:github_manager/features/repositories/domain/repository_git_models.dart';
import 'package:github_manager/features/uploads/domain/managed_upload.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

typedef ProjectUploadExecutor = Future<ProjectUploadResult> Function({
  required ZipProjectPreview project,
  required String repositoryFullName,
  required String branch,
  required String commitMessage,
  void Function(ProjectUploadProgress progress)? onProgress,
});

typedef BuildEnsureExecutor = Future<RepositoryBuildLaunchResult> Function({
  required String repositoryFullName,
  required String branch,
  required String commitSha,
  void Function(String status)? onStatus,
  required int verificationAttempts,
  required Duration verificationDelay,
  required Duration postDispatchDelay,
});

class UploadManagerService {
  UploadManagerService({
    required GitProjectUploadService uploadService,
    required RepositoryGitService gitService,
    Future<File> Function()? historyFileFactory,
    bool restoreHistory = true,
  })  : _uploadZip = (({
          required ZipProjectPreview project,
          required String repositoryFullName,
          required String branch,
          required String commitMessage,
          void Function(ProjectUploadProgress progress)? onProgress,
        }) =>
            uploadService.uploadZip(
              project: project,
              repositoryFullName: repositoryFullName,
              branch: branch,
              commitMessage: commitMessage,
              onProgress: onProgress,
            )),
        _ensureBuild = (({
          required String repositoryFullName,
          required String branch,
          required String commitSha,
          void Function(String status)? onStatus,
          required int verificationAttempts,
          required Duration verificationDelay,
          required Duration postDispatchDelay,
        }) =>
            gitService.ensureBuildForCommit(
              repositoryFullName: repositoryFullName,
              branch: branch,
              commitSha: commitSha,
              onStatus: onStatus,
              verificationAttempts: verificationAttempts,
              verificationDelay: verificationDelay,
              postDispatchDelay: postDispatchDelay,
            )),
        _historyFileFactory = historyFileFactory {
    if (restoreHistory) {
      unawaited(_restoreHistory());
    }
  }

  UploadManagerService.forTest({
    required ProjectUploadExecutor uploadZip,
    required BuildEnsureExecutor ensureBuild,
    Future<File> Function()? historyFileFactory,
    bool restoreHistory = false,
  })  : _uploadZip = uploadZip,
        _ensureBuild = ensureBuild,
        _historyFileFactory = historyFileFactory {
    if (restoreHistory) {
      unawaited(_restoreHistory());
    }
  }

  final ProjectUploadExecutor _uploadZip;
  final BuildEnsureExecutor _ensureBuild;
  final Future<File> Function()? _historyFileFactory;
  final _controller = StreamController<List<ManagedUpload>>.broadcast();
  final List<ManagedUpload> _items = [];
  final List<_QueuedUploadTask> _queue = [];
  Timer? _persistTimer;
  Future<void> _persistTail = Future<void>.value();
  bool _running = false;
  bool _disposed = false;
  int _sequence = 0;

  Stream<List<ManagedUpload>> get stream => _controller.stream;
  List<ManagedUpload> get items => List.unmodifiable(_items);
  int get activeCount => _items.where((item) => item.isActive).length;

  ManagedUpload startBuild({
    required ZipProjectPreview project,
    required String repositoryFullName,
    required String branch,
  }) {
    final duplicate = _items.where((item) => item.isActive).firstWhereOrNull(
          (item) =>
              item.repositoryFullName == repositoryFullName &&
              item.branch == branch &&
              item.zipPath == project.path,
        );
    if (duplicate != null) {
      duplicate.addLog('Tentativa duplicada ignorada; o envio já está ativo');
      _emit();
      return duplicate;
    }

    final item = ManagedUpload(
      id: '${DateTime.now().microsecondsSinceEpoch}-${_sequence++}',
      repositoryFullName: repositoryFullName,
      branch: branch,
      zipPath: project.path,
      zipName: project.name,
      projectName: project.identityLabel,
      projectType: project.projectType,
      archiveBytes: project.archiveBytes,
      uncompressedBytes: project.uncompressedBytes,
      fileCount: project.fileCount,
      folderCount: project.folderCount,
      importantFiles: List<String>.from(project.importantFiles),
      commonRoot: project.commonRoot,
      packageName: project.packageName,
      applicationId: project.applicationId,
      version: project.version,
      versionCode: project.versionCode,
      status: ManagedUploadStatus.queued,
      createdAt: DateTime.now(),
      total: project.fileCount,
    )..addLog('Envio adicionado à fila');

    _items.insert(0, item);
    _queue.add(_QueuedUploadTask(item.id, buildOnly: false));
    _emit();
    _schedulePersist();
    unawaited(_drainQueue());
    return item;
  }

  ManagedUpload? find(String id) {
    for (final item in _items) {
      if (item.id == id) return item;
    }
    return null;
  }

  Future<void> retry(String id) async {
    final item = find(id);
    if (item == null || item.isActive || !item.canRetry) return;
    final buildOnly = item.failureStage == 'build' &&
        item.commitSha != null &&
        item.commitSha!.isNotEmpty;
    item.resetForRetry(buildOnly: buildOnly);
    _queue.add(_QueuedUploadTask(item.id, buildOnly: buildOnly));
    _emit();
    await _persistHistory();
    unawaited(_drainQueue());
  }

  Future<void> runBuildAnyway(String id) async {
    final item = find(id);
    if (item == null || item.isActive || !item.canRunBuildAnyway) return;
    item
      ..status = ManagedUploadStatus.queued
      ..phase = 'Aguardando execução da build'
      ..completedAt = null
      ..failedAt = null
      ..errorMessage = null
      ..errorCode = null
      ..failureStage = null;
    item.addLog('Execução da build solicitada mesmo sem alterações no ZIP');
    _queue.add(_QueuedUploadTask(item.id, buildOnly: true));
    _emit();
    await _persistHistory();
    unawaited(_drainQueue());
  }

  Future<void> removeFromHistory(String id) async {
    final item = find(id);
    if (item == null || item.isActive) return;
    _items.remove(item);
    _emit();
    await _persistHistory();
  }

  Future<void> clearFinishedHistory() async {
    _items.removeWhere((item) => !item.isActive);
    _emit();
    await _persistHistory();
  }

  Future<void> waitUntilIdle() async {
    while (_running || _queue.isNotEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  Future<void> _drainQueue() async {
    if (_running || _disposed) return;
    _running = true;
    try {
      while (_queue.isNotEmpty && !_disposed) {
        final task = _queue.removeAt(0);
        final item = find(task.id);
        if (item == null || !item.isActive) continue;
        await _runItem(item, buildOnly: task.buildOnly);
      }
    } finally {
      _running = false;
    }
  }

  Future<void> _runItem(
    ManagedUpload item, {
    required bool buildOnly,
  }) async {
    if (buildOnly) {
      await _runBuild(item);
      return;
    }

    final zip = File(item.zipPath);
    if (!await zip.exists()) {
      _fail(
        item,
        const InvalidZipException(
          'O ZIP original não está mais disponível no aparelho. Selecione o projeto novamente.',
          code: 'UPLOAD_ZIP_MISSING',
        ),
        stage: 'upload',
      );
      return;
    }

    item
      ..status = ManagedUploadStatus.syncing
      ..startedAt = DateTime.now()
      ..phase = 'Preparando sincronização'
      ..current = 0
      ..total = item.fileCount
      ..currentFile = null;
    item.addLog('Sincronização iniciada');
    _emit();
    _schedulePersist();

    try {
      final result = await _uploadZip(
        project: item.toProjectPreview(),
        repositoryFullName: item.repositoryFullName,
        branch: item.branch,
        commitMessage: '',
        onProgress: (progress) {
          item
            ..status = ManagedUploadStatus.syncing
            ..phase = progress.phase
            ..current = progress.current
            ..total = progress.total > 0 ? progress.total : item.fileCount
            ..currentFile = progress.fileName;
          final detail = progress.fileName?.trim().isNotEmpty == true
              ? '${progress.phase}: ${progress.fileName}'
              : progress.phase;
          item.addLog(detail);
          _emit();
          _schedulePersist();
        },
      );
      item
        ..commitSha = result.commitSha
        ..changed = result.changed
        ..current = item.fileCount
        ..total = item.fileCount
        ..currentFile = null;

      if (!result.changed) {
        item
          ..status = ManagedUploadStatus.noChanges
          ..phase = 'Projeto já está atualizado'
          ..completedAt = DateTime.now();
        item.addLog('Nenhuma alteração encontrada; nenhum commit foi criado');
        _emit();
        await _persistHistory();
        return;
      }

      item.addLog('Projeto sincronizado no commit ${_shortSha(result.commitSha)}');
      await _runBuild(item);
    } catch (error) {
      _fail(item, error, stage: 'upload');
    }
  }

  Future<void> _runBuild(ManagedUpload item) async {
    final commitSha = item.commitSha;
    if (commitSha == null || commitSha.isEmpty) {
      _fail(
        item,
        const RepositoryFileException(
          'Não há commit válido para iniciar a build.',
          code: 'UPLOAD_BUILD_COMMIT_MISSING',
        ),
        stage: 'build',
      );
      return;
    }

    item
      ..status = ManagedUploadStatus.startingBuild
      ..phase = 'Confirmando o disparo da build'
      ..current = item.fileCount
      ..total = item.fileCount
      ..currentFile = null;
    item.addLog('Verificando a build do commit ${_shortSha(commitSha)}');
    _emit();
    _schedulePersist();

    try {
      final launch = await _ensureBuild(
        repositoryFullName: item.repositoryFullName,
        branch: item.branch,
        commitSha: commitSha,
        onStatus: (status) {
          item.phase = status;
          item.addLog(status);
          _emit();
          _schedulePersist();
        },
        verificationAttempts: 5,
        verificationDelay: const Duration(seconds: 2),
        postDispatchDelay: const Duration(seconds: 2),
      );
      item
        ..workflowName = launch.workflow?.name
        ..workflowPath = launch.workflow?.path
        ..workflowRunId = launch.workflowRunId ??
            (launch.runs.isNotEmpty ? launch.runs.first.id : null)
        ..dispatchTriggered = launch.dispatchTriggered
        ..status = ManagedUploadStatus.completed
        ..phase = launch.dispatchTriggered
            ? 'Projeto atualizado • Build iniciada manualmente'
            : 'Projeto atualizado • Build iniciada'
        ..completedAt = DateTime.now()
        ..failedAt = null
        ..errorMessage = null
        ..errorCode = null
        ..failureStage = null;
      item.addLog(item.phase);
      _emit();
      await _persistHistory();
    } catch (error) {
      _fail(item, error, stage: 'build');
    }
  }

  void _fail(ManagedUpload item, Object error, {required String stage}) {
    final appError = error is AppException ? error : null;
    item
      ..status = ManagedUploadStatus.failed
      ..failedAt = DateTime.now()
      ..phase = stage == 'build' ? 'Falha ao iniciar a build' : 'Falha no envio'
      ..errorMessage = appError?.message ?? 'Não foi possível concluir o envio.'
      ..errorCode = appError?.technicalCode ?? error.runtimeType.toString()
      ..failureStage = stage
      ..currentFile = null;
    item.addLog('${item.phase}: ${item.errorMessage}');
    _emit();
    unawaited(_persistHistory());
  }

  Future<void> _restoreHistory() async {
    try {
      final file = await _historyFile();
      if (!await file.exists()) {
        _emit();
        return;
      }
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! List) return;
      final restored = decoded
          .whereType<Map>()
          .map((raw) => ManagedUpload.fromJson(Map<String, dynamic>.from(raw)))
          .where((item) => item.id.isNotEmpty)
          .toList(growable: false);
      for (final item in restored) {
        if (item.isActive) {
          item.markInterruptedByAppExit();
        }
      }
      final liveItems = List<ManagedUpload>.from(_items);
      final liveIds = liveItems.map((item) => item.id).toSet();
      final merged = <ManagedUpload>[
        ...liveItems,
        ...restored.where((item) => !liveIds.contains(item.id)),
      ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _items
        ..clear()
        ..addAll(merged);
      _emit();
      await _persistHistory();
    } catch (_) {
      // O histórico é auxiliar e nunca deve bloquear o aplicativo.
    }
  }

  void _schedulePersist() {
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 650), () {
      unawaited(_persistHistory());
    });
  }

  Future<void> _persistHistory() {
    final payload = jsonEncode(
      _items.take(80).map((item) => item.toJson()).toList(growable: false),
    );
    _persistTail = _persistTail.then((_) async {
      try {
        final file = await _historyFile();
        await file.parent.create(recursive: true);
        final temporary = File('${file.path}.tmp');
        await temporary.writeAsString(payload, flush: true);
        try {
          await temporary.rename(file.path);
        } on FileSystemException {
          if (await file.exists()) {
            await file.delete();
          }
          await temporary.rename(file.path);
        }
      } catch (_) {
        // Falha de histórico não invalida um envio em andamento.
      }
    });
    return _persistTail;
  }

  Future<File> _historyFile() async {
    final custom = _historyFileFactory;
    if (custom != null) return custom();
    final root = await getApplicationSupportDirectory();
    return File(p.join(root.path, 'uploads_history.json'));
  }

  void _emit() {
    if (!_disposed) {
      _controller.add(List<ManagedUpload>.unmodifiable(_items));
    }
  }

  String _shortSha(String sha) => sha.length > 7 ? sha.substring(0, 7) : sha;

  void dispose() {
    _disposed = true;
    _persistTimer?.cancel();
    unawaited(_persistHistory());
    _controller.close();
  }
}

class _QueuedUploadTask {
  const _QueuedUploadTask(this.id, {required this.buildOnly});

  final String id;
  final bool buildOnly;
}

extension _FirstWhereOrNull<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T value) test) {
    for (final value in this) {
      if (test(value)) return value;
    }
    return null;
  }
}
