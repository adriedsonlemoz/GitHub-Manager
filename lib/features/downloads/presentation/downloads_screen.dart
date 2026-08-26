import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:github_manager/core/platform/platform_actions.dart';
import 'package:github_manager/features/downloads/domain/managed_download.dart';
import 'package:github_manager/features/downloads/presentation/download_providers.dart';

class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manager = ref.watch(downloadManagerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Downloads'),
        actions: [
          IconButton(
            tooltip: 'Limpar concluídos',
            onPressed: manager.items.any((item) => !item.isActive)
                ? manager.clearFinished
                : null,
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
      body: StreamBuilder<List<ManagedDownload>>(
        stream: manager.stream,
        initialData: manager.items,
        builder: (context, snapshot) {
          final items = snapshot.data ?? manager.items;
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Nenhum download ainda.'),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(item.isApk ? Icons.android_rounded : Icons.download_rounded),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                Text(
                                  item.fileName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          _StatusIcon(item: item),
                        ],
                      ),
                      if (item.isActive) ...[
                        const SizedBox(height: 12),
                        LinearProgressIndicator(value: item.progress),
                        const SizedBox(height: 6),
                        Text(_progressText(item)),
                      ],
                      if (item.errorMessage != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          item.errorMessage!,
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (item.isActive)
                            OutlinedButton.icon(
                              onPressed: () => manager.cancel(item.id),
                              icon: const Icon(Icons.close_rounded),
                              label: const Text('Cancelar'),
                            ),
                          if (item.status == ManagedDownloadStatus.completed && item.localPath != null)
                            if (item.isApk)
                              FilledButton.tonalIcon(
                                onPressed: () => _install(context, item.localPath!),
                                icon: const Icon(Icons.install_mobile_rounded),
                                label: const Text('Instalar APK'),
                              )
                            else
                              OutlinedButton.icon(
                                onPressed: () => _openFile(context, item.localPath!),
                                icon: const Icon(Icons.open_in_new_rounded),
                                label: const Text('Abrir'),
                              ),
                          if (!item.isActive)
                            TextButton.icon(
                              onPressed: () => manager.delete(item.id),
                              icon: const Icon(Icons.delete_outline_rounded),
                              label: const Text('Excluir'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  static Future<void> _install(BuildContext context, String path) async {
    if (!path.startsWith('content://') && !await File(path).exists()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('O APK não existe mais no aparelho.')),
        );
      }
      return;
    }
    if (!context.mounted) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Instalar APK?'),
        content: const Text(
          'O GitHub Manager apenas abrirá o instalador oficial do Android. A instalação só acontece se você confirmar novamente na tela do sistema.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.install_mobile_rounded),
            label: const Text('Continuar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    try {
      final result = await PlatformActions.installApk(path);
      if (!context.mounted) {
        return;
      }
      if (result == 'permission_required') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Autorize o GitHub Manager a instalar apps e depois toque em “Instalar APK” novamente.',
            ),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o instalador do Android.')),
        );
      }
    }
  }

  static Future<void> _openFile(BuildContext context, String path) async {
    try {
      await PlatformActions.openFile(path);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nenhum aplicativo disponível para abrir este arquivo.')),
        );
      }
    }
  }

  static String _progressText(ManagedDownload item) {
    if (item.totalBytes > 0) {
      return '${_formatBytes(item.receivedBytes)} de ${_formatBytes(item.totalBytes)}';
    }
    return '${_formatBytes(item.receivedBytes)} baixados';
  }

  static String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '$bytes B';
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.item});

  final ManagedDownload item;

  @override
  Widget build(BuildContext context) {
    return switch (item.status) {
      ManagedDownloadStatus.queued => const Icon(Icons.schedule_rounded),
      ManagedDownloadStatus.downloading => const Icon(Icons.downloading_rounded),
      ManagedDownloadStatus.completed => const Icon(Icons.check_circle_outline_rounded),
      ManagedDownloadStatus.failed => Icon(Icons.error_outline_rounded, color: Theme.of(context).colorScheme.error),
      ManagedDownloadStatus.cancelled => const Icon(Icons.cancel_outlined),
    };
  }
}
