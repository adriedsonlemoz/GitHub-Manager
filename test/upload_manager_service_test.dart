import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:github_manager/features/projects/domain/zip_project.dart';
import 'package:github_manager/features/repositories/domain/repository_git_models.dart';
import 'package:github_manager/features/uploads/data/upload_manager_service.dart';
import 'package:github_manager/features/uploads/domain/managed_upload.dart';

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('github-manager-upload-test');
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test('queues uploads sequentially and ignores active duplicate', () async {
    var activeUploads = 0;
    var maxConcurrent = 0;
    var uploadCount = 0;

    Future<ProjectUploadResult> upload({
      required ZipProjectPreview project,
      required String repositoryFullName,
      required String branch,
      required String commitMessage,
      void Function(ProjectUploadProgress progress)? onProgress,
    }) async {
      uploadCount++;
      activeUploads++;
      if (activeUploads > maxConcurrent) maxConcurrent = activeUploads;
      onProgress?.call(
        ProjectUploadProgress(
          phase: 'Enviando',
          current: 1,
          total: project.fileCount,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 25));
      activeUploads--;
      return ProjectUploadResult(
        commitSha: 'abcdef${uploadCount}1234567890',
        fileCount: project.fileCount,
        changed: true,
      );
    }

    Future<RepositoryBuildLaunchResult> ensure({
      required String repositoryFullName,
      required String branch,
      required String commitSha,
      void Function(String status)? onStatus,
      required int verificationAttempts,
      required Duration verificationDelay,
      required Duration postDispatchDelay,
    }) async {
      onStatus?.call('Build encontrada');
      return RepositoryBuildLaunchResult(
        commitSha: commitSha,
        runs: const [],
        workflow: null,
        dispatchTriggered: false,
      );
    }

    final history = File('${temp.path}/history.json');
    final manager = UploadManagerService.forTest(
      uploadZip: upload,
      ensureBuild: ensure,
      historyFileFactory: () async => history,
    );
    addTearDown(manager.dispose);

    final firstZip = File('${temp.path}/first.zip')..writeAsBytesSync([1]);
    final secondZip = File('${temp.path}/second.zip')..writeAsBytesSync([2]);
    final first = manager.startBuild(
      project: _preview(firstZip.path, 'First'),
      repositoryFullName: 'owner/first',
      branch: 'main',
    );
    final duplicate = manager.startBuild(
      project: _preview(firstZip.path, 'First'),
      repositoryFullName: 'owner/first',
      branch: 'main',
    );
    manager.startBuild(
      project: _preview(secondZip.path, 'Second'),
      repositoryFullName: 'owner/second',
      branch: 'main',
    );

    expect(duplicate.id, first.id);
    expect(manager.items, hasLength(2));

    await manager.waitUntilIdle();

    expect(maxConcurrent, 1);
    expect(uploadCount, 2);
    expect(
      manager.items.every((item) => item.status == ManagedUploadStatus.completed),
      isTrue,
    );
  });

  test('no-change upload can run current commit build without reuploading', () async {
    var uploadCount = 0;
    var buildCount = 0;

    Future<ProjectUploadResult> upload({
      required ZipProjectPreview project,
      required String repositoryFullName,
      required String branch,
      required String commitMessage,
      void Function(ProjectUploadProgress progress)? onProgress,
    }) async {
      uploadCount++;
      return ProjectUploadResult(
        commitSha: 'abcdef0123456789',
        fileCount: project.fileCount,
        changed: false,
      );
    }

    Future<RepositoryBuildLaunchResult> ensure({
      required String repositoryFullName,
      required String branch,
      required String commitSha,
      void Function(String status)? onStatus,
      required int verificationAttempts,
      required Duration verificationDelay,
      required Duration postDispatchDelay,
    }) async {
      buildCount++;
      return RepositoryBuildLaunchResult(
        commitSha: commitSha,
        runs: const [],
        workflow: null,
        dispatchTriggered: true,
        workflowRunId: 99,
      );
    }

    final zip = File('${temp.path}/same.zip')..writeAsBytesSync([1]);
    final manager = UploadManagerService.forTest(
      uploadZip: upload,
      ensureBuild: ensure,
      historyFileFactory: () async => File('${temp.path}/history.json'),
    );
    addTearDown(manager.dispose);

    final item = manager.startBuild(
      project: _preview(zip.path, 'Same'),
      repositoryFullName: 'owner/same',
      branch: 'main',
    );
    await manager.waitUntilIdle();

    expect(item.status, ManagedUploadStatus.noChanges);
    expect(item.canRunBuildAnyway, isTrue);
    expect(buildCount, 0);

    await manager.runBuildAnyway(item.id);
    await manager.waitUntilIdle();

    expect(uploadCount, 1);
    expect(buildCount, 1);
    expect(item.status, ManagedUploadStatus.completed);
    expect(item.workflowRunId, 99);
  });
}

ZipProjectPreview _preview(String path, String name) => ZipProjectPreview(
      path: path,
      name: '$name.zip',
      archiveBytes: 1,
      uncompressedBytes: 1,
      fileCount: 1,
      folderCount: 0,
      projectType: 'Flutter',
      importantFiles: const ['pubspec.yaml'],
      commonRoot: null,
      projectName: name,
      packageName: name.toLowerCase(),
      applicationId: 'br.com.test.${name.toLowerCase()}',
      version: '1.0.0',
      versionCode: 1,
    );
