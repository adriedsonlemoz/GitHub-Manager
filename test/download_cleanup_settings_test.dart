import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:github_manager/features/downloads/data/download_cleanup_settings.dart';
import 'package:github_manager/features/downloads/domain/managed_download.dart';

void main() {
  test('três modalidades e padrão seguro depois da conclusão', () {
    expect(DownloadCleanupMode.values, hasLength(3));
    expect(DownloadCleanupSettings.label(DownloadCleanupMode.afterSuccess),
        contains('concluir'));
    expect(DownloadCleanupSettings.label(DownloadCleanupMode.beforeStart),
        contains('iniciar'));
    expect(DownloadCleanupSettings.label(DownloadCleanupMode.disabled),
        'Desativada');
  });

  test('alerta de falha de limpeza é conservado no histórico', () {
    final item = ManagedDownload(
      id: 'abc',
      title: 'Vigia IA',
      fileName: 'app.apk',
      type: ManagedDownloadType.apk,
      status: ManagedDownloadStatus.completed,
      createdAt: DateTime.utc(2026, 10, 16),
      repositoryFullName: 'owner/vigia',
      cleanupWarning: 'Arquivo salvo, mas a limpeza automática não foi concluída.',
    );
    expect(
      ManagedDownload.fromJson(item.toJson()).cleanupWarning,
      contains('não foi concluída'),
    );
  });

  test('salvar antes de limpar e limpar antes de baixar são fluxos separados', () {
    final service = File('lib/features/downloads/data/download_manager_service.dart')
        .readAsStringSync();
    final before = service.indexOf('Future<void> _cleanBeforeStart(');
    final publish = service.indexOf('Future<void> _publishCompleted(');
    expect(before, greaterThan(0));
    expect(publish, greaterThan(before));
    expect(service, contains('DownloadCleanupMode.beforeStart'));
    expect(service, contains('DownloadCleanupMode.disabled'));
    expect(service, contains('await _cleanManagedProject(item, keepLocation: location)'));
    expect(service, contains('_withProjectCleanupLock(projectFolder, publishAndClean)'));
    expect(service, contains('previous.status != ManagedDownloadStatus.completed'));
    expect(service, contains('if (location.startsWith(\'content://\')) continue'));
  });

  test('limpeza nativa limita pasta e proprietário, protegendo parciais', () {
    final native = File('android/app/src/main/kotlin/br/com/githubmanager/app/MainActivity.kt')
        .readAsStringSync();
    expect(native, contains('cleanupManagedProjectDownloads('));
    expect(native, contains('MediaStore.MediaColumns.OWNER_PACKAGE_NAME'));
    expect(native, contains('owner != packageName'));
    expect(native, contains('MediaStore.MediaColumns.IS_PENDING'));
    expect(native, contains('Environment.DIRECTORY_DOWNLOADS'));
    expect(native, contains('if (location == keepLocation) continue'));
  });

  test('configurações expõem seletor persistente sem limpar outras pastas', () {
    final screen = File('lib/features/settings/presentation/settings_screen.dart')
        .readAsStringSync();
    final actions = File('lib/features/settings/presentation/settings_screen_actions.dart')
        .readAsStringSync();
    expect(screen, contains('Limpeza automática dos downloads'));
    expect(screen, contains('_chooseDownloadCleanupMode'));
    expect(actions, contains('DownloadCleanupSettings.write('));
    expect(actions, contains('DownloadCleanupSettings.read('));
    expect(actions, contains('DownloadCleanupMode.values'));
  });
}
