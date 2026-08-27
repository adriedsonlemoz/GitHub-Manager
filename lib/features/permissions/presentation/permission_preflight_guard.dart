import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:github_manager/core/widgets/adaptive_dialog.dart';
import 'package:github_manager/features/permissions/domain/repository_permission_preflight.dart';
import 'package:github_manager/features/permissions/presentation/token_permission_providers.dart';
import 'package:go_router/go_router.dart';

Future<bool> ensureRepositoryPermission(
  BuildContext context,
  WidgetRef ref, {
  required String repositoryFullName,
  required RepositoryCriticalAction action,
}) async {
  final decision = await ref
      .read(permissionPreflightServiceProvider)
      .check(repositoryFullName, action);
  if (!context.mounted || !decision.blocked) return !decision.blocked;

  final openDiagnostics = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.shield_outlined),
          SizedBox(width: 10),
          Expanded(child: Text('Ação bloqueada pelo token')),
        ],
      ),
      content: AdaptiveDialogBody(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${decision.actionLabel} não foi iniciado porque o diagnóstico '
                'já encontrou um bloqueio confirmado para este repositório.',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (decision.message?.isNotEmpty == true) ...[
                const SizedBox(height: 10),
                Text(decision.message!),
              ],
              if (decision.requiredPermissions.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Permissão necessária',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                ...decision.requiredPermissions.map(
                  (permission) => Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .errorContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        permission,
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onErrorContainer,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              if (decision.denied.isNotEmpty) ...[
                const SizedBox(height: 10),
                ...decision.denied.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('• ${item.detail}'),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              const Text(
                'Nenhuma alteração foi feita. Abra o diagnóstico para revisar '
                'o token e as permissões detectadas.',
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Fechar'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(dialogContext, true),
          icon: const Icon(Icons.verified_user_outlined),
          label: const Text('Abrir diagnóstico'),
        ),
      ],
    ),
  );

  if (openDiagnostics == true && context.mounted) {
    context.push('/repositories/$repositoryFullName/permissions');
  }
  return false;
}
