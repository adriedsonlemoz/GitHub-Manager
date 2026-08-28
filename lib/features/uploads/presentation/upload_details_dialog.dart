import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:github_manager/features/uploads/domain/managed_upload.dart';

part 'upload_details_widgets.dart';

class UploadDetailsDialog extends StatelessWidget {
  const UploadDetailsDialog({required this.item, super.key});

  final ManagedUpload item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final statusColor = _statusColor(scheme, item.status);

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(16, 14, 10, 0),
      contentPadding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      title: Row(
        children: [
          Icon(Icons.receipt_long_rounded, color: statusColor),
          const SizedBox(width: 10),
          const Expanded(child: Text('Relatório do envio')),
          _StatusBadge(label: item.statusLabel, color: statusColor),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ResultBanner(item: item, color: statusColor),
              const SizedBox(height: 8),
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
              const SizedBox(height: 10),
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
