import 'package:github_manager/core/platform/platform_actions.dart';
import 'package:github_manager/features/uploads/domain/managed_upload.dart';

abstract interface class UploadForegroundController {
  Future<void> show({
    required ManagedUpload upload,
    required int activeCount,
  });

  Future<void> stop();
}

class PlatformUploadForegroundController implements UploadForegroundController {
  bool _started = false;
  Future<void> _operationTail = Future<void>.value();

  @override
  Future<void> show({
    required ManagedUpload upload,
    required int activeCount,
  }) =>
      _enqueue(() async {
        try {
          await PlatformActions.showUploadForegroundService(
            startService: !_started,
            uploadId: upload.id,
            projectName: upload.projectName,
            repositoryFullName: upload.repositoryFullName,
            phase: upload.phase,
            current: upload.current,
            total: upload.total,
            indeterminate: upload.progress == null,
            activeCount: activeCount,
          );
          _started = true;
        } catch (_) {
          // A proteção principal continua sendo o checkpoint persistido. Falha
          // na notificação/serviço não invalida a sincronização com o GitHub.
        }
      });

  @override
  Future<void> stop() => _enqueue(() async {
        if (!_started) return;
        try {
          await PlatformActions.stopUploadForegroundService();
        } catch (_) {
          // Encerrar a notificação é auxiliar e não altera o resultado do envio.
        } finally {
          _started = false;
        }
      });

  Future<void> _enqueue(Future<void> Function() operation) {
    final next = _operationTail.then((_) => operation());
    _operationTail = next.catchError((_) {});
    return next;
  }
}
