import 'package:flutter_local_notifications/flutter_local_notifications.dart';

abstract final class AppNotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_launcher'),
    );
    await _notifications.initialize(settings: settings);
    _initialized = true;
  }

  static Future<bool> requestPermission() async {
    try {
      await initialize();
      final android = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final result = await android?.requestNotificationsPermission();
      return result ?? true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> showBuildResult({
    required int id,
    required String repository,
    required String workflowName,
    required int? runNumber,
    required String conclusion,
  }) async {
    await initialize();
    final (title, status) = switch (conclusion) {
      'success' => ('Build concluída ✓', 'concluída com sucesso'),
      'failure' => ('Build falhou', 'falhou'),
      'cancelled' => ('Build cancelada', 'foi cancelada'),
      'timed_out' => ('Build excedeu o tempo', 'excedeu o tempo limite'),
      _ => ('Build precisa de atenção', 'precisa de atenção'),
    };
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'github_build_status',
        'Status das builds',
        channelDescription: 'Avisos quando uma execução do GitHub Actions termina.',
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.status,
      ),
    );
    final number = runNumber == null ? '' : ' #$runNumber';
    try {
      await _notifications.show(
        id: id & 0x7fffffff,
        title: title,
        body: '$repository • $workflowName$number $status.',
        notificationDetails: details,
        payload: repository,
      );
    } catch (_) {
      // Notificação nunca invalida a operação principal.
    }
  }

  static Future<void> showDownloadCompleted({
    required String id,
    required String fileName,
    required String repository,
  }) async {
    await initialize();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'github_download_results',
        'Downloads concluídos',
        channelDescription: 'Avisos imediatos quando um download termina ou falha.',
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.status,
      ),
    );
    try {
      await _notifications.show(
        id: _stableId('download:$id'),
        title: 'Download concluído ✓',
        body: repository.trim().isEmpty
            ? fileName
            : '$fileName • $repository',
        notificationDetails: details,
        payload: 'download:$id',
      );
    } catch (_) {
      // O arquivo já foi salvo; falha visual não muda o download.
    }
  }

  static Future<void> showDownloadFailed({
    required String id,
    required String fileName,
    required String message,
  }) async {
    await initialize();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'github_download_results',
        'Downloads concluídos',
        channelDescription: 'Avisos imediatos quando um download termina ou falha.',
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.status,
      ),
    );
    try {
      await _notifications.show(
        id: _stableId('download:$id'),
        title: 'Download com falha',
        body: '$fileName • $message',
        notificationDetails: details,
        payload: 'download:$id',
      );
    } catch (_) {
      // A Central de Downloads continua exibindo a falha normalmente.
    }
  }

  static int _stableId(String value) {
    var hash = 0x811c9dc5;
    for (final code in value.codeUnits) {
      hash ^= code;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }
}
