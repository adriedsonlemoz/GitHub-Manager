part of 'downloads_screen.dart';

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
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
        child: Row(
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 7),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const Spacer(),
            _DownloadBadge(label: '$count', icon: Icons.layers_outlined),
          ],
        ),
      );
}

class _ActiveDownloadCard extends StatelessWidget {
  const _ActiveDownloadCard({required this.item, required this.onCancel});

  final ManagedDownload item;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final percent = item.progress == null ? null : (item.progress! * 100).floor();
    return _DownloadCardShell(
      item: item,
      badges: [
        _DownloadBadge(label: item.typeLabel, icon: _typeIcon(item.type)),
        _DownloadBadge(
          label: percent == null ? item.statusLabel : '$percent%',
          icon: Icons.downloading_rounded,
          emphasized: true,
        ),
      ],
      details: [
        _bytesLine(item),
        if (item.bytesPerSecond > 0) '${_formatBytes(item.bytesPerSecond.round())}/s',
        if (item.estimatedSecondsRemaining != null)
          _etaText(item.estimatedSecondsRemaining!),
      ],
      progress: item.progress,
      actions: [
        _CompactDownloadButton(
          onPressed: onCancel,
          icon: Icons.close_rounded,
          label: 'Cancelar',
        ),
      ],
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
    final descriptor = _DownloadDescriptor.fromItem(item);
    final size = _formatBytes(item.totalBytes > 0 ? item.totalBytes : item.receivedBytes);
    return _DownloadCardShell(
      item: item,
      menu: PopupMenuButton<String>(
        tooltip: 'Mais ações',
        onSelected: (value) {
          if (value == 'history') onRemoveHistory();
        },
        itemBuilder: (_) => const [
          PopupMenuItem(
            value: 'history',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.history_toggle_off_rounded),
              title: Text('Remover do histórico'),
            ),
          ),
        ],
      ),
      badges: [
        _DownloadBadge(label: descriptor.format, icon: descriptor.icon),
        if (descriptor.buildType != null)
          _DownloadBadge(
            label: descriptor.buildType!,
            icon: Icons.build_circle_outlined,
            emphasized: descriptor.stable,
          ),
        const _DownloadBadge(
          label: 'Concluído',
          icon: Icons.check_circle_outline_rounded,
          emphasized: true,
        ),
      ],
      details: [
        size,
        _formatDate(item.completedAt ?? item.createdAt),
        'Downloads/${item.fileName}',
      ],
      actions: [
        _CompactDownloadButton(
          onPressed: item.isApk ? onInstall : onOpen,
          icon: item.isApk ? Icons.install_mobile_rounded : Icons.open_in_new_rounded,
          label: item.isApk ? 'Instalar' : 'Abrir',
          primary: true,
        ),
        _CompactDownloadButton(
          onPressed: onShare,
          icon: Icons.share_outlined,
          label: 'Compartilhar',
        ),
        _CompactDownloadButton(
          onPressed: onDeleteFile,
          icon: Icons.delete_outline_rounded,
          label: 'Excluir',
        ),
      ],
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
  Widget build(BuildContext context) => _DownloadCardShell(
        item: item,
        badges: [
          _DownloadBadge(label: item.typeLabel, icon: _typeIcon(item.type)),
          _DownloadBadge(
            label: item.statusLabel,
            icon: Icons.error_outline_rounded,
            danger: true,
          ),
        ],
        details: [
          item.errorMessage ?? 'Não foi possível concluir o download.',
          if (item.httpStatus != null || item.errorCode != null)
            [
              if (item.httpStatus != null) 'HTTP ${item.httpStatus}',
              if (item.errorCode != null) item.errorCode!,
            ].join(' • '),
          if (item.canResume) '${_formatBytes(item.receivedBytes)} preservados',
        ],
        actions: [
          if (onRetry != null)
            _CompactDownloadButton(
              onPressed: onRetry,
              icon: item.canResume ? Icons.play_arrow_rounded : Icons.refresh_rounded,
              label: item.canResume ? 'Retomar' : 'Tentar',
              primary: true,
            ),
          _CompactDownloadButton(
            onPressed: onDetails,
            icon: Icons.description_outlined,
            label: 'Detalhes',
          ),
          _CompactDownloadButton(
            onPressed: onRemoveHistory,
            icon: Icons.history_toggle_off_rounded,
            label: 'Remover',
          ),
        ],
      );
}

