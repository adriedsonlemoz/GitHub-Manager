part of 'upload_details_dialog.dart';

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.item, required this.color});

  final ManagedUpload item;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_statusIcon(item.status), color: color, size: 28),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.phase,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.syncSummaryLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_formatDateTime(item.completedAt ?? item.failedAt ?? item.startedAt ?? item.createdAt)} • ${item.elapsedLabel}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }

  static IconData _statusIcon(ManagedUploadStatus status) => switch (status) {
        ManagedUploadStatus.completed => Icons.check_circle_rounded,
        ManagedUploadStatus.noChanges => Icons.info_rounded,
        ManagedUploadStatus.buildPending => Icons.warning_amber_rounded,
        ManagedUploadStatus.failed => Icons.cancel_rounded,
        ManagedUploadStatus.interrupted => Icons.pause_circle_filled_rounded,
        ManagedUploadStatus.queued => Icons.schedule_rounded,
        ManagedUploadStatus.syncing => Icons.cloud_upload_rounded,
        ManagedUploadStatus.startingBuild => Icons.rocket_launch_rounded,
      };
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
              ),
        ),
      );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 112),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(width: 7),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
              Text(label, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: scheme.primary),
              const SizedBox(width: 7),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _ExpandableSection extends StatelessWidget {
  const _ExpandableSection({
    required this.icon,
    required this.title,
    required this.children,
    this.initiallyExpanded = false,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        leading: Icon(icon, color: scheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        children: children,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.trailing,
    this.strong = false,
  });

  final String label;
  final String value;
  final Widget? trailing;
  final bool strong;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 92,
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SelectableText(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
                    ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      );
}


class _FailureReportCard extends StatelessWidget {
  const _FailureReportCard({required this.item});

  final ManagedUpload item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pending = item.isBuildPending;
    final accent = pending ? scheme.tertiary : scheme.error;
    final containerColor =
        pending ? scheme.tertiaryContainer : scheme.errorContainer;
    final foreground =
        pending ? scheme.onTertiaryContainer : scheme.onErrorContainer;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                pending ? Icons.warning_amber_rounded : Icons.error_outline_rounded,
                color: accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  pending
                      ? 'Build pendente • projeto enviado'
                      : 'Falha em “${item.failureOperationLabel}”',
                  style: TextStyle(
                    color: foreground,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.errorMessage!,
            style: TextStyle(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          _FailureParagraph(
            title: 'Método usado',
            text: '${item.uploadMethod.label} — ${item.uploadMethod.description}',
            color: foreground,
          ),
          const SizedBox(height: 8),
          _FailureParagraph(
            title: 'Próxima tentativa recomendada',
            text: item.recoveryRecommendationLabel,
            color: foreground,
          ),
          if (item.recoveryEvents.isNotEmpty) ...[
            const SizedBox(height: 8),
            _FailureParagraph(
              title: 'Histórico de recuperação',
              text: item.recoveryEvents.map((event) => '• $event').join('\n'),
              color: foreground,
            ),
          ],
          const SizedBox(height: 8),
          _FailureParagraph(
            title: 'Até onde chegou',
            text: item.failureProgressExplanation,
            color: foreground,
          ),
          if (item.failureRepositoryImpact != null) ...[
            const SizedBox(height: 8),
            _FailureParagraph(
              title: 'Impacto no repositório',
              text: item.failureRepositoryImpact!,
              color: foreground,
            ),
          ],
          const SizedBox(height: 8),
          _FailureParagraph(
            title: 'Resposta do GitHub',
            text: item.githubFailureResponse,
            color: foreground,
          ),
          const SizedBox(height: 8),
          _FailureParagraph(
            title: 'O que isso significa',
            text: item.failureMeaning,
            color: foreground,
          ),
          const SizedBox(height: 8),
          _FailureParagraph(
            title: 'O que fazer agora',
            text: item.failureSuggestedAction,
            color: foreground,
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: scheme.surface.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Detalhes técnicos',
                  style: TextStyle(
                    color: foreground,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                _FailureDetail(
                  label: 'Método',
                  value: item.uploadMethod.label,
                  color: foreground,
                ),
                if (item.errorCode?.isNotEmpty == true)
                  _FailureDetail(
                    label: 'Código',
                    value: item.errorCode!,
                    color: foreground,
                  ),
                if (item.errorHttpStatus != null)
                  _FailureDetail(
                    label: 'HTTP',
                    value: '${item.errorHttpStatus}',
                    color: foreground,
                  ),
                if (item.errorEndpoint?.isNotEmpty == true)
                  _FailureDetail(
                    label: 'Endpoint',
                    value: item.errorEndpoint!,
                    color: foreground,
                  ),
                if (item.failedFilePath?.isNotEmpty == true)
                  _FailureDetail(
                    label: 'Arquivo',
                    value: item.failedFilePath!,
                    color: foreground,
                  ),
                if (item.failureStage?.isNotEmpty == true)
                  _FailureDetail(
                    label: 'Etapa interna',
                    value: item.failureStage!,
                    color: foreground,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FailureParagraph extends StatelessWidget {
  const _FailureParagraph({
    required this.title,
    required this.text,
    required this.color,
  });

  final String title;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        SelectableText(text, style: TextStyle(color: color)),
      ],
    );
  }
}

class _FailureDetail extends StatelessWidget {
  const _FailureDetail({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
          ),
          Expanded(child: SelectableText(value, style: TextStyle(color: color))),
        ],
      ),
    );
  }
}
