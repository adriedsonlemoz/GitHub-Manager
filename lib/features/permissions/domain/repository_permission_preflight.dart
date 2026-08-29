import 'package:github_manager/features/permissions/domain/repository_permission_report.dart';

enum RepositoryCriticalAction {
  sendBuild,
  manageFiles,
  manageSecrets,
  deleteRepository,
}

class RepositoryPermissionPreflightDecision {
  const RepositoryPermissionPreflightDecision({
    required this.action,
    required this.repositoryFullName,
    required this.blocked,
    required this.denied,
    required this.unknown,
    this.message,
    this.diagnosticUnavailable = false,
    this.checkedAt,
  });

  final RepositoryCriticalAction action;
  final String repositoryFullName;
  final bool blocked;
  final List<PermissionAccessResult> denied;
  final List<PermissionAccessResult> unknown;
  final String? message;
  final bool diagnosticUnavailable;
  final DateTime? checkedAt;

  bool get mayProceed => !blocked;

  String get actionLabel => switch (action) {
        RepositoryCriticalAction.sendBuild => 'Enviar build',
        RepositoryCriticalAction.manageFiles => 'Gerenciar arquivos',
        RepositoryCriticalAction.manageSecrets => 'Gerenciar Secrets',
        RepositoryCriticalAction.deleteRepository => 'Excluir repositório',
      };

  List<String> get requiredPermissions {
    final values = <String>{};
    for (final item in denied) {
      final permission = item.requiredPermission?.trim();
      if (permission != null && permission.isNotEmpty) {
        values.add(permission);
      }
    }
    return values.toList(growable: false);
  }
}
