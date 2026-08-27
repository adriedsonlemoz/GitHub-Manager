import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:github_manager/features/uploads/domain/managed_upload.dart';

class UploadDetailsDialog extends StatelessWidget {
  const UploadDetailsDialog({required this.item, super.key});

  final ManagedUpload item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final statusColor = _statusColor(scheme, item.status);

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      title: Row(
        children: [
          Icon(Icons.receipt_long_rounded, color: statusColor),
          const SizedBox(width: 10),
          const Expanded(child: Text('Relatório do envio')),
          _StatusBadge(label: item.statusLabel, color: statusColor),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ResultBanner(item: item, color: statusColor),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Metric(
                    icon: Icons.inventory_2_outlined,
                    value: '${item.fileCount}',
                    label: 'analisados',
                  ),
                  _Metric(
                    icon: Icons.edit_outlined,
                    value: '${item.changedFiles}',
                    label: 'alterados',
                  ),
                  _Metric(
                    icon: Icons.check_circle_outline_rounded,
                    value: '${item.unchangedFiles}',
                    label: 'já atualizados',
                  ),
                  if (item.resumedFiles > 0)
                    _Metric(
                      icon: Icons.restore_rounded,
                      value: '${item.resumedFiles}',
                      label: 'retomados',
                    ),
                  if (item.removedFiles > 0)
                    _Metric(
                      icon: Icons.delete_outline_rounded,
                      value: '${item.removedFiles}',
                      label: 'removidos',
                    ),
                  _Metric(
                    icon: Icons.timer_outlined,
                    value: item.elapsedLabel,
                    label: 'duração',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _Section(
                icon: Icons.folder_outlined,
                title: 'Projeto',
                children: [
                  _InfoRow(label: 'Nome', value: item.projectName),
                  _InfoRow(label: 'Versão', value: item.versionLabel),
                  _InfoRow(label: 'Repositório', value: item.repositoryFullName),
                  _InfoRow(label: 'Branch', value: item.branch),
                  _InfoRow(label: 'ZIP', value: item.zipName),
                ],
              ),
              const SizedBox(height: 12),
              _Section(
                icon: Icons.account_tree_outlined,
                title: 'GitHub e build',
                children: [
                  _InfoRow(
                    label: 'Build',
                    value: item.buildTriggerLabel,
                    strong: true,
                  ),
                  if (item.commitSha?.isNotEmpty == true)
                    _InfoRow(
                      label: 'Commit',
                      value: _shortSha(item.commitSha!),
                      trailing: IconButton(
                        tooltip: 'Copiar commit',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => Clipboard.setData(
                          ClipboardData(text: item.commitSha!),
                        ),
                        icon: const Icon(Icons.copy_rounded, size: 18),
                      ),
                    ),
                  if (item.workflowName?.isNotEmpty == true)
                    _InfoRow(label: 'Workflow', value: item.workflowName!),
                  if (item.workflowPath?.isNotEmpty == true)
                    _InfoRow(label: 'Arquivo', value: item.workflowPath!),
                  if (item.workflowRunId != null)
                    _InfoRow(
                      label: 'Run ID',
                      value: '${item.workflowRunId}',
                    ),
                ],
              ),
              if (item.errorMessage?.isNotEmpty == true) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Erro',
                        style: TextStyle(
                          color: scheme.onErrorContainer,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.errorMessage!,
                        style: TextStyle(color: scheme.onErrorContainer),
                      ),
                      if (item.failedFilePath?.isNotEmpty == true) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Arquivo: ${item.failedFilePath}',
                          style: TextStyle(
                            color: scheme.onErrorContainer,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      if (item.errorCode?.isNotEmpty == true) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Código: ${item.errorCode}',
                          style: TextStyle(
                            color: scheme.onErrorContainer,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              if (item.changedFileSamples.isNotEmpty) ...[
                const SizedBox(height: 12),
                _ExpandableSection(
                  icon: Icons.description_outlined,
                  title: item.changedFiles > item.changedFileSamples.length
                      ? 'Arquivos alterados • amostra de ${item.changedFileSamples.length}'
                      : 'Arquivos alterados • ${item.changedFileSamples.length}',
                  children: item.changedFileSamples
                      .map(
                        (path) => Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.chevron_right_rounded, size: 17),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  path,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
              if (item.timelineLines.isNotEmpty) ...[
                const SizedBox(height: 12),
                _ExpandableSection(
                  initiallyExpanded: true,
                  icon: Icons.timeline_rounded,
                  title: 'Linha do tempo • ${item.timelineLines.length} etapas',
                  children: item.timelineLines
                      .map(
                        (line) => Padding(
                          padding: const EdgeInsets.only(bottom: 7),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.check_circle_outline_rounded,
                                size: 17,
                                color: scheme.primary,
                              ),
                              const SizedBox(width: 7),
                              Expanded(child: Text(line)),
                            ],
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
              const SizedBox(height: 12),
              _ExpandableSection(
                icon: Icons.text_snippet_outlined,
                title: 'Relatório em texto',
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: SelectableText(
                      item.technicalLog,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: item.technicalLog));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Relatório copiado')),
              );
            }
          },
          icon: const Icon(Icons.copy_all_rounded),
          label: const Text('Copiar relatório'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fechar'),
        ),
      ],
    );
  }

  static String _shortSha(String sha) =>
      sha.length > 12 ? sha.substring(0, 12) : sha;

  static Color _statusColor(ColorScheme scheme, ManagedUploadStatus status) =>
      switch (status) {
        ManagedUploadStatus.completed => scheme.primary,
        ManagedUploadStatus.noChanges => scheme.tertiary,
        ManagedUploadStatus.failed || ManagedUploadStatus.interrupted =>
          scheme.error,
        _ => scheme.primary,
      };
}

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
