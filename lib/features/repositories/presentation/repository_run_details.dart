part of 'repository_actions_screen.dart';

class _RunDetailsSheet extends ConsumerStatefulWidget {
  const _RunDetailsSheet({
    required this.repositoryFullName,
    required this.run,
    required this.onChanged,
    required this.onOpenArtifacts,
    required this.readOnly,
  });

  final String repositoryFullName;
  final RepositoryWorkflowRun run;
  final VoidCallback onChanged;
  final VoidCallback onOpenArtifacts;
  final bool readOnly;

  @override
  ConsumerState<_RunDetailsSheet> createState() => _RunDetailsSheetState();
}

class _RunDetailsSheetState extends ConsumerState<_RunDetailsSheet>
    with _RunDetailsStateController {
  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .62,
      minChildSize: .38,
      maxChildSize: .94,
      builder: (context, scrollController) =>
          FutureBuilder<List<RepositoryWorkflowJob>>(
        future: _jobsFuture,
        builder: (context, snapshot) {
          final jobs =
              snapshot.data ?? _currentJobs ?? const <RepositoryWorkflowJob>[];
          RepositoryWorkflowJob? failedJob;
          for (final job in jobs) {
            if (job.failed) {
              failedJob = job;
              break;
            }
          }

          final scheme = Theme.of(context).colorScheme;
          final statusColor = _run.conclusion == 'failure'
              ? scheme.error
              : _run.isRunning
                  ? scheme.primary
                  : scheme.onSurfaceVariant;

          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 88),
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: _RunStatusIcon(run: _run),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_run.name} #${_run.runNumber}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_run.branch} • ${_run.shortSha} • '
                                '${_RepositoryActionsScreenState._formatDate(_run.startedAt ?? _run.createdAt)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => _refresh(),
                          tooltip: 'Atualizar',
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.refresh_rounded, size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 8,
                      runSpacing: 5,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (_run.detectedVersion != null)
                          Text(
                            'v${_run.detectedVersion}',
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        Text(
                          _RepositoryActionsScreenState._statusLabel(_run),
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(
                                color: statusColor,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        Text(
                          _run.isRunning
                              ? 'Atualizando automaticamente'
                              : _RepositoryActionsScreenState._formatDuration(_run),
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                    if (_run.commitMessage.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        _run.commitMessage.split('\n').first,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _RunActionButton(
                      icon: Icons.download_for_offline_outlined,
                      label: 'Logs',
                      onPressed: _working ? null : _downloadLogs,
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (!widget.readOnly && _run.isRunning) ...[
                    Expanded(
                      child: _RunActionButton(
                        icon: Icons.stop_circle_outlined,
                        label: 'Cancelar',
                        onPressed: _working ? null : _cancel,
                      ),
                    ),
                  ] else if (!_run.isRunning) ...[
                    if (!widget.readOnly) ...[
                      Expanded(
                        child: _RunActionButton(
                          icon: Icons.replay_rounded,
                          label: 'Repetir',
                          onPressed: _working ? null : _rerun,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: _RunActionButton(
                        icon: Icons.android_rounded,
                        label: 'APK',
                        filled: true,
                        onPressed: () {
                          Navigator.of(context).pop();
                          widget.onOpenArtifacts();
                        },
                      ),
                    ),
                    if (!widget.readOnly) ...[
                      const SizedBox(width: 6),
                      Expanded(
                        child: _RunActionButton(
                          icon: Icons.delete_outline_rounded,
                          label: 'Excluir',
                          onPressed: _working ? null : _deleteRun,
                        ),
                      ),
                    ],
                  ],
                ],
              ),
              const SizedBox(height: 8),
              _RunInformationCard(run: _run, jobs: jobs),
              if (failedJob != null) ...[
                const SizedBox(height: 8),
                _FailureSummaryCard(
                  repositoryFullName: widget.repositoryFullName,
                  run: _run,
                  job: failedJob,
                ),
              ],
              const SizedBox(height: 12),
              Text(
                'Etapas',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 7),
              if (snapshot.connectionState == ConnectionState.waiting &&
                  jobs.isEmpty)
                const LinearProgressIndicator()
              else if (snapshot.hasError && jobs.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    snapshot.error is AppException
                        ? (snapshot.error! as AppException).message
                        : 'Não foi possível carregar jobs e etapas.',
                  ),
                )
              else if (jobs.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Os jobs ainda não foram publicados pelo GitHub.',
                  ),
                )
              else
                ...jobs.map(
                  (job) => Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Container(
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: ExpansionTile(
                        tilePadding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        childrenPadding:
                            const EdgeInsets.fromLTRB(4, 0, 4, 6),
                        leading: _JobIcon(job: job),
                        title: Text(
                          job.name,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          '${_RepositoryActionsScreenState._jobStatus(job)} • '
                          '${_RepositoryActionsScreenState._formatSpan(job.startedAt, job.completedAt)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        initiallyExpanded:
                            job.status != 'completed' || job.failed,
                        children: job.steps
                            .map(
                              (step) => _WorkflowStepTile(step: step),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
