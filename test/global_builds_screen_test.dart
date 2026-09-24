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
  testWidgets('lista repositório uma vez e abre popup com builds do commit mais recente',
      (tester) async {
    final snapshot = GlobalBuildsSnapshot(
      entries: [
        GlobalBuildEntry(repository: _repo, run: _apkRun),
        GlobalBuildEntry(repository: _repo, run: _ciRun),
      ],
      repositoryCount: 1,
      repositoriesWithBuilds: 1,
      unavailableRepositories: 0,
      loadedAt: DateTime(2026, 9, 24),
    );
    final router = GoRouter(
      initialLocation: '/builds',
      routes: [
        GoRoute(path: '/builds', builder: (_, __) => const GlobalBuildsScreen()),
        GoRoute(
          path: '/repositories/:owner/:repo/builds',
          builder: (_, state) => Scaffold(
            body: Text(
              'run=${state.uri.queryParameters['runId']} branch=${state.uri.queryParameters['branch']}',
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [globalBuildsProvider.overrideWith((ref) async => snapshot)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('repo'), findsOneWidget);
    expect(find.text('2 builds na versão mais recente'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('repository-build-owner/repo')));
    await tester.pumpAndSettle();

    expect(find.text('Android APK • #78'), findsOneWidget);
    expect(find.text('Verificação do Projeto (CI) • #78'), findsOneWidget);
    expect(find.byKey(const ValueKey('logs-987')), findsOneWidget);
    expect(find.byKey(const ValueKey('apk-987')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('run-987')));
    await tester.pumpAndSettle();

    expect(find.text('run=987 branch=release'), findsOneWidget);
  });
}

const _repo = GitHubRepository(
  id: 1,
  name: 'repo',
  fullName: 'owner/repo',
  isPrivate: false,
  isArchived: false,
  defaultBranch: 'main',
  updatedAt: null,
  htmlUrl: 'https://example.invalid/owner/repo',
);

final _apkRun = RepositoryWorkflowRun(
  id: 987,
  workflowId: 3,
  workflowPath: '.github/workflows/android.yml',
  name: 'Android APK',
  title: 'Build 2.0.83',
  status: 'in_progress',
  conclusion: null,
  branch: 'release',
  headSha: '1234567890',
  commitMessage: 'Build 2.0.83',
  event: 'workflow_dispatch',
  runNumber: 78,
  runAttempt: 1,
  createdAt: DateTime(2026, 9, 24, 12),
  startedAt: DateTime(2026, 9, 24, 12),
  updatedAt: DateTime(2026, 9, 24, 12),
  htmlUrl: 'https://example.invalid/run/987',
);

final _ciRun = RepositoryWorkflowRun(
  id: 988,
  workflowId: 4,
  workflowPath: '.github/workflows/ci.yml',
  name: 'Verificação do Projeto (CI)',
  title: 'CI 2.0.83',
  status: 'in_progress',
  conclusion: null,
  branch: 'release',
  headSha: '1234567890',
  commitMessage: 'Build 2.0.83',
  event: 'push',
  runNumber: 78,
  runAttempt: 1,
  createdAt: DateTime(2026, 9, 24, 12),
  startedAt: DateTime(2026, 9, 24, 12),
  updatedAt: DateTime(2026, 9, 24, 12),
  htmlUrl: 'https://example.invalid/run/988',
);
