import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:github_manager/features/uploads/domain/managed_upload.dart';
import 'package:github_manager/features/uploads/presentation/upload_providers.dart';
import 'package:go_router/go_router.dart';

class UploadsScreen extends ConsumerWidget {
  const UploadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manager = ref.watch(uploadManagerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Central de Envios'),
        actions: [
          StreamBuilder<List<ManagedUpload>>(
            stream: manager.stream,
            initialData: manager.items,
            builder: (context, snapshot) {
              final items = snapshot.data ?? manager.items;
              final hasHistory = items.any((item) => !item.isActive);
              return IconButton(
                tooltip: 'Limpar histórico concluído',
                onPressed: hasHistory
                    ? () => _confirmClear(context, manager.clearFinishedHistory)
                    : null,
                icon: const Icon(Icons.delete_sweep_outlined),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<ManagedUpload>>(
        stream: manager.stream,
        initialData: manager.items,
        builder: (context, snapshot) {
          final items = snapshot.data ?? manager.items;
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Nenhum envio ainda.\n\nAo enviar um build, você poderá minimizar o progresso e continuar usando o aplicativo.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final active = items.where((item) => item.isActive).toList();
          final finished = items
              .where(
                (item) =>
                    item.status == ManagedUploadStatus.completed ||
                    item.status == ManagedUploadStatus.noChanges,
              )
              .toList();
          final failed = items
              .where(
                (item) =>
                    item.status == ManagedUploadStatus.failed ||
                    item.status == ManagedUploadStatus.interrupted,
              )
              .toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 28),
            children: [
              if (active.isNotEmpty) ...[
                _SectionTitle(
                  icon: Icons.cloud_upload_outlined,
                  title: 'Em andamento',
                  count: active.length,
                ),
                ...active.map((item) => _UploadCard(item: item)),
                const SizedBox(height: 10),
              ],
              if (finished.isNotEmpty) ...[
                _SectionTitle(
                  icon: Icons.check_circle_outline_rounded,
                  title: 'Concluídos',
                  count: finished.length,
                ),
                ...finished.map(
                  (item) => _UploadCard(
                    item: item,
                    onOpenBuilds: () => _openBuilds(context, item),
                    onRunAnyway: item.canRunBuildAnyway
                        ? () => manager.runBuildAnyway(item.id)
                        : null,
                    onRemove: () => manager.removeFromHistory(item.id),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              if (failed.isNotEmpty) ...[
                _SectionTitle(
                  icon: Icons.error_outline_rounded,
                  title: 'Interrompidos ou com falha',
                  count: failed.length,
                ),
                ...failed.map(
                  (item) => _UploadCard(
                    item: item,
                    onRetry: item.canRetry ? () => manager.retry(item.id) : null,
                    onOpenBuilds: item.commitSha?.isNotEmpty == true
                        ? () => _openBuilds(context, item)
                        : null,
                    onRemove: () => manager.removeFromHistory(item.id),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  static void _openBuilds(BuildContext context, ManagedUpload item) {
    final repository = item.repositoryFullName;
    if (!repository.contains('/')) return;
    context.push(
      '/repositories/$repository/builds?branch=${Uri.encodeQueryComponent(item.branch)}',
    );
  }

  static Future<void> _confirmClear(
    BuildContext context,
    Future<void> Function() clear,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Limpar histórico de envios?'),
        content: const Text(
          'Envios concluídos, interrompidos e com falha serão removidos da Central. Nenhum arquivo ou commit será apagado do GitHub.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Limpar'),
          ),
        ],
      ),
    );
    if (confirmed == true) await clear();
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
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
        child: Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            Text('$count'),
          ],
        ),
      );
}

class _UploadCard extends StatelessWidget {
  const _UploadCard({
    required this.item,
    this.onRetry,
    this.onRunAnyway,
    this.onOpenBuilds,
    this.onRemove,
  });

  final ManagedUpload item;
  final VoidCallback? onRetry;
  final VoidCallback? onRunAnyway;
  final VoidCallback? onOpenBuilds;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final progress = item.progress;
    final scheme = Theme.of(context).colorScheme;
    final statusColor = switch (item.status) {
      ManagedUploadStatus.completed => scheme.primary,
      ManagedUploadStatus.noChanges => scheme.tertiary,
      ManagedUploadStatus.failed || ManagedUploadStatus.interrupted => scheme.error,
      _ => scheme.primary,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  item.isActive
                      ? Icons.cloud_upload_outlined
                      : item.status == ManagedUploadStatus.completed
                          ? Icons.check_circle_outline_rounded
                          : item.status == ManagedUploadStatus.noChanges
                              ? Icons.info_outline_rounded
                              : Icons.error_outline_rounded,
                  color: statusColor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.projectName,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.repositoryFullName,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  item.statusLabel,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(item.phase, style: const TextStyle(fontWeight: FontWeight.w700)),
            if (item.currentFile?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 3),
              Text(
                item.currentFile!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (item.isActive) ...[
              const SizedBox(height: 9),
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 5),
              Text(
                item.status == ManagedUploadStatus.startingBuild
                    ? 'Arquivos sincronizados • aguardando GitHub Actions'
                    : '${item.current.clamp(0, item.total)} de ${item.total} arquivos${progress == null ? '' : ' • ${(progress * 100).round()}%'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (item.errorMessage?.isNotEmpty == true) ...[
              const SizedBox(height: 9),
              Text(
                item.errorMessage!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.error,
                    ),
              ),
            ],
            if (item.commitSha?.isNotEmpty == true) ...[
              const SizedBox(height: 6),
              Text(
                'Commit ${_shortSha(item.commitSha!)}${item.workflowName?.isNotEmpty == true ? ' • ${item.workflowName}' : ''}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (onRetry != null)
                  FilledButton.tonalIcon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Tentar novamente'),
                  ),
                if (onRunAnyway != null)
                  FilledButton.tonalIcon(
                    onPressed: onRunAnyway,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Executar build'),
                  ),
                if (onOpenBuilds != null)
                  OutlinedButton.icon(
                    onPressed: onOpenBuilds,
                    icon: const Icon(Icons.play_circle_outline_rounded),
                    label: const Text('Builds'),
                  ),
                OutlinedButton.icon(
                  onPressed: () => _showDetails(context, item),
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('Detalhes'),
                ),
                if (onRemove != null)
                  IconButton(
                    onPressed: onRemove,
                    tooltip: 'Remover do histórico',
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _shortSha(String sha) => sha.length > 7 ? sha.substring(0, 7) : sha;

  static Future<void> _showDetails(BuildContext context, ManagedUpload item) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Detalhes do envio'),
        content: SingleChildScrollView(
          child: SelectableText(item.technicalLog),
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: item.technicalLog));
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
}
