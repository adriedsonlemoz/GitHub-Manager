part of 'repository_actions_screen.dart';

class _RunGroup {
  const _RunGroup(this.runs);

  final List<RepositoryWorkflowRun> runs;

  RepositoryWorkflowRun get primary => runs.first;

  DateTime? get latestAt {
    DateTime? latest;
    for (final run in runs) {
      final value = run.createdAt ?? run.startedAt;
      if (value != null && (latest == null || value.isAfter(latest))) {
        latest = value;
      }
    }
    return latest;
  }

  DateTime? get createdAt => latestAt;

  String get shortSha => primary.shortSha;

  String get title {
    if (primary.event == 'push') {
      return 'Atualização';
    }
    if (primary.event == 'workflow_dispatch') {
      return 'Build manual';
    }
    return primary.title.trim().isEmpty ? 'Execução' : primary.title;
  }

  String get eventLabel {
    if (primary.event == 'workflow_dispatch') {
      return 'manual';
    }
    final event = primary.event.trim();
    return event.isEmpty ? 'evento -' : event;
  }
}

class _RunGroupCard extends StatelessWidget {
  const _RunGroupCard({
    required this.group,
    required this.onRunTap,
    required this.onRunLongPress,
    required this.selectionMode,
    required this.selectedRunIds,
  });

  final _RunGroup group;
  final ValueChanged<RepositoryWorkflowRun> onRunTap;
  final ValueChanged<RepositoryWorkflowRun> onRunLongPress;
  final bool selectionMode;
  final Set<int> selectedRunIds;

