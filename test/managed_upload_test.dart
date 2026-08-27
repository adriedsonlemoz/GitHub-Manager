import 'package:flutter_test/flutter_test.dart';
import 'package:github_manager/features/uploads/domain/managed_upload.dart';

void main() {
  test('active upload restored after app exit becomes interrupted', () {
    final item = ManagedUpload(
      id: '1',
      repositoryFullName: 'owner/repo',
      branch: 'main',
      zipPath: '/tmp/repo.zip',
      zipName: 'repo.zip',
      projectName: 'Repo',
      projectType: 'Flutter',
      archiveBytes: 10,
      uncompressedBytes: 20,
      fileCount: 3,
      folderCount: 1,
      importantFiles: const ['pubspec.yaml'],
      commonRoot: null,
      status: ManagedUploadStatus.syncing,
      createdAt: DateTime(2026, 8, 27),
      total: 3,
      current: 1,
    );

    final restored = ManagedUpload.fromJson(item.toJson());
    restored.markInterruptedByAppExit();

    expect(restored.status, ManagedUploadStatus.interrupted);
    expect(restored.canRetry, isTrue);
    expect(restored.errorCode, 'UPLOAD_APP_INTERRUPTED');
    expect(restored.technicalLog, contains('owner/repo'));
  });

  test('interruption during build keeps retry on build stage', () {
    final item = ManagedUpload(
      id: '2',
      repositoryFullName: 'owner/repo',
      branch: 'main',
      zipPath: '/tmp/repo.zip',
      zipName: 'repo.zip',
      projectName: 'Repo',
      projectType: 'Flutter',
      archiveBytes: 10,
      uncompressedBytes: 20,
      fileCount: 3,
      folderCount: 1,
      importantFiles: const ['pubspec.yaml'],
      commonRoot: null,
      status: ManagedUploadStatus.startingBuild,
      createdAt: DateTime(2026, 8, 27),
      total: 3,
      current: 3,
      commitSha: 'abcdef0123456789',
    );

    item.markInterruptedByAppExit();

    expect(item.failureStage, 'build');
  });
}
