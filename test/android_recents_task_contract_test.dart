import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('MainActivity reutiliza uma única task nos Recentes', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, contains('android:launchMode="singleTask"'));
    expect(manifest, contains('android:documentLaunchMode="never"'));
    expect(manifest, isNot(contains('android:taskAffinity=""')));
  });

  test('Activity não força NEW_TASK ao abrir URI ou instalar APK', () {
    final activity = File(
      'android/app/src/main/kotlin/br/com/githubmanager/app/MainActivity.kt',
    ).readAsStringSync();

    expect(activity, isNot(contains('Intent.FLAG_ACTIVITY_NEW_TASK')));
    expect(activity, contains('cleanupDuplicateRecentTasks()'));
    expect(activity, contains('activityManager.appTasks'));
    expect(activity, contains('appTask.finishAndRemoveTask()'));
    expect(activity, contains('appTask.taskInfo.id != taskId'));
  });

  test('notificações retornam explicitamente à MainActivity existente', () {
    for (final path in <String>[
      'android/app/src/main/kotlin/br/com/githubmanager/app/UploadForegroundService.kt',
      'android/app/src/main/kotlin/br/com/githubmanager/app/DownloadForegroundService.kt',
    ]) {
      final service = File(path).readAsStringSync();
      expect(service, contains('Intent(context, MainActivity::class.java).apply'));
      expect(service, contains('action = Intent.ACTION_MAIN'));
      expect(service, contains('addCategory(Intent.CATEGORY_LAUNCHER)'));
      expect(service, contains('putExtra("notificationRoute",'));
      expect(service, contains('PendingIntent.FLAG_UPDATE_CURRENT'));
      expect(service, contains('Intent.FLAG_ACTIVITY_CLEAR_TOP'));
      expect(service, contains('Intent.FLAG_ACTIVITY_SINGLE_TOP'));
      expect(service, isNot(contains('Intent.FLAG_ACTIVITY_NEW_TASK')));
    }
  });

  test('cada serviço preserva a rota específica ao reabrir a MainActivity', () {
    final upload = File(
      'android/app/src/main/kotlin/br/com/githubmanager/app/UploadForegroundService.kt',
    ).readAsStringSync();
    final download = File(
      'android/app/src/main/kotlin/br/com/githubmanager/app/DownloadForegroundService.kt',
    ).readAsStringSync();
    expect(upload, contains('"/uploads?uploadId="'));
    expect(upload, contains('android.net.Uri.encode(arguments.uploadId)'));
    expect(download, contains('"/downloads?downloadId="'));
    expect(download, contains('android.net.Uri.encode(arguments.downloadId)'));
    // Request codes distintos evitam mistura de destinos entre os serviços.
    expect(
      upload,
      contains('PendingIntent.getActivity(context, 9102, launch, flags)'),
    );
    expect(
      download,
      contains('PendingIntent.getActivity(context, 9202, launch, flags)'),
    );
  });
}
