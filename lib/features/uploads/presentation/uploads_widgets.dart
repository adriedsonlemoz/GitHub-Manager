part of 'uploads_screen.dart';

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
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(3, 5, 3, 4),
      child: Row(
        children: [
          Icon(icon, size: 17, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: .65),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              '$count',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ],
      ),
    );
  }
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
    final scheme = Theme.of(context).colorScheme;
    final progress = item.progress;
    final statusColor = switch (item.status) {
      ManagedUploadStatus.completed => Colors.green.shade600,
      ManagedUploadStatus.noChanges => scheme.tertiary,
      ManagedUploadStatus.failed ||
      ManagedUploadStatus.interrupted =>
        scheme.error,
      _ => scheme.primary,
    };

    final actionItems = <_UploadAction>[
      if (onRetry != null)
        _UploadAction(
          icon: Icons.refresh_rounded,
          label: 'Repetir',
          onPressed: onRetry!,
        ),
      if (onRunAnyway != null)
        _UploadAction(
          icon: Icons.play_arrow_rounded,
          label: 'Executar',
          onPressed: onRunAnyway!,
          filled: true,
        ),
      if (onOpenBuilds != null)
        _UploadAction(
          icon: Icons.play_circle_outline_rounded,
          label: 'Builds',
          onPressed: onOpenBuilds!,
        ),
      _UploadAction(
        icon: Icons.receipt_long_outlined,
        label: 'Relatório',
        onPressed: () => _showDetails(context, item),
      ),
      if (onRemove != null)
        _UploadAction(
          icon: Icons.delete_outline_rounded,
          label: 'Excluir',
          onPressed: onRemove!,
        ),
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(13),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
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
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: item.projectName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (item.versionLabel != 'Não identificada')
                            TextSpan(
                              text: '  v${item.versionLabel}',
                              style: TextStyle(
                                color: scheme.primary,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 7),
                  _UploadStatusBadge(
                    label: item.statusLabel,
                    color: statusColor,
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                '${item.repositoryFullName} | ${item.branch}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                item.phase,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              if (item.isActive) ...[
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.status == ManagedUploadStatus.startingBuild
                      ? 'Arquivos sincronizados | aguardando GitHub Actions'
                      : '${item.current.clamp(0, item.total)} de ${item.total} arquivos'
                          '${progress == null ? '' : ' | ${(progress * 100).round()}%'}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
              if (item.analyzedFiles > 0 || !item.isActive) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 5,
                  runSpacing: 4,
                  children: [
                    _UploadMetric(
                      label: 'Analisados',
                      value: '${item.analyzedFiles > 0 ? item.analyzedFiles : item.fileCount}',
                    ),
                    if (item.sentFiles > 0)
                      _UploadMetric(
                        label: 'Enviados',
                        value: '${item.sentFiles}',
                      ),
                    if (item.unchangedFiles > 0)
                      _UploadMetric(
                        label: 'Atualizados',
                        value: '${item.unchangedFiles}',
                      ),
                    _UploadMetric(
                      label: 'Duração',
                      value: item.elapsedLabel,
                    ),
                    if (item.commitSha?.isNotEmpty == true)
                      _UploadMetric(
                        label: 'Commit',
                        value: _shortSha(item.commitSha!),
                      ),
                  ],
                ),
              ],
              if (item.errorMessage?.isNotEmpty == true) ...[
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer.withValues(alpha: .38),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    item.errorMessage!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.error,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
              if (item.isActive && item.hasCheckpoint) ...[
                const SizedBox(height: 5),
                Row(
                  children: [
                    Icon(
                      Icons.save_outlined,
                      size: 15,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        item.checkpointLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                      ),
                    ),
                  ],
                ),
              ],
              if (actionItems.isNotEmpty) ...[
                const SizedBox(height: 7),
                Row(
                  children: [
                    for (var index = 0;
                        index < actionItems.length;
                        index++) ...[
                      if (index > 0) const SizedBox(width: 5),
                      Expanded(
                        child: _CompactUploadActionButton(
                          action: actionItems[index],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _shortSha(String sha) =>
      sha.length > 7 ? sha.substring(0, 7) : sha;

  static Future<void> _showDetails(
    BuildContext context,
    ManagedUpload item,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => UploadDetailsDialog(item: item),
    );
  }
}

class _UploadStatusBadge extends StatelessWidget {
  const _UploadStatusBadge({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
}

class _UploadMetric extends StatelessWidget {
  const _UploadMetric({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: .48),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$value $label',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _UploadAction {
  const _UploadAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool filled;
}

class _CompactUploadActionButton extends StatelessWidget {
  const _CompactUploadActionButton({required this.action});

  final _UploadAction action;

  @override
  Widget build(BuildContext context) {
    final child = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(action.icon, size: 16),
        const SizedBox(height: 1),
        Text(
          action.label,
          maxLines: 1,
          overflow: TextOverflow.fade,
          softWrap: false,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 10.5,
              ),
        ),
      ],
    );

    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, 43)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      ),
      visualDensity: VisualDensity.compact,
    );

    return action.filled
        ? FilledButton.tonal(
            onPressed: action.onPressed,
            style: style,
            child: child,
          )
        : OutlinedButton(
            onPressed: action.onPressed,
            style: style,
            child: child,
          );
  }
}
