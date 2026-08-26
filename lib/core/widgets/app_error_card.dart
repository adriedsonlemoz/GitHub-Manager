import 'package:flutter/material.dart';
import 'package:github_manager/core/errors/app_exception.dart';

class AppErrorCard extends StatelessWidget {
  const AppErrorCard({required this.error, this.onRetry, super.key});

  final Object error;
  final VoidCallback? onRetry;

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
            Icon(Icons.error_outline_rounded, color: Theme.of(context).colorScheme.error),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
            if (onRetry != null) TextButton(onPressed: onRetry, child: const Text('Tentar novamente')),
          ],
        ),
      ),
    );
  }
}
