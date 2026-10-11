import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:github_manager/core/notifications/notification_destination.dart';

void main() {
  test('notificação da build aponta para execução e branch corretas', () {
    final payload = NotificationDestination.forBuild(
      repository: 'usuario/meu-projeto',
      runId: 123456,
      branch: 'feature/teste 1',
    );
    final route = NotificationDestination.fromPayload(payload)!.route;
    final uri = Uri.parse(route);
    expect(uri.path, '/repositories/usuario/meu-projeto/builds');
    expect(uri.queryParameters['runId'], '123456');
    expect(uri.queryParameters['branch'], 'feature/teste 1');
  });

  test('download e envio levam à central com registro selecionado', () {
    final downloadRoute = NotificationDestination.fromPayload(
      NotificationDestination.forDownload('download:abc 1'),
    )!.route;
    expect(Uri.parse(downloadRoute).path, '/downloads');
    expect(Uri.parse(downloadRoute).queryParameters['downloadId'],
        'download:abc 1');
    final uploadRoute = NotificationDestination.fromPayload(
      NotificationDestination.forUpload('envio 42'),
    )!.route;
    expect(Uri.parse(uploadRoute).queryParameters['uploadId'], 'envio 42');
    expect(Uri.parse(uploadRoute).path, '/uploads');
  });

  test('notificações legadas continuam abrindo a área correta', () {
    expect(
      NotificationDestination.fromPayload('download:antigo')!.route,
      '/downloads?downloadId=antigo',
    );
    expect(
      NotificationDestination.fromPayload('owner/repo')!.route,
      '/repositories/owner/repo/builds',
    );
  });

  test('payloads inválidos não produzem rotas arbitrárias', () {
    for (final payload in <String>[
      'https://example.com/redirect',
      '../../settings',
      '{"type":"build","repository":"foo/../../admin","runId":99}',
      '{"type":"build","repository":"owner/repo","runId":-1}',
      '{"type":"upload","id":""}',
      'download:',
    ]) {
      expect(NotificationDestination.fromPayload(payload), isNull,
          reason: payload);
    }
    expect(NotificationDestination.fromNativeRoute('/settings'), isNull);
    expect(NotificationDestination.fromNativeRoute('https://bad.com/uploads'), isNull);
    expect(NotificationDestination.fromNativeRoute('/uploads?uploadId=1')!.route,
        '/uploads?uploadId=1');
  });

  test('captura toques com app aberto e fechado e passagem nativa', () {
    final service = File('lib/core/notifications/app_notification_service.dart')
        .readAsStringSync();
    final nav = File('lib/core/notifications/notification_navigation_service.dart')
        .readAsStringSync();
    final main = File('lib/main.dart').readAsStringSync();
    final activity = File(
      'android/app/src/main/kotlin/br/com/githubmanager/app/MainActivity.kt',
    ).readAsStringSync();
    expect(service, contains('onDidReceiveNotificationResponse'));
    expect(service, contains('getNotificationAppLaunchDetails'));
    expect(nav, contains("appRouter.go(destination.route)"));
    expect(nav, contains('consumeNotificationRoute'));
    expect(main, contains('NotificationNavigationService.start()'));
    expect(activity, contains('override fun onNewIntent(intent: Intent)'));
    expect(activity, contains('notificationTapped'));
    expect(activity, contains('consumeNotificationRoute'));
  });

  test('serviços nativos abrem a transferência correta', () {
    final download = File(
      'android/app/src/main/kotlin/br/com/githubmanager/app/DownloadForegroundService.kt',
    ).readAsStringSync();
    final upload = File(
      'android/app/src/main/kotlin/br/com/githubmanager/app/UploadForegroundService.kt',
    ).readAsStringSync();
    expect(download, contains('notificationRoute'));
    expect(download, contains('arguments.downloadId'));
    expect(upload, contains('notificationRoute'));
    expect(upload, contains('arguments.uploadId'));
  });
}
