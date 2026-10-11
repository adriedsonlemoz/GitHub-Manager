import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:github_manager/features/builds/domain/global_build_entry.dart';
import 'package:github_manager/features/builds/presentation/build_providers.dart';
import 'package:github_manager/features/builds/presentation/global_builds_screen.dart';
import 'package:github_manager/features/repositories/domain/github_repository.dart';
import 'package:github_manager/features/repositories/domain/repository_git_models.dart';
import 'package:go_router/go_router.dart';

const repo = GitHubRepository(
  id: 1, name: 'projeto', fullName: 'owner/projeto',
  isPrivate: false, isArchived: false, defaultBranch: 'main',
  updatedAt: null, htmlUrl: 'https://example.invalid/owner/projeto',
);

RepositoryWorkflowRun makeRun(int id, String branch, String sha, String conclusion) =>
    RepositoryWorkflowRun(
      id: id, workflowId: 55,
      workflowPath: '.github/workflows/android.yml',
      name: 'Android', title: 'Android v2.0.$id',
      status: 'completed', conclusion: conclusion,
      branch: branch, headSha: sha, commitMessage: 'v2.0.$id',
      event: 'push', runNumber: id, runAttempt: 1,
      createdAt: DateTime(2026, 10, 10, id == 9 ? 10 : 12),
      startedAt: DateTime(2026, 10, 10, id == 9 ? 10 : 12),
      updatedAt: DateTime(2026, 10, 10, id == 9 ? 10 : 12, 5),
      htmlUrl: 'https://example.invalid/run/$id',
    );

void main() {
  testWidgets('histórico permite buscar por branch e abrir uma execução antiga',
      (tester) async {
    final latest = GlobalBuildEntry(repository: repo,
        run: makeRun(10, 'main', 'abcdef10', 'success'));
    final older = GlobalBuildEntry(repository: repo,
        run: makeRun(9, 'develop', 'abcdef09', 'failure'));
    final snapshot = GlobalBuildsSnapshot(
      entries: [latest], historyEntries: [latest, older],
      repositoryCount: 1, repositoriesWithBuilds: 1,
      unavailableRepositories: 0, loadedAt: DateTime(2026, 10, 10, 13),
    );
    final router = GoRouter(initialLocation: '/builds', routes: [
      GoRoute(path: '/builds', builder: (_, __) => const GlobalBuildsScreen()),
      GoRoute(path: '/repositories/:owner/:repo/builds',
        builder: (_, state) => Scaffold(
          body: Text('execucao=${state.uri.queryParameters['runId']}'),
        ),
      ),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [globalBuildsProvider.overrideWith((ref) async => snapshot)],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
    expect(find.text('1 build na versão mais recente'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('builds-history')));
    await tester.pumpAndSettle();
    expect(find.text('2 execuções no histórico'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('builds-search')), 'develop');
    await tester.pumpAndSettle();
    expect(find.text('1 execução no histórico'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('repository-build-owner/projeto')));
    await tester.tap(find.byKey(const ValueKey('repository-build-owner/projeto')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('diagnose-9')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('run-9')));
    await tester.pumpAndSettle();
    expect(find.text('execucao=9'), findsOneWidget);
  });
}
