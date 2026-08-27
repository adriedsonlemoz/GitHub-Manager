import 'package:flutter_test/flutter_test.dart';
import 'package:github_manager/features/uploads/domain/managed_upload.dart';

void main() {
  test('upload without resume source can be marked interrupted', () {
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

  test('checkpoint survives JSON round trip and exposes resume label', () {
    final item = ManagedUpload(
      id: '3',
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
      uploadedBlobShas: const {
        'assets/a.bin': 'sha-a',
        'assets/b.bin': 'sha-b',
      },
    );

    final restored = ManagedUpload.fromJson(item.toJson());

    expect(restored.uploadedBlobShas, item.uploadedBlobShas);
    restored.uploadedBlobShas.clear();
    expect(restored.uploadedBlobShas, isEmpty);
    restored.uploadedBlobShas.addAll(item.uploadedBlobShas);
    expect(restored.hasCheckpoint, isTrue);
    expect(restored.checkpointLabel, contains('2 arquivo(s)'));
    restored.prepareAutomaticResume(buildOnly: false);
    expect(restored.status, ManagedUploadStatus.queued);
    expect(restored.logLines.join(' '), contains('2 blob(s)'));
  });
}
