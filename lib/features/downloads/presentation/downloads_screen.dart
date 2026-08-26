import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
        title: const Text('Central de Downloads'),
        actions: [
          StreamBuilder<List<ManagedDownload>>(
            stream: manager.stream,
            initialData: manager.items,
            builder: (context, snapshot) {
              final hasHistory =
                  (snapshot.data ?? manager.items).any((item) => !item.isActive);
              return IconButton(
                tooltip: 'Limpar histórico',
                onPressed: hasHistory
                    ? () => _confirmClearHistory(context, manager.clearFinishedHistory)
                    : null,
                icon: const Icon(Icons.delete_sweep_outlined),
              );
            },
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

          final active = items.where((item) => item.isActive).toList();
          final completed = items
              .where((item) => item.status == ManagedDownloadStatus.completed)
              .toList();
          final failed = items
              .where(
                (item) =>
                    item.status == ManagedDownloadStatus.failed ||
                    item.status == ManagedDownloadStatus.cancelled,
              )
              .toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 28),
            children: [
              if (active.isNotEmpty) ...[
                _SectionTitle(
                  icon: Icons.downloading_rounded,
                  title: 'Baixando',
                  count: active.length,
                ),
                ...active.map(
                  (item) => _ActiveDownloadCard(
                    item: item,
                    onCancel: () => manager.cancel(item.id),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              if (completed.isNotEmpty) ...[
                _SectionTitle(
                  icon: Icons.check_circle_outline_rounded,
                  title: 'Concluídos',
                  count: completed.length,
                ),
                ...completed.map(
                  (item) => _CompletedDownloadCard(
                    item: item,
                    onOpen: () => _open(context, item),
                    onInstall: () => _install(context, item),
                    onShare: () => _share(context, item),
                    onDeleteFile: () => _confirmDeleteFile(
                      context,
                      () => manager.deleteFileAndHistory(item.id),
                    ),
                    onRemoveHistory: () => manager.removeFromHistory(item.id),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              if (failed.isNotEmpty) ...[
                _SectionTitle(
                  icon: Icons.error_outline_rounded,
                  title: 'Falharam',
                  count: failed.length,
                ),
                ...failed.map(
                  (item) => _FailedDownloadCard(
                    item: item,
                    onRetry: item.canRetry ? () => manager.retry(item.id) : null,
                    onDetails: () => _showDetails(context, item),
                    onRemoveHistory: () => manager.removeFromHistory(item.id),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  static Future<void> _confirmClearHistory(
    BuildContext context,
    Future<void> Function() clear,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Limpar histórico?'),
        content: const Text(
          'Os registros concluídos, cancelados e com falha serão removidos da Central. Os arquivos já salvos em Downloads não serão apagados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Limpar histórico'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await clear();
    }
  }

  static Future<void> _confirmDeleteFile(
    BuildContext context,
    Future<void> Function() delete,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir arquivo?'),
        content: const Text(
          'O arquivo será removido da pasta Downloads e também do histórico do GitHub Manager.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await delete();
    }
  }

  static Future<bool> _fileAvailable(ManagedDownload item) async {
    final location = item.localPath;
    if (location == null || location.isEmpty) {
      return false;
    }
    if (location.startsWith('content://')) {
      return true;
    }
    return File(location).exists();
  }

  static Future<void> _open(BuildContext context, ManagedDownload item) async {
    if (!await _fileAvailable(item)) {
      if (context.mounted) {
        _snack(context, 'O arquivo não existe mais no aparelho.');
      }
      return;
    }
    try {
      await PlatformActions.openFile(item.localPath!, mimeType: _mimeType(item));
    } catch (_) {
      if (context.mounted) {
        _snack(context, 'Nenhum aplicativo disponível para abrir este arquivo.');
      }
    }
  }

  static Future<void> _share(BuildContext context, ManagedDownload item) async {
    if (!await _fileAvailable(item)) {
      if (context.mounted) {
        _snack(context, 'O arquivo não existe mais no aparelho.');
      }
      return;
    }
    try {
      await PlatformActions.shareFile(item.localPath!, mimeType: _mimeType(item));
    } catch (_) {
      if (context.mounted) {
        _snack(context, 'Não foi possível compartilhar este arquivo.');
      }
    }
  }

  static Future<void> _install(BuildContext context, ManagedDownload item) async {
    if (!await _fileAvailable(item)) {
      if (context.mounted) {
        _snack(context, 'O APK não existe mais no aparelho.');
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
          'O GitHub Manager abrirá o instalador oficial do Android. O aplicativo nunca instala um APK automaticamente.',
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
      final result = await PlatformActions.installApk(item.localPath!);
      if (!context.mounted) {
        return;
      }
      if (result == 'permission_required') {
        _snack(
          context,
          'Autorize o GitHub Manager a instalar apps desconhecidos e depois toque em “Instalar” novamente.',
        );
      }
    } catch (_) {
      if (context.mounted) {
        _snack(context, 'Não foi possível abrir o instalador oficial do Android.');
      }
    }
  }

  static Future<void> _showDetails(
    BuildContext context,
    ManagedDownload item,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Detalhes do download'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: SelectableText(
              item.technicalLog,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: item.technicalLog));
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
                _snack(context, 'Log copiado.');
              }
            },
            icon: const Icon(Icons.copy_rounded),
            label: const Text('Copiar log'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  static void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  static String _mimeType(ManagedDownload item) {
    if (item.isApk) {
      return 'application/vnd.android.package-archive';
    }
    if (item.fileName.toLowerCase().endsWith('.zip')) {
      return 'application/zip';
    }
    return 'application/octet-stream';
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.count,
  });

  final IconData icon;
  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(width: 6),
          Text('($count)', style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _ActiveDownloadCard extends StatelessWidget {
  const _ActiveDownloadCard({required this.item, required this.onCancel});

  final ManagedDownload item;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final percent = item.progress == null ? null : (item.progress! * 100).floor();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DownloadHeader(item: item),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    percent == null ? 'Baixando…' : '$percent%',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                Text(item.statusLabel),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: item.progress),
            const SizedBox(height: 10),
            Text(_bytesLine(item)),
            if (item.bytesPerSecond > 0) ...[
              const SizedBox(height: 3),
              Text('${_formatBytes(item.bytesPerSecond.round())}/s'),
            ],
            if (item.estimatedSecondsRemaining != null) ...[
              const SizedBox(height: 3),
              Text(_etaText(item.estimatedSecondsRemaining!)),
            ],
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onCancel,
              icon: const Icon(Icons.close_rounded),
              label: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompletedDownloadCard extends StatelessWidget {
  const _CompletedDownloadCard({
    required this.item,
    required this.onOpen,
    required this.onInstall,
    required this.onShare,
    required this.onDeleteFile,
    required this.onRemoveHistory,
  });

  final ManagedDownload item;
  final VoidCallback onOpen;
  final VoidCallback onInstall;
  final VoidCallback onShare;
  final VoidCallback onDeleteFile;
  final VoidCallback onRemoveHistory;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DownloadHeader(item: item),
            const SizedBox(height: 9),
            Text(
              '${_formatBytes(item.totalBytes > 0 ? item.totalBytes : item.receivedBytes)} • ${_formatDate(item.completedAt ?? item.createdAt)}',
            ),
            const SizedBox(height: 3),
            Text(
              'Salvo em Downloads/${item.fileName}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (item.isApk)
                  FilledButton.tonalIcon(
                    onPressed: onInstall,
                    icon: const Icon(Icons.install_mobile_rounded),
                    label: const Text('Instalar'),
                  )
                else
                  FilledButton.tonalIcon(
                    onPressed: onOpen,
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('Abrir'),
                  ),
                OutlinedButton.icon(
                  onPressed: onShare,
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Compartilhar'),
                ),
                TextButton.icon(
                  onPressed: onDeleteFile,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Excluir arquivo'),
                ),
                TextButton(
                  onPressed: onRemoveHistory,
                  child: const Text('Remover do histórico'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FailedDownloadCard extends StatelessWidget {
  const _FailedDownloadCard({
    required this.item,
    required this.onRetry,
    required this.onDetails,
    required this.onRemoveHistory,
  });

  final ManagedDownload item;
  final VoidCallback? onRetry;
  final VoidCallback onDetails;
  final VoidCallback onRemoveHistory;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DownloadHeader(item: item),
            const SizedBox(height: 10),
            Text(
              item.errorMessage ?? 'Não foi possível concluir o download.',
              style: TextStyle(color: colors.error, fontWeight: FontWeight.w600),
            ),
            if (item.httpStatus != null || item.errorCode != null) ...[
              const SizedBox(height: 5),
              Text(
                [
                  if (item.httpStatus != null) 'HTTP ${item.httpStatus}',
                  if (item.errorCode != null) item.errorCode!,
                ].join(' • '),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (onRetry != null)
                  FilledButton.tonalIcon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Tentar novamente'),
                  ),
                OutlinedButton.icon(
                  onPressed: onDetails,
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('Ver detalhes'),
                ),
                TextButton(
                  onPressed: onRemoveHistory,
                  child: const Text('Remover do histórico'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DownloadHeader extends StatelessWidget {
  const _DownloadHeader({required this.item});

  final ManagedDownload item;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(item.isApk ? Icons.android_rounded : _typeIcon(item.type)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.fileName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                item.typeLabel,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        _StatusIcon(item: item),
      ],
    );
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
      ManagedDownloadStatus.completed =>
        const Icon(Icons.check_circle_outline_rounded),
      ManagedDownloadStatus.failed => Icon(
          Icons.error_outline_rounded,
          color: Theme.of(context).colorScheme.error,
        ),
      ManagedDownloadStatus.cancelled => const Icon(Icons.cancel_outlined),
    };
  }
}

IconData _typeIcon(ManagedDownloadType type) => switch (type) {
      ManagedDownloadType.apk => Icons.android_rounded,
      ManagedDownloadType.projectZip => Icons.folder_zip_outlined,
      ManagedDownloadType.logs => Icons.receipt_long_outlined,
      ManagedDownloadType.artifact => Icons.inventory_2_outlined,
      ManagedDownloadType.file => Icons.insert_drive_file_outlined,
    };

String _bytesLine(ManagedDownload item) {
  if (item.totalBytes > 0) {
    return '${_formatBytes(item.receivedBytes)} / ${_formatBytes(item.totalBytes)}';
  }
  return '${_formatBytes(item.receivedBytes)} baixados';
}

String _formatBytes(int bytes) {
  if (bytes >= 1024 * 1024 * 1024) {
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }
  if (bytes >= 1024 * 1024) {
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '$bytes B';
}

String _etaText(int seconds) {
  if (seconds < 60) {
    return 'Restam aproximadamente $seconds segundos';
  }
  final minutes = (seconds / 60).ceil();
  return 'Restam aproximadamente $minutes min';
}

String _formatDate(DateTime date) {
  final local = date.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
}
