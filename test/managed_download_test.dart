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
}
