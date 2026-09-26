import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:github_manager/features/downloads/domain/managed_download.dart';
import 'package:github_manager/features/downloads/presentation/download_providers.dart';
import 'package:go_router/go_router.dart';

class DownloadCenterButton extends ConsumerWidget {
  const DownloadCenterButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manager = ref.watch(downloadManagerProvider);
    return StreamBuilder<List<ManagedDownload>>(
      stream: manager.stream,
      initialData: manager.items,
      builder: (context, snapshot) {
        final items = snapshot.data ?? manager.items;
        if (items.isEmpty) {
          return const SizedBox.shrink();
        }
        final active = items.where((item) => item.isActive).length;
        return IconButton(
          onPressed: () => context.push('/downloads'),
          tooltip: active > 0 ? '$active download(s) em andamento' : 'Downloads',
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.download_for_offline_outlined),
              if (active > 0)
                Positioned(
                  right: -7,
                  top: -7,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$active',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class DownloadFloatingStatusButton extends ConsumerWidget {
  const DownloadFloatingStatusButton({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manager = ref.watch(downloadManagerProvider);
    return StreamBuilder<List<ManagedDownload>>(
      stream: manager.stream,
      initialData: manager.items,
      builder: (context, _) {
        final active = manager.items.where((item) => item.isActive).toList();
        if (active.isEmpty) {
          return const SizedBox.shrink();
        }
        final item = active.first;
        final progress = item.progress;
        final label = active.length > 1
            ? '${active.length} downloads em andamento'
            : progress == null
                ? 'Download em andamento'
                : 'Download ${(progress * 100).floor()}%';
        final scheme = Theme.of(context).colorScheme;

        return Tooltip(
          message: label,
          child: FloatingActionButton.small(
            heroTag: 'global_download_status',
            onPressed: onTap,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    value: progress,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                Icon(
                  Icons.download_rounded,
                  size: 17,
                  color: scheme.onPrimaryContainer,
                ),
                if (active.length > 1)
                  Positioned(
                    right: -9,
                    top: -9,
                    child: _TransferCountBadge(count: active.length),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TransferCountBadge extends StatelessWidget {
  const _TransferCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.error,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          color: scheme.onError,
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
