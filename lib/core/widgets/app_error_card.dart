import 'package:flutter/material.dart';
import 'package:github_manager/core/errors/app_exception.dart';

class AppErrorCard extends StatelessWidget {
  const AppErrorCard({
    required this.error,
    this.onRetry,
    this.onRepair,
    super.key,
  });

  final Object error;
  final VoidCallback? onRetry;
  final VoidCallback? onRepair;

  @override
  Widget build(BuildContext context) {
    final message = error is AppException
        ? (error as AppException).message
        : 'Não foi possível carregar estes dados.';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message),
                  if (onRepair != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Parece ser uma falha nos dados locais do aplicativo. O reparo não apaga seu token GitHub.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                  if (onRetry != null || onRepair != null) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (onRetry != null)
                          TextButton(
                            onPressed: onRetry,
                            child: const Text('Tentar novamente'),
                          ),
                        if (onRepair != null)
                          TextButton.icon(
                            onPressed: onRepair,
                            icon: const Icon(Icons.build_circle_outlined, size: 18),
                            label: const Text('Reparar dados locais'),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
