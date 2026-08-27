import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:github_manager/core/providers/core_providers.dart';
import 'package:github_manager/features/permissions/data/permission_preflight_service.dart';
import 'package:github_manager/features/permissions/data/token_permission_diagnostics_service.dart';
import 'package:github_manager/features/permissions/domain/repository_permission_report.dart';

final tokenPermissionDiagnosticsServiceProvider =
    Provider<TokenPermissionDiagnosticsService>(
  (ref) => TokenPermissionDiagnosticsService(
    ref.watch(githubApiClientProvider),
    ref.watch(secureStorageProvider),
  ),
);

final permissionPreflightServiceProvider = Provider<PermissionPreflightService>(
  (ref) => PermissionPreflightService(
    ref.watch(tokenPermissionDiagnosticsServiceProvider),
    ref.watch(secureStorageProvider),
  ),
);

final repositoryPermissionReportProvider = FutureProvider.autoDispose.family<
    RepositoryPermissionReport, String>(
  (ref, repositoryFullName) => ref
      .watch(permissionPreflightServiceProvider)
      .getReport(repositoryFullName, forceRefresh: true),
);
