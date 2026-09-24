import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:github_manager/core/network/github_api_client.dart';
import 'package:github_manager/core/persistence/local_database.dart';
import 'package:github_manager/core/security/secure_storage_service.dart';
import 'package:github_manager/features/builds/domain/action_artifact.dart';
import 'package:github_manager/features/builds/presentation/build_providers.dart';
import 'package:github_manager/features/permissions/data/permission_preflight_service.dart';
import 'package:github_manager/features/permissions/data/token_permission_diagnostics_service.dart';
import 'package:github_manager/features/permissions/domain/repository_permission_preflight.dart';
import 'package:github_manager/features/permissions/presentation/token_permission_providers.dart';
import 'package:github_manager/features/projects/data/git_project_upload_service.dart';
import 'package:github_manager/features/projects/data/local_project_service.dart';
import 'package:github_manager/features/projects/domain/zip_project.dart';
import 'package:github_manager/features/projects/presentation/project_providers.dart';
import 'package:github_manager/features/repositories/data/repository_git_service.dart';
import 'package:github_manager/features/repositories/data/repository_project_info_service.dart';
import 'package:github_manager/features/repositories/data/repository_service.dart';
import 'package:github_manager/features/repositories/domain/github_repository.dart';
import 'package:github_manager/features/repositories/domain/repository_git_models.dart';
import 'package:github_manager/features/repositories/domain/repository_project_info.dart';
import 'package:github_manager/features/repositories/presentation/repository_detail_screen.dart';
import 'package:github_manager/features/repositories/presentation/repository_providers.dart';
import 'package:github_manager/features/uploads/data/upload_manager_service.dart';
import 'package:github_manager/features/uploads/domain/managed_upload.dart';
import 'package:github_manager/features/uploads/presentation/upload_providers.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets(
    'envio real pela interface escolhe branch antes do pre-check e respeita build desmarcada',
    (tester) async {
      final temp = Directory.systemTemp.createTempSync('github_manager_send_flow_');
      addTearDown(() => temp.deleteSync(recursive: true));
      final zip = File('${temp.path}/repo-v2.0.82.zip')..writeAsBytesSync([1, 2, 3, 4]);
      final events = <String>[];

      final project = ZipProjectPreview(
        path: zip.path,
        name: 'repo-v2.0.82.zip',
        archiveBytes: 4,
        uncompressedBytes: 4,
        fileCount: 1,
        folderCount: 0,
        projectType: 'Flutter',
        importantFiles: const ['pubspec.yaml', '.github/workflows/android.yml'],
        commonRoot: null,
        projectName: 'Repo',
        packageName: 'repo',
        applicationId: 'com.example.repo',
        version: '2.0.82',
        versionCode: 200096,
        hasWorkflowFiles: true,
      );

      final gitService = _FakeRepositoryGitService(events);
      final permissionService = _AllowPermissionService(events);
      final manager = UploadManagerService.forTest(
        uploadZip: ({
          required ZipProjectPreview project,
          required String repositoryFullName,
          required String branch,
          required String commitMessage,
          void Function(ProjectUploadProgress progress)? onProgress,
          required Map<String, String> reusableBlobShas,
          void Function(String path, String sha)? onBlobUploaded,
          required ProjectUploadMethod method,
          required bool allowAutomaticRecovery,
        }) async => ProjectUploadResult(
          commitSha: 'abcdef123456',
          fileCount: project.fileCount,
          changed: true,
          method: method,
          commitCount: 1,
        ),
        ensureBuild: ({
          required String repositoryFullName,
          required String branch,
          required String commitSha,
          void Function(String status)? onStatus,
          required int verificationAttempts,
          required Duration verificationDelay,
          required Duration postDispatchDelay,
        }) async => throw StateError('Build não deveria ser chamada neste teste.'),
        historyFileFactory: () async => File('${temp.path}/history.json'),
        queueDirectoryFactory: () async => Directory('${temp.path}/queue')..createSync(recursive: true),
        automaticRecoveryEnabled: () async => false,
      );
      addTearDown(manager.dispose);

      final router = GoRouter(
        initialLocation: '/repositories/owner/repo',
        routes: [
          GoRoute(
            path: '/repositories/:owner/:repo',
            builder: (_, __) => const RepositoryDetailScreen(
              repositoryFullName: 'owner/repo',
            ),
          ),
          GoRoute(
            path: '/uploads',
            builder: (_, __) => const Scaffold(body: Text('uploads')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryServiceProvider.overrideWithValue(_FakeRepositoryService()),
            repositoryGitServiceProvider.overrideWithValue(gitService),
            repositoryProjectInfoServiceProvider.overrideWithValue(
              _FakeRepositoryProjectInfoService(),
            ),
            localProjectServiceProvider.overrideWithValue(_FakeLocalProjectService(project)),
            gitProjectUploadServiceProvider.overrideWithValue(_FakeGitProjectUploadService()),
            permissionPreflightServiceProvider.overrideWithValue(permissionService),
            uploadManagerProvider.overrideWithValue(manager),
            repositoryArtifactsProvider('owner/repo').overrideWith(
              (ref) async => const <ActionArtifact>[],
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Enviar').first);
      await tester.pumpAndSettle();

      expect(find.text('Escolher branch'), findsOneWidget);
      await tester.tap(find.text('develop'));
      await tester.pumpAndSettle();

      expect(find.text('Conferir envio'), findsOneWidget);
      expect(find.text('develop'), findsWidgets);
      expect(find.text('Iniciar build após o envio'), findsOneWidget);

      final buildToggle = find.text('Iniciar build após o envio');
      await tester.ensureVisible(buildToggle);
      await tester.pumpAndSettle();
      await tester.tap(buildToggle);
      await tester.pump();
      await tester.tap(find.text('Enviar versão'));
      await tester.pump();
      await manager.waitUntilIdle();

      expect(manager.items, hasLength(1));
      expect(manager.items.single.branch, 'develop');
      expect(manager.items.single.buildPolicy, ManagedUploadBuildPolicy.skipByUser);

      final branchesIndex = events.indexOf('branches');
      final permissionIndex = events.indexWhere((event) => event.startsWith('permission:'));
      expect(branchesIndex, greaterThanOrEqualTo(0));
      expect(permissionIndex, greaterThan(branchesIndex));
      expect(events[permissionIndex], 'permission:syncProjectWithWorkflows');
    },
  );
}

const _repository = GitHubRepository(
  id: 1,
  name: 'repo',
  fullName: 'owner/repo',
  isPrivate: false,
  isArchived: false,
  defaultBranch: 'main',
  updatedAt: null,
  htmlUrl: 'https://example.invalid/owner/repo',
  language: 'Dart',
);

class _FakeLocalProjectService extends LocalProjectService {
  _FakeLocalProjectService(this.project);

  final ZipProjectPreview project;

  @override
  Future<ZipProjectPreview?> pickAndAnalyzeZip() async => project;
}

class _FakeGitProjectUploadService extends GitProjectUploadService {
  _FakeGitProjectUploadService() : super(GitHubApiClient(SecureStorageService()));

  @override
  Future<ProjectSyncPreview> previewZipSync({
    required ZipProjectPreview project,
    required String repositoryFullName,
    required String branch,
  }) async =>
      const ProjectSyncPreview(
        createdPaths: ['lib/new.dart'],
        modifiedPaths: ['pubspec.yaml'],
        deletedPaths: [],
        unchangedCount: 3,
      );
}

class _FakeRepositoryService extends RepositoryService {
  _FakeRepositoryService()
      : super(GitHubApiClient(SecureStorageService()), LocalDatabase.shared);

  @override
  Future<GitHubRepository> getRepository(String fullName) async => _repository;
}

class _FakeRepositoryGitService extends RepositoryGitService {
  _FakeRepositoryGitService(this.events)
      : super(GitHubApiClient(SecureStorageService()));

  final List<String> events;

  @override
  Future<List<RepositoryWorkflowRun>> listWorkflowRuns(String repositoryFullName) async =>
      const <RepositoryWorkflowRun>[];

  @override
  Future<List<RepositoryBranch>> listBranches(String repositoryFullName) async {
    events.add('branches');
    return const [
      RepositoryBranch(name: 'main', sha: 'main-sha', isProtected: false),
      RepositoryBranch(name: 'develop', sha: 'develop-sha', isProtected: false),
    ];
  }

  @override
  Future<GitHubRateLimitSnapshot> loadRateLimit() async =>
      const GitHubRateLimitSnapshot(
        limit: 5000,
        remaining: 4900,
        used: 100,
        resetAt: null,
      );
}

class _FakeRepositoryProjectInfoService extends RepositoryProjectInfoService {
  _FakeRepositoryProjectInfoService()
      : super(GitHubApiClient(SecureStorageService()));

  @override
  Future<RepositoryProjectInfo> load(
    GitHubRepository repository, {
    String? branch,
  }) async =>
      const RepositoryProjectInfo(
        projectName: 'Repo',
        version: '2.0.80',
        technologies: ['Dart'],
        packageName: 'repo',
        applicationId: 'com.example.repo',
        versionCode: 200094,
      );
}

class _AllowPermissionService extends PermissionPreflightService {
  _AllowPermissionService(this.events)
      : super.withTokenReader(
          TokenPermissionDiagnosticsService.withGateway(_UnusedGateway()),
          () async => 'token',
        );

  final List<String> events;

  @override
  Future<RepositoryPermissionPreflightDecision> check(
    String repositoryFullName,
    RepositoryCriticalAction action, {
    bool forceRefresh = false,
  }) async {
    events.add('permission:${action.name}');
    return RepositoryPermissionPreflightDecision(
      action: action,
      repositoryFullName: repositoryFullName,
      blocked: false,
      denied: const [],
      unknown: const [],
    );
  }
}

class _UnusedGateway implements TokenPermissionDiagnosticsGateway {
  @override
  Future<String?> readToken() async => 'token';

  @override
  Future<PermissionProbe> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async =>
      const PermissionProbe(statusCode: 500, data: null);
}