class _DownloadCardShell extends StatelessWidget {
  const _DownloadCardShell({
    required this.item,
    required this.badges,
    required this.details,
    required this.actions,
    this.progress,
    this.menu,
  });

  final ManagedDownload item;
  final List<Widget> badges;
  final List<String> details;
  final List<Widget> actions;
  final double? progress;
  final Widget? menu;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: .70),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    item.isApk ? Icons.android_rounded : _typeIcon(item.type),
                    size: 21,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.fileName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                if (menu != null) menu!,
              ],
            ),
            const SizedBox(height: 9),
            Wrap(spacing: 6, runSpacing: 6, children: badges),
            if (progress != null) ...[
              const SizedBox(height: 9),
              LinearProgressIndicator(value: progress),
            ],
            if (details.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                details.where((value) => value.trim().isNotEmpty).join(' • '),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.35,
                    ),
              ),
            ],
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 11),
              Row(
                children: [
                  for (var i = 0; i < actions.length; i++) ...[
                    if (i > 0) const SizedBox(width: 7),
                    Expanded(child: actions[i]),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CompactDownloadButton extends StatelessWidget {
  const _CompactDownloadButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    this.primary = false,
  });

  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, 40)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 7, vertical: 8),
      ),
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ),
      ],
    );
    return primary
        ? FilledButton(onPressed: onPressed, style: style, child: child)
        : OutlinedButton(onPressed: onPressed, style: style, child: child);
  }
}

class _DownloadBadge extends StatelessWidget {
  const _DownloadBadge({
    required this.label,
    required this.icon,
    this.emphasized = false,
    this.danger = false,
  });

  final String label;
  final IconData icon;
  final bool emphasized;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = danger
        ? scheme.error
        : emphasized
            ? scheme.primary
            : scheme.onSurfaceVariant;
    final background = danger
        ? scheme.errorContainer.withValues(alpha: .45)
        : emphasized
            ? scheme.primaryContainer.withValues(alpha: .55)
            : scheme.surfaceContainerHighest.withValues(alpha: .60);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: foreground.withValues(alpha: .18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: foreground),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _DownloadDescriptor {
  const _DownloadDescriptor({
    required this.format,
    required this.icon,
    required this.buildType,
    required this.stable,
  });

  final String format;
  final IconData icon;
  final String? buildType;
  final bool stable;

  factory _DownloadDescriptor.fromItem(ManagedDownload item) {
    final lower = item.fileName.toLowerCase();
    if (!item.isApk) {
      return _DownloadDescriptor(
        format: item.typeLabel,
        icon: _typeIcon(item.type),
        buildType: null,
        stable: false,
      );
    }
    String buildType = 'Release provável';
    var stable = true;
    if (lower.contains('debug')) {
      buildType = 'Debug';
      stable = false;
    } else if (lower.contains('profile')) {
      buildType = 'Profile';
      stable = false;
    } else if (lower.contains('beta') ||
        lower.contains('alpha') ||
        lower.contains('preview') ||
        lower.contains('rc')) {
      buildType = 'Prévia';
      stable = false;
    } else if (lower.contains('release') || lower.contains('stable')) {
      buildType = 'Release';
    }
    return _DownloadDescriptor(
      format: 'APK',
      icon: Icons.android_rounded,
      buildType: buildType,
      stable: stable,
    );
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
  if (seconds < 60) return '~$seconds s restantes';
  return '~${(seconds / 60).ceil()} min restantes';
}

String _formatDate(DateTime date) {
  final local = date.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
}
