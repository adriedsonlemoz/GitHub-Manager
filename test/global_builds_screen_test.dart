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
  testWidgets('tocar build global navega com branch e runId específicos', (tester) async {
    final snapshot = GlobalBuildsSnapshot(
      entries: [GlobalBuildEntry(repository: _repo, run: _run)],
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
            body: Text('run=${state.uri.queryParameters['runId']} branch=${state.uri.queryParameters['branch']}'),
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
    await tester.tap(find.text('repo'));
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

final _run = RepositoryWorkflowRun(
  id: 987,
  workflowId: 3,
  workflowPath: '.github/workflows/android.yml',
  name: 'Android APK',
  title: 'Build 2.0.78',
  status: 'in_progress',
  conclusion: null,
  branch: 'release',
  headSha: '1234567890',
  commitMessage: 'Build 2.0.78',
  event: 'workflow_dispatch',
  runNumber: 78,
  runAttempt: 1,
  createdAt: DateTime(2026, 9, 24),
  startedAt: DateTime(2026, 9, 24),
  updatedAt: DateTime(2026, 9, 24),
  htmlUrl: 'https://example.invalid/run/987',
);
