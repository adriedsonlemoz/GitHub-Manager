import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:github_manager/core/widgets/adaptive_dialog.dart';
import 'package:github_manager/features/uploads/data/upload_manager_service.dart';
import 'package:github_manager/features/uploads/domain/managed_upload.dart';
import 'package:github_manager/features/uploads/presentation/upload_providers.dart';
import 'package:go_router/go_router.dart';

class UploadProgressDialog extends ConsumerWidget {
  const UploadProgressDialog({required this.uploadId, super.key});

  final String uploadId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manager = ref.watch(uploadManagerProvider);
    return StreamBuilder<List<ManagedUpload>>(
      stream: manager.stream,
      initialData: manager.items,
      builder: (context, _) {
        final item = manager.find(uploadId);
        if (item == null) {
          return AlertDialog(
            title: const Text('Envio'),
            content: const Text('Este envio não está mais disponível.'),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fechar'),
              ),
            ],
          );
        }

        final progress = item.progress;
        final percent = progress == null ? null : (progress * 100).round();
        return AlertDialog(
          title: Text(_title(item)),
          content: AdaptiveDialogBody(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.phase,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                if (item.total > 0 && item.status != ManagedUploadStatus.startingBuild)
                  Text(
                    '${item.current.clamp(0, item.total)} de ${item.total} arquivos${percent == null ? '' : ' • $percent%'}',
                  ),
                if (item.status == ManagedUploadStatus.startingBuild)
                  const Text('Arquivos sincronizados. Conferindo o GitHub Actions.'),
                if (item.currentFile?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.currentFile!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                if (item.isActive) ...[
                  const SizedBox(height: 10),
                  LinearProgressIndicator(value: progress),
                ],
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Processo',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 5),
                      ...item.logLines.reversed.take(6).toList().reversed.map(
                            (line) => Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text(
                                '• $line',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                if (item.isActive)
                  const Text(
                    'Você pode minimizar este painel e continuar navegando pelo GitHub Manager. O envio continuará enquanto o aplicativo permanecer em execução.',
                  ),
                if (item.errorMessage?.isNotEmpty == true)
                  Text(
                    item.errorMessage!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                if (item.status == ManagedUploadStatus.noChanges)
                  const Text(
                    'O ZIP é idêntico ao repositório. Você pode iniciar a build do commit atual mesmo assim.',
                  ),
              ],
            ),
          ),
          actions: _actions(context, manager, item),
        );
      },
    );
  }

  List<Widget> _actions(
    BuildContext context,
    UploadManagerService manager,
    ManagedUpload item,
  ) {
    final router = GoRouter.of(context);
    if (item.isActive) {
      return [
        TextButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.minimize_rounded),
          label: const Text('Minimizar'),
        ),
        FilledButton.tonalIcon(
          onPressed: () {
            Navigator.pop(context);
            router.push('/uploads');
          },
          icon: const Icon(Icons.cloud_upload_outlined),
          label: const Text('Centro de envios'),
        ),
      ];
    }

    if (item.status == ManagedUploadStatus.noChanges) {
      return [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fechar'),
        ),
        FilledButton.icon(
          onPressed: () => manager.runBuildAnyway(item.id),
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Executar build'),
        ),
      ];
    }

    if (item.status == ManagedUploadStatus.failed ||
        item.status == ManagedUploadStatus.interrupted) {
      return [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fechar'),
        ),
        if (item.canRetry)
          FilledButton.icon(
            onPressed: () => manager.retry(item.id),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Tentar novamente'),
          ),
      ];
    }

    return [
      TextButton.icon(
        onPressed: () {
          Navigator.pop(context);
          router.push('/uploads');
        },
        icon: const Icon(Icons.cloud_upload_outlined),
        label: const Text('Centro de envios'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Fechar'),
      ),
    ];
  }

  static String _title(ManagedUpload item) => switch (item.status) {
        ManagedUploadStatus.completed => 'Envio concluído',
        ManagedUploadStatus.noChanges => 'Projeto já está atualizado',
        ManagedUploadStatus.failed => 'Envio com falha',
        ManagedUploadStatus.interrupted => 'Envio interrompido',
        _ => 'Enviando build',
      };
}
