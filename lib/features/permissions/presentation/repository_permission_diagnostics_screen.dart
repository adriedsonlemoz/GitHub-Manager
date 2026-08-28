import 'package:flutter/material.dart';
import 'package:github_manager/core/widgets/app_main_navigation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:github_manager/core/errors/app_exception.dart';
import 'package:github_manager/core/widgets/centered_notice.dart';
import 'package:github_manager/features/permissions/domain/repository_permission_report.dart';
import 'package:github_manager/features/permissions/presentation/token_permission_providers.dart';

part 'repository_permission_diagnostics_widgets.dart';

class RepositoryPermissionDiagnosticsScreen extends ConsumerWidget {
  const RepositoryPermissionDiagnosticsScreen({
    required this.repositoryFullName,
    super.key,
  });

  final String repositoryFullName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(
      repositoryPermissionReportProvider(repositoryFullName),
    );

    return Scaffold(
      bottomNavigationBar: const AppMainNavigation(selectedIndex: 0),
      appBar: AppBar(
        title: const Text('Diagnóstico do token'),
        actions: [
          IconButton(
            tooltip: 'Testar novamente',
            onPressed: () => ref.invalidate(
              repositoryPermissionReportProvider(repositoryFullName),
            ),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(repositoryPermissionReportProvider(repositoryFullName));
          await ref.read(
            repositoryPermissionReportProvider(repositoryFullName).future,
          );
        },
        child: report.when(
          loading: () => const _LoadingView(),
          error: (error, _) => _ErrorView(
            error: error,
            onRetry: () => ref.invalidate(
              repositoryPermissionReportProvider(repositoryFullName),
            ),
          ),
          data: (data) => _ReportView(report: data),
        ),
      ),
    );
  }
}
