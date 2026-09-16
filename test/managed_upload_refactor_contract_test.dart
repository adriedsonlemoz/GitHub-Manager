import 'package:flutter_test/flutter_test.dart';
import 'package:github_manager/features/projects/domain/zip_project.dart';
import 'package:github_manager/features/uploads/domain/managed_upload.dart';

void main() {
  test('ManagedUpload keeps state, diagnostics, report and codec contracts', () {
    final item = ManagedUpload(
      id: 'refactor-contract',
      repositoryFullName: 'owner/repo',
      branch: 'main',
      zipPath: '/tmp/repo.zip',
      sourceZipPath: '/storage/repo.zip',
      zipName: 'repo.zip',
      projectName: 'Repo',
      projectType: 'Flutter',
      archiveBytes: 100,
      uncompressedBytes: 200,
      fileCount: 4,
      folderCount: 2,
      importantFiles: const ['pubspec.yaml'],
      commonRoot: 'repo',
      status: ManagedUploadStatus.failed,
      createdAt: DateTime(2026, 9, 16, 12),
      startedAt: DateTime(2026, 9, 16, 12, 1),
      failedAt: DateTime(2026, 9, 16, 12, 2),
      current: 4,
      total: 4,
      version: '2.0.72',
      versionCode: 200086,
      commitSha: 'abcdef0123456789',
      changed: true,
      workflowName: 'Android APK',
      workflowPath: '.github/workflows/android-apk.yml',
      workflowRunId: 123,
      dispatchTriggered: false,
      errorMessage: 'Validation Failed',
      errorCode: 'GITHUB_VALIDATION',
      errorHttpStatus: 422,
      errorEndpoint: '/repos/owner/repo/git/trees',
      errorApiMessage: 'Validation Failed',
      failureStage: 'upload',
      failureOperation: 'Criando árvore',
      uploadMethod: ProjectUploadMethod.incremental,
      changedFiles: 2,
      unchangedFiles: 2,
      changedFileSamples: const ['pubspec.yaml'],
      logLines: <String>['Sincronização iniciada', 'Criando commit'],
    );

    expect(item.statusLabel, 'Falhou');
    expect(item.versionLabel, '2.0.72+200086');
    expect(item.syncSummaryLabel, contains('4 analisados'));
    expect(item.recommendedRecoveryMethod, ProjectUploadMethod.fullTree);
    expect(item.failureDiagnosticText, contains('DIAGNÓSTICO DA FALHA'));
    expect(item.timelineLines, contains('Comparando o projeto com o repositório'));
    expect(item.technicalLog, contains('RELATÓRIO DE ENVIO'));

    final restored = ManagedUpload.fromJson(item.toJson());
    expect(restored.repositoryFullName, item.repositoryFullName);
    expect(restored.commitSha, item.commitSha);
    expect(restored.workflowRunId, 123);
    expect(restored.changedFileSamples, ['pubspec.yaml']);

    restored.resetForRetry(
      buildOnly: false,
      method: ProjectUploadMethod.fullTree,
    );
    expect(restored.status, ManagedUploadStatus.queued);
    expect(restored.uploadMethod, ProjectUploadMethod.fullTree);
    expect(restored.commitSha, isNull);
  });
}
