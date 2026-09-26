import 'package:flutter_test/flutter_test.dart';
import 'package:github_manager/features/downloads/domain/managed_download.dart';

void main() {
  test('managed download persists diagnostic fields and retry source', () {
    final item = ManagedDownload(
      id: '1',
      title: 'APK',
      fileName: 'GitHub-Manager.apk',
      type: ManagedDownloadType.apk,
      status: ManagedDownloadStatus.failed,
      createdAt: DateTime.utc(2026, 8, 26),
      repositoryFullName: 'owner/repo',
      sourceEndpoint: '/repos/owner/repo/actions/artifacts/10/zip',
      artifactId: 10,
      receivedBytes: 1024,
      totalBytes: 2048,
      errorMessage: 'Artifact expirado.',
      errorCode: 'DOWNLOAD_EXPIRED',
      failureStage: 'obter_url',
      httpStatus: 410,
    );

    final restored = ManagedDownload.fromJson(item.toJson());
    expect(restored.canRetry, isTrue);
    expect(restored.httpStatus, 410);
    expect(restored.artifactId, 10);
    expect(restored.technicalLog, contains('HTTP: 410'));
    expect(restored.technicalLog, isNot(contains('Authorization')));
  });

  test('active download can be restored as interrupted and retried', () {
    final item = ManagedDownload(
      id: '2',
      title: 'Release privada',
      fileName: 'app-release.apk',
      type: ManagedDownloadType.apk,
      status: ManagedDownloadStatus.downloading,
      createdAt: DateTime.utc(2026, 8, 26),
      repositoryFullName: 'owner/private',
      sourceEndpoint: '/repos/owner/private/releases/assets/77',
    );

    item.markInterruptedByAppExit();
    final restored = ManagedDownload.fromJson(item.toJson());

    expect(restored.status, ManagedDownloadStatus.interrupted);
    expect(restored.statusLabel, 'Interrompido');
    expect(restored.canRetry, isTrue);
    expect(restored.errorCode, 'DOWNLOAD_APP_INTERRUPTED');
  });

  test('artifact APK keeps ABI preference across persistence and retry', () {
    final item = ManagedDownload(
      id: 'abi-1',
      title: 'APK ARM',
      fileName: 'app-arm64-v8a.apk',
      type: ManagedDownloadType.apk,
      status: ManagedDownloadStatus.interrupted,
      createdAt: DateTime.utc(2026, 9, 26),
      repositoryFullName: 'owner/repo',
      sourceEndpoint: '/repos/owner/repo/actions/artifacts/11/zip',
      artifactId: 11,
      preferredAbi: 'arm64-v8a',
      preferredAbis: const ['arm64-v8a', 'armeabi-v7a'],
    );

    final restored = ManagedDownload.fromJson(item.toJson());

    expect(restored.preferredAbi, 'arm64-v8a');
    expect(restored.preferredAbis, ['arm64-v8a', 'armeabi-v7a']);
    expect(restored.technicalLog, contains('ABI preferida: arm64-v8a'));
  });

  test('partial download persists working path and can resume', () {
    final item = ManagedDownload(
      id: '3',
      title: 'APK parcial',
      fileName: 'app.apk',
      type: ManagedDownloadType.apk,
      status: ManagedDownloadStatus.interrupted,
      createdAt: DateTime.utc(2026, 8, 27),
      repositoryFullName: 'owner/repo',
      sourceEndpoint: '/repos/owner/repo/releases/assets/88',
      receivedBytes: 4096,
      totalBytes: 8192,
      workingPath: '/private/download_work/app.apk.part',
    );

    final restored = ManagedDownload.fromJson(item.toJson());

    expect(restored.workingPath, '/private/download_work/app.apk.part');
    expect(restored.receivedBytes, 4096);
    expect(restored.canResume, isTrue);
  });

}
