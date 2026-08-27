import 'package:flutter_test/flutter_test.dart';
import 'package:github_manager/features/projects/domain/zip_project.dart';
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

  test('technical report summarizes file activity without noisy per-file lines', () {
    final item = ManagedUpload(
      id: '4',
      repositoryFullName: 'owner/repo',
      branch: 'main',
      zipPath: '/tmp/repo.zip',
      zipName: 'repo-2.0.24.zip',
      projectName: 'Repo',
      projectType: 'Flutter',
      archiveBytes: 100,
      uncompressedBytes: 200,
      fileCount: 405,
      folderCount: 40,
      importantFiles: const ['pubspec.yaml'],
      commonRoot: null,
      status: ManagedUploadStatus.completed,
      createdAt: DateTime(2026, 8, 27, 8),
      startedAt: DateTime(2026, 8, 27, 8, 20),
      completedAt: DateTime(2026, 8, 27, 8, 23, 11),
      commitSha: '41cba0a6557cbf0ba21c11af570bf83cb195858e',
      workflowName: 'Android APK',
      workflowPath: '.github/workflows/android-apk.yml',
      workflowRunId: 33067130089,
      dispatchTriggered: false,
      phase: 'Projeto atualizado • Build iniciada',
    );

    item.recordProgress(
      const ProjectUploadProgress(
        phase: 'Arquivo já está atualizado',
        fileName: 'lib/main.dart',
        kind: ProjectUploadProgressKind.unchanged,
      ),
    );
    item.recordProgress(
      const ProjectUploadProgress(
        phase: 'Processando arquivos do projeto',
        fileName: 'pubspec.yaml',
        kind: ProjectUploadProgressKind.changed,
      ),
    );
    item.addLog('Arquivo já está atualizado: lib/main.dart');
    item.addLog('Preparando sincronização no GitHub');
    item.addLog('Criando commit');
    item.addLog('Projeto atualizado • Build iniciada');

    expect(item.unchangedFiles, 1);
    expect(item.changedFiles, 1);
    expect(item.changedFileSamples, contains('pubspec.yaml'));
    expect(item.timelineLines, isNot(contains('Arquivo já está atualizado: lib/main.dart')));
    expect(item.technicalLog, contains('RELATÓRIO DE ENVIO'));
    expect(item.technicalLog, contains('Já atualizados: 1'));
    expect(item.technicalLog, contains('Alterados nesta tentativa: 1'));
    expect(item.technicalLog, contains('Build: Iniciada automaticamente pelo push'));
    expect(item.technicalLog, contains('Run ID: 33067130089'));
    expect(item.technicalLog, isNot(contains('Arquivo já está atualizado: lib/main.dart')));
  });

  test('file summary counters survive JSON round trip', () {
    final item = ManagedUpload(
      id: '5',
      repositoryFullName: 'owner/repo',
      branch: 'main',
      zipPath: '/tmp/repo.zip',
      zipName: 'repo.zip',
      projectName: 'Repo',
      projectType: 'Flutter',
      archiveBytes: 10,
      uncompressedBytes: 20,
      fileCount: 4,
      folderCount: 1,
      importantFiles: const ['pubspec.yaml'],
      commonRoot: null,
      status: ManagedUploadStatus.syncing,
      createdAt: DateTime(2026, 8, 27),
      unchangedFiles: 2,
      changedFiles: 1,
      resumedFiles: 1,
      removedFiles: 3,
      changedFileSamples: const ['pubspec.yaml'],
    );

    final restored = ManagedUpload.fromJson(item.toJson());

    expect(restored.unchangedFiles, 2);
    expect(restored.changedFiles, 1);
    expect(restored.resumedFiles, 1);
    expect(restored.removedFiles, 3);
    expect(restored.changedFileSamples, ['pubspec.yaml']);
  });
}
