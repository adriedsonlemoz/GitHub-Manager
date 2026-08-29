import 'package:flutter/material.dart';
import 'package:github_manager/core/widgets/app_main_navigation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:github_manager/features/uploads/domain/managed_upload.dart';
import 'package:github_manager/features/uploads/presentation/upload_details_dialog.dart';
import 'package:github_manager/features/uploads/presentation/upload_providers.dart';
import 'package:go_router/go_router.dart';

part 'uploads_widgets.dart';

class UploadsScreen extends ConsumerWidget {
  const UploadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manager = ref.watch(uploadManagerProvider);
    return Scaffold(
      bottomNavigationBar: const AppMainNavigation(selectedIndex: 0),
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
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 88),
            children: [
              if (active.isNotEmpty) ...[
                _SectionTitle(
                  icon: Icons.cloud_upload_outlined,
                  title: 'Em andamento',
                  count: active.length,
                ),
                ...active.map((item) => _UploadCard(item: item)),
                const SizedBox(height: 6),
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
                const SizedBox(height: 6),
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
