import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:github_manager/features/uploads/domain/managed_upload.dart';
import 'package:github_manager/features/uploads/presentation/upload_providers.dart';
import 'package:go_router/go_router.dart';

class UploadCenterButton extends ConsumerWidget {
  const UploadCenterButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manager = ref.watch(uploadManagerProvider);
    return StreamBuilder<List<ManagedUpload>>(
      stream: manager.stream,
      initialData: manager.items,
      builder: (context, snapshot) {
        final items = snapshot.data ?? manager.items;
        final active = items.where((item) => item.isActive).length;
        return IconButton(
          onPressed: () => context.push('/uploads'),
          tooltip: active > 0 ? '$active envio(s) em andamento' : 'Central de Envios',
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.cloud_upload_outlined),
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

class UploadFloatingStatusButton extends ConsumerWidget {
  const UploadFloatingStatusButton({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manager = ref.watch(uploadManagerProvider);
    return StreamBuilder<List<ManagedUpload>>(
      stream: manager.stream,
      initialData: manager.items,
      builder: (context, _) {
        final active = manager.items.where((item) => item.isActive).toList();
        if (active.isEmpty) return const SizedBox.shrink();
        final item = active.first;
        final progress = item.progress;
        final label = active.length > 1
            ? '${active.length} envios em andamento'
            : item.status == ManagedUploadStatus.queued
                ? 'Envio na fila'
                : item.status == ManagedUploadStatus.startingBuild
                    ? 'Iniciando build'
                    : progress == null
                        ? 'Envio em andamento'
                        : 'Envio ${(progress * 100).floor()}%';
        final scheme = Theme.of(context).colorScheme;

        return Tooltip(
          message: label,
          child: FloatingActionButton.small(
            heroTag: 'global_upload_status',
            onPressed: onTap,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 28,
                  height: 28,
                  child: item.status == ManagedUploadStatus.queued
                      ? Icon(
                          Icons.schedule_rounded,
                          size: 24,
                          color: scheme.onPrimaryContainer,
                        )
                      : CircularProgressIndicator(
                          strokeWidth: 2.4,
                          value: progress,
                          color: scheme.onPrimaryContainer,
                        ),
                ),
                if (item.status != ManagedUploadStatus.queued)
                  Icon(
                    Icons.cloud_upload_outlined,
                    size: 16,
                    color: scheme.onPrimaryContainer,
                  ),
                if (active.length > 1)
                  Positioned(
                    right: -9,
                    top: -9,
                    child: _UploadCountBadge(count: active.length),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _UploadCountBadge extends StatelessWidget {
  const _UploadCountBadge({required this.count});

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