  @override
  Widget build(BuildContext context) {
    final timestamp = _RepositoryActionsScreenState._formatDate(group.createdAt);
    final sha = group.shortSha.isEmpty ? 'commit -' : group.shortSha;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${group.title} • $timestamp',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      if (group.runs.first.detectedVersion != null) ...[
                        const SizedBox(height: 1),
                        Row(
                          children: [
                            const Icon(Icons.new_releases_outlined, size: 15),
                            const SizedBox(width: 5),
                            Text(
                              'Versão ${group.runs.first.detectedVersion}',
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 1),
                      Text(
                        '$sha • ${group.eventLabel} • ${group.runs.length} ${group.runs.length == 1 ? 'workflow' : 'workflows'}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ...group.runs.map(
              (run) => _RunResultTile(
                run: run,
                selectionMode: selectionMode,
                selected: selectedRunIds.contains(run.id),
                onTap: () => onRunTap(run),
                onLongPress: run.isRunning
                    ? null
                    : () => onRunLongPress(run),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _RunResultTile extends StatelessWidget {
  const _RunResultTile({
    required this.run,
    required this.onTap,
    required this.selectionMode,
    required this.selected,
    this.onLongPress,
  });

  final RepositoryWorkflowRun run;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool selectionMode;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isSuccess = run.status == 'completed' && run.conclusion == 'success';
    final isFailure = run.status == 'completed' && run.conclusion == 'failure';
    final statusColor = isSuccess
        ? Colors.green.shade600
        : isFailure
            ? scheme.error
            : scheme.primary;

    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: statusColor.withValues(alpha: .30)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(9, 8, 7, 8),
          child: Row(
            children: [
              if (selectionMode)
                Checkbox(
                  value: selected,
                  visualDensity: VisualDensity.compact,
                  onChanged: run.isRunning ? null : (_) => onTap(),
                )
              else
                Icon(
                  run.isRunning
                      ? Icons.sync_rounded
                      : isSuccess
                          ? Icons.check_circle_rounded
                          : isFailure
                              ? Icons.error_rounded
                              : Icons.schedule_rounded,
                  color: statusColor,
                  size: 21,
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${run.name} #${run.runNumber}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: .14),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _RepositoryActionsScreenState._statusLabel(run),
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${run.detectedVersion == null ? '' : 'v${run.detectedVersion} • '}'
                      '${run.branch} • ${_RepositoryActionsScreenState._formatDuration(run)} • '
                      '${_RepositoryActionsScreenState._formatDate(run.createdAt)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              if (run.isRunning)
                SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(strokeWidth: 2, color: statusColor),
                )
              else if (!selectionMode)
                const Icon(Icons.chevron_right_rounded, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkflowStepTile extends StatelessWidget {
  const _WorkflowStepTile({required this.step});

  final RepositoryWorkflowStep step;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isSuccess =
        step.status == 'completed' && step.conclusion == 'success';
    final isFailure =
        step.status == 'completed' && step.conclusion == 'failure';
    final accent = isFailure
        ? scheme.error
        : isSuccess
            ? Colors.green.shade500
            : scheme.onSurfaceVariant;
    final background = isFailure
        ? scheme.errorContainer.withValues(alpha: .38)
        : scheme.surfaceContainerHighest.withValues(alpha: .34);

    return Container(
      margin: const EdgeInsets.fromLTRB(7, 3, 7, 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(9),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
        minVerticalPadding: 5,
        leading: Icon(
          step.status != 'completed'
              ? Icons.radio_button_unchecked_rounded
              : isSuccess
                  ? Icons.check_circle_outline_rounded
                  : isFailure
                      ? Icons.error_outline_rounded
                      : Icons.remove_circle_outline_rounded,
          size: 19,
          color: accent,
        ),
        title: Text(
          step.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: isFailure ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
        subtitle: Text(
          '${_RepositoryActionsScreenState._stepExplanation(step.name)} • '
          '${_RepositoryActionsScreenState._stepStatus(step)}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _ActionsQuickBar extends StatelessWidget {
  const _ActionsQuickBar({
    required this.starting,
    required this.onRun,
    required this.onRefresh,
    required this.onArtifacts,
    required this.onDiagnostics,
    required this.onPermissions,
  });

  final bool starting;
  final VoidCallback onRun;
  final VoidCallback onRefresh;
  final VoidCallback onArtifacts;
  final VoidCallback onDiagnostics;
  final VoidCallback onPermissions;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        child: Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: starting ? null : onRun,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 38),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  visualDensity: VisualDensity.compact,
                ),
                icon: starting
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow_rounded, size: 19),
                label: const Text('Executar'),
              ),
            ),
            const SizedBox(width: 6),
            _CompactIconAction(
              icon: Icons.refresh_rounded,
              tooltip: 'Atualizar',
              onPressed: onRefresh,
            ),
            _CompactIconAction(
              icon: Icons.android_rounded,
              tooltip: 'APKs e artifacts',
              onPressed: onArtifacts,
            ),
            _CompactIconAction(
              icon: Icons.monitor_heart_outlined,
              tooltip: 'Diagnóstico',
              onPressed: onDiagnostics,
            ),
            _CompactIconAction(
              icon: Icons.verified_user_outlined,
              tooltip: 'Permissões',
              onPressed: onPermissions,
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactIconAction extends StatelessWidget {
  const _CompactIconAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints.tightFor(width: 38, height: 38),
        icon: Icon(icon, size: 18),
      );
}

class _WorkflowsPanel extends StatelessWidget {
  const _WorkflowsPanel({
    required this.data,
    required this.selectedWorkflow,
    required this.onSelected,
  });

  final RepositoryActionsData data;
  final RepositoryWorkflow? selectedWorkflow;
  final ValueChanged<RepositoryWorkflow?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Workflows',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                Text(
                  '${data.allRuns.length} execuções',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _WorkflowChip(
                    selected: selectedWorkflow == null,
                    icon: Icons.all_inclusive_rounded,
                    label: 'Todos',
                    count: data.allRuns.length,
                    onTap: () => onSelected(null),
                  ),
                  ...data.workflows.map((workflow) => Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: _WorkflowChip(
                          selected: selectedWorkflow?.id == workflow.id,
                          icon: workflow.isActive
                              ? Icons.check_circle_outline_rounded
                              : Icons.pause_circle_outline_rounded,
                          label: workflow.name,
                          count: data.countFor(workflow),
                          onTap: () => onSelected(workflow),
                        ),
                      )),
                ],
              ),
            ),
            if (selectedWorkflow != null) ...[
              const SizedBox(height: 8),
              Builder(builder: (context) {
                final workflow = selectedWorkflow!;
                final latest = data.latestFor(workflow);
                final status = latest == null
                    ? 'Sem execução'
                    : '${_RepositoryActionsScreenState._statusLabel(latest)} • #${latest.runNumber}';
                return Text(
                  '${workflow.isActive ? 'Ativo' : workflow.state} • $status • ${workflow.path}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

class _WorkflowChip extends StatelessWidget {
  const _WorkflowChip({
    required this.selected,
    required this.icon,
    required this.label,
    required this.count,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ChoiceChip(
        selected: selected,
        onSelected: (_) => onTap(),
        avatar: Icon(icon, size: 16),
        label: Text('$label · $count'),
        labelStyle: const TextStyle(fontWeight: FontWeight.w700),
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 4),
      );
}

class _ActionsDiagnosticCard extends StatelessWidget {
  const _ActionsDiagnosticCard({required this.diagnostic});

  final RepositoryActionsDiagnostic diagnostic;

  @override
  Widget build(BuildContext context) {
    final lines = <String>[
      if (diagnostic.workflowName != null) 'Workflow: ${diagnostic.workflowName}',
      if (diagnostic.workflowId != null) 'Workflow ID: ${diagnostic.workflowId}',
      if (diagnostic.workflowPath != null) 'Arquivo: ${diagnostic.workflowPath}',
      if (diagnostic.workflowState != null)
        'Status: ${diagnostic.workflowState == 'active' ? 'Ativo' : diagnostic.workflowState}',
      'Runs recebidos: ${diagnostic.repositoryRunsReceived}',
      'Após filtro: ${diagnostic.runsAfterFilter}',
      if (diagnostic.totalCountReported != null)
        'Total informado pelo GitHub: ${diagnostic.totalCountReported}',
      'Endpoint principal: ${diagnostic.endpoint}',
      'HTTP principal: ${diagnostic.httpStatus ?? '-'}',
      'Diagnóstico: ${diagnostic.reason}',
      if (diagnostic.fallbackEndpoint != null)
        'Fallback: ${diagnostic.fallbackEndpoint}',
      if (diagnostic.fallbackHttpStatus != null)
        'HTTP fallback: ${diagnostic.fallbackHttpStatus}',
      if (diagnostic.fallbackRunsReceived != null)
        'Runs no fallback: ${diagnostic.fallbackRunsReceived}',
    ];
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.monitor_heart_outlined),
        title: const Text('Diagnóstico do GitHub Actions'),
        subtitle: const Text('Nenhum token ou Authorization é exibido.'),
        initiallyExpanded: diagnostic.runsAfterFilter == 0,
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: SelectableText(lines.join('\n')),
          ),
        ],
      ),
    );
  }
}

class _EmptyRunsCard extends StatelessWidget {
  const _EmptyRunsCard({required this.diagnostic});

  final RepositoryActionsDiagnostic diagnostic;

  @override
  Widget build(BuildContext context) {
    final message = diagnostic.repositoryRunsReceived > 0
        ? 'O GitHub retornou ${diagnostic.repositoryRunsReceived} execuções, mas nenhuma correspondeu ao workflow selecionado. O diagnóstico acima mostra o ID, arquivo e fallback consultados.'
        : diagnostic.httpStatus == 200
            ? 'A API respondeu HTTP 200, mas retornou zero execuções. Isso é diferente de um erro de filtro; confira o diagnóstico acima.'
            : 'Não foi possível confirmar execuções para esta seleção. Confira o diagnóstico da API.';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Text(message),
      ),
    );
  }
}
