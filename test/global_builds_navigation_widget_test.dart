import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:github_manager/features/builds/domain/global_build_entry.dart';
import 'package:github_manager/features/builds/presentation/build_providers.dart';
import 'package:github_manager/features/builds/presentation/global_builds_screen.dart';
import 'package:github_manager/features/repositories/domain/github_repository.dart';
import 'package:github_manager/features/repositories/domain/repository_git_models.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('card global abre a execução específica e preserva a branch', (
    tester,
  ) async {
    final repository = GitHubRepository(
      id: 1,
      name: 'app-teste',
      fullName: 'owner/app-teste',
      isPrivate: true,
      isArchived: false,
      defaultBranch: 'main',
      updatedAt: DateTime.utc(2026, 9, 23),
      htmlUrl: 'https://github.com/owner/app-teste',
    );
    final run = RepositoryWorkflowRun(
      id: 9876,
      workflowId: 42,
      workflowPath: '.github/workflows/android-apk.yml',
      name: 'Android APK',
      title: 'Build 2.0.78',
      status: 'completed',
      conclusion: 'success',
      branch: 'release/2.0',
      headSha: 'abcdef0123456789',
      commitMessage: 'Release 2.0.78',
      event: 'workflow_dispatch',
      runNumber: 78,
      runAttempt: 1,
      createdAt: DateTime.utc(2026, 9, 23, 22),
      startedAt: DateTime.utc(2026, 9, 23, 22),
      updatedAt: DateTime.utc(2026, 9, 23, 22, 2),
      htmlUrl: 'https://github.com/owner/app-teste/actions/runs/9876',
    );
    final snapshot = GlobalBuildsSnapshot(
      entries: [GlobalBuildEntry(repository: repository, run: run)],
      repositoryCount: 1,
      repositoriesWithBuilds: 1,
      unavailableRepositories: 0,
      loadedAt: DateTime.utc(2026, 9, 23, 22, 3),
    );

    final router = GoRouter(
      initialLocation: '/builds',
      routes: [
        GoRoute(
          path: '/builds',
          builder: (_, __) => const GlobalBuildsScreen(),
        ),
        GoRoute(
          path: '/repositories/:owner/:repo/builds',
          builder: (_, state) => Scaffold(
            body: Text(
              'run=${state.uri.queryParameters['runId']} '
              'branch=${state.uri.queryParameters['filterBranch']}',
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          globalBuildsProvider.overrideWith((ref) async => snapshot),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('app-teste'));
    await tester.pumpAndSettle();

    expect(find.text('run=9876 branch=release/2.0'), findsOneWidget);
  });
}
