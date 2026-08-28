import 'dart:io';
import 'package:github_manager/core/widgets/centered_notice.dart';

import 'package:flutter/material.dart';
import 'package:github_manager/core/widgets/app_main_navigation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:github_manager/core/platform/platform_actions.dart';
import 'package:github_manager/features/downloads/domain/managed_download.dart';
import 'package:github_manager/features/downloads/presentation/download_providers.dart';

part 'downloads_widgets.dart';

class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manager = ref.watch(downloadManagerProvider);
    return Scaffold(
      bottomNavigationBar: const AppMainNavigation(selectedIndex: 1),
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
                    item.status == ManagedDownloadStatus.interrupted ||
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
    showCenteredNotice(context, message);
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
