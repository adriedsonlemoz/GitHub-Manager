import 'package:flutter/material.dart';
import 'package:github_manager/features/downloads/presentation/downloads_screen.dart';
import 'package:github_manager/features/home/presentation/profile_screen.dart';
import 'package:github_manager/features/issues/presentation/repository_issues_screen.dart';
import 'package:github_manager/features/permissions/presentation/repository_permission_diagnostics_screen.dart';
import 'package:github_manager/features/repositories/presentation/repositories_screen.dart';
import 'package:github_manager/features/repositories/presentation/repository_actions_screen.dart';
import 'package:github_manager/features/repositories/presentation/repository_artifacts_screen.dart';
import 'package:github_manager/features/repositories/presentation/repository_commits_screen.dart';
import 'package:github_manager/features/repositories/presentation/repository_detail_screen.dart';
import 'package:github_manager/features/repositories/presentation/repository_files_screen.dart';
import 'package:github_manager/features/secrets/presentation/repository_secrets_screen.dart';
import 'package:github_manager/features/settings/presentation/settings_screen.dart';
import 'package:github_manager/features/setup/presentation/setup_wizard_screen.dart';
import 'package:github_manager/features/uploads/presentation/uploads_screen.dart';
import 'package:go_router/go_router.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (_, _) => const RepositoriesScreen(),
    ),
    GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
    GoRoute(
      path: '/settings',
      builder: (_, _) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/downloads',
      builder: (_, _) => const DownloadsScreen(),
    ),
    GoRoute(
      path: '/uploads',
      builder: (_, _) => const UploadsScreen(),
    ),
    GoRoute(
      path: '/setup',
      builder: (_, _) => const SetupWizardScreen(),
    ),
    GoRoute(
      path: '/repositories/:owner/:repo',
      builder: (_, state) {
        final fullName =
            '${state.pathParameters['owner']}/${state.pathParameters['repo']}';
        return RepositoryDetailScreen(
          repositoryFullName: fullName,
          readOnly: state.uri.queryParameters['readOnly'] == '1',
        );
      },
      routes: [
        GoRoute(
          path: 'files',
          builder: (_, state) {
            final fullName =
                '${state.pathParameters['owner']}/${state.pathParameters['repo']}';
            return RepositoryFilesScreen(
              repositoryFullName: fullName,
              defaultBranch: state.uri.queryParameters['branch'] ?? 'main',
              readOnly: state.uri.queryParameters['readOnly'] == '1',
            );
          },
        ),
        GoRoute(
          path: 'builds',
          builder: (_, state) {
            final fullName =
                '${state.pathParameters['owner']}/${state.pathParameters['repo']}';
            return RepositoryActionsScreen(
              repositoryFullName: fullName,
              defaultBranch: state.uri.queryParameters['branch'] ?? 'main',
              readOnly: state.uri.queryParameters['readOnly'] == '1',
            );
          },
        ),
        GoRoute(
          path: 'commits',
          builder: (_, state) {
            final fullName =
                '${state.pathParameters['owner']}/${state.pathParameters['repo']}';
            return RepositoryCommitsScreen(
              repositoryFullName: fullName,
              initialBranch: state.uri.queryParameters['branch'] ?? 'main',
            );
          },
        ),
        GoRoute(
          path: 'bugs',
          builder: (_, state) {
            final fullName =
                '${state.pathParameters['owner']}/${state.pathParameters['repo']}';
            return RepositoryIssuesScreen(repositoryFullName: fullName);
          },
        ),
        GoRoute(
          path: 'artifacts',
          builder: (_, state) {
            final fullName =
                '${state.pathParameters['owner']}/${state.pathParameters['repo']}';
            return RepositoryArtifactsScreen(
              repositoryFullName: fullName,
              readOnly: state.uri.queryParameters['readOnly'] == '1',
            );
          },
        ),
        GoRoute(
          path: 'permissions',
          builder: (_, state) {
            final fullName =
                '${state.pathParameters['owner']}/${state.pathParameters['repo']}';
            return RepositoryPermissionDiagnosticsScreen(
              repositoryFullName: fullName,
            );
          },
        ),
        GoRoute(
          path: 'secrets',
          builder: (_, state) {
            final fullName =
                '${state.pathParameters['owner']}/${state.pathParameters['repo']}';
            return RepositorySecretsScreen(repositoryFullName: fullName);
          },
        ),
      ],
    ),
  ],
);
