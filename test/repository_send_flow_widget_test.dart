import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:github_manager/core/network/github_api_client.dart';
import 'package:github_manager/core/security/secure_storage_service.dart';
import 'package:github_manager/features/projects/domain/zip_project.dart';
import 'package:github_manager/features/repositories/data/repository_git_service.dart';
import 'package:github_manager/features/repositories/domain/repository_git_models.dart';
import 'package:github_manager/features/repositories/presentation/repository_branch_selector.dart';
import 'package:github_manager/features/repositories/presentation/repository_providers.dart';
import 'package:github_manager/features/uploads/data/upload_manager_service.dart';
import 'package:github_manager/features/uploads/domain/managed_upload.dart';
import 'package:github_manager/features/uploads/presentation/upload_progress_dialog.dart';
import 'package:github_manager/features/uploads/presentation/upload_providers.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets(
    'seletor de branch retorna a branch tocada sem depender do fluxo completo de envio',
    (tester) async {
      final gitService = _FakeRepositoryGitService();
      RepositoryBranch? selected;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryGitServiceProvider.overrideWithValue(gitService),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) => Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () async {
                      selected = await showRepositoryBranchSelector(
                        context: context,
                        ref: ref,
                        repositoryFullName: 'owner/repo',
                        currentBranch: 'main',
                        defaultBranch: 'main',
                      );
                    },
                    child: const Text('Escolher branch'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Escolher branch'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('main'), findsOneWidget);
      expect(find.text('develop'), findsOneWidget);

      final developTile = find.byKey(
        const ValueKey('repository_branch_develop'),
      );
      expect(developTile, findsOneWidget);
      await tester.ensureVisible(developTile);
      await tester.pump(const Duration(milliseconds: 120));
      await tester.tap(developTile);
      await tester.pump(const Duration(milliseconds: 400));

      expect(selected?.name, 'develop');
      expect(find.text('develop'), findsNothing);
    },
  );

  testWidgets(
    'dialogo de progresso pode ser minimizado mesmo com progresso indeterminado',
    (tester) async {
      final project = ZipProjectPreview(
        path: '/tmp/repo-v2.0.91.zip',
        name: 'repo-v2.0.91.zip',
        archiveBytes: 4,
        uncompressedBytes: 4,
        fileCount: 1,
        folderCount: 0,
        projectType: 'Flutter',
        importantFiles: const ['pubspec.yaml'],
        commonRoot: null,
        projectName: 'Repo',
        packageName: 'repo',
        applicationId: 'com.example.repo',
        version: '2.0.91',
        versionCode: 200105,
        hasWorkflowFiles: false,
      );

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
        }) async => throw StateError('Build não deve ser executada neste teste.'),
        runBackgroundQueue: false,
      );
      final upload = manager.startBuild(
        project: project,
        repositoryFullName: 'owner/repo',
        branch: 'develop',
        buildPolicy: ManagedUploadBuildPolicy.skipByUser,
      );

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => UploadProgressDialog(uploadId: upload.id),
                    ),
                    child: const Text('Abrir progresso'),
                  ),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/uploads',
            builder: (_, _) => const Scaffold(body: Text('uploads')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            uploadManagerProvider.overrideWithValue(manager),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await tester.tap(find.text('Abrir progresso'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Minimizar'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      await tester.tap(find.text('Minimizar'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Minimizar'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      router.dispose();
      await manager.dispose();
    },
  );
}

class _FakeRepositoryGitService extends RepositoryGitService {
  _FakeRepositoryGitService()
      : super(GitHubApiClient(SecureStorageService()));

  @override
  Future<List<RepositoryBranch>> listBranches(String repositoryFullName) async {
    return const [
      RepositoryBranch(name: 'main', sha: 'main-sha', isProtected: false),
      RepositoryBranch(name: 'develop', sha: 'develop-sha', isProtected: false),
    ];
  }
}
