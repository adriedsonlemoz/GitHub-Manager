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

class _RunDetailsSheetState extends ConsumerState<_RunDetailsSheet> {
  late RepositoryWorkflowRun _run;
  late Future<List<RepositoryWorkflowJob>> _jobsFuture;
  Timer? _timer;
  bool _working = false;
  List<RepositoryWorkflowJob>? _currentJobs;

  @override
  void initState() {
    super.initState();
    _run = widget.run;
    _jobsFuture = _loadJobs();
    _updateTimer();
  }

  Future<List<RepositoryWorkflowJob>> _loadJobs() async {
    final jobs = await ref.read(repositoryGitServiceProvider).listWorkflowRunJobs(
          repositoryFullName: widget.repositoryFullName,
          runId: _run.id,
        );
    _currentJobs = jobs;
    return jobs;
  }

  void _updateTimer() {
    _timer?.cancel();
    if (_run.isRunning) {
      _timer = Timer.periodic(const Duration(seconds: 6), (_) {
        if (mounted) {
          _refresh(silent: true);
        }
      });
    }
  }

  Future<void> _refresh({bool silent = false}) async {
    try {
      final service = ref.read(repositoryGitServiceProvider);
      final runs = await service.listWorkflowRuns(widget.repositoryFullName);
      RepositoryWorkflowRun? latest;
      for (final item in runs) {
        if (item.id == _run.id) {
          latest = item;
          break;
        }
      }
      final jobsFuture = _loadJobs();
      if (mounted) {
        setState(() {
          if (latest != null) {
            _run = latest;
          }
          _jobsFuture = jobsFuture;
        });
        _updateTimer();
      }
      await jobsFuture;
      widget.onChanged();
    } catch (error) {
      if (!silent && mounted) {
        _showError(error);
      }
    }
  }

  Future<void> _cancel() async {
    setState(() => _working = true);
    try {
      await ref.read(repositoryGitServiceProvider).cancelWorkflowRun(
            repositoryFullName: widget.repositoryFullName,
            runId: _run.id,
          );
      await Future<void>.delayed(const Duration(seconds: 1));
      await _refresh();
    } catch (error) {
      if (mounted) {
        _showError(error);
      }
    } finally {
      if (mounted) {
        setState(() => _working = false);
      }
    }
  }

  Future<void> _rerun() async {
    setState(() => _working = true);
    try {
      await ref.read(repositoryGitServiceProvider).rerunWorkflowRun(
            repositoryFullName: widget.repositoryFullName,
            runId: _run.id,
          );
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      widget.onChanged();
    } catch (error) {
      if (mounted) {
        _showError(error);
        setState(() => _working = false);
      }
    }
  }

  Future<void> _deleteRun() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir execução permanentemente?'),
        content: Text(
          '${_run.name} #${_run.runNumber} será removida do GitHub Actions. '
          'Artifacts ligados a essa execução também podem ser removidos pelo GitHub. '
          'Esta ação não pode ser desfeita.',
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
    if (confirmed != true || !mounted) return;
    setState(() => _working = true);
    try {
      await ref.read(repositoryGitServiceProvider).deleteWorkflowRun(
            repositoryFullName: widget.repositoryFullName,
            runId: _run.id,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onChanged();
    } catch (error) {
      if (mounted) {
        _showError(error);
        setState(() => _working = false);
      }
    }
  }

  void _downloadLogs() {
    ref.read(downloadManagerProvider).startWorkflowLogs(
          repositoryFullName: widget.repositoryFullName,
          runId: _run.id,
          runTitle: '${_run.name}-${_run.runNumber}',
        );
    if (mounted) {
      showCenteredNotice(context, 'Download dos logs iniciado. Acompanhe pela Central de Downloads.');
    }
  }

  void _showError(Object error) {
    final message = error is GitHubPermissionException
        ? 'O token precisa de Actions: write para controlar builds.'
        : error is AppException
            ? error.message
            : 'Não foi possível atualizar esta execução.';
    showCenteredNotice(context, message);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

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
                  borderRadius: BorderRadius.circular(14),
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
              if (failedJob != null) ...[
                const SizedBox(height: 8),
                _FailureSummaryCard(
                  repositoryFullName: widget.repositoryFullName,
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
                    borderRadius: BorderRadius.circular(12),
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
                        borderRadius: BorderRadius.circular(13),
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
                          _RepositoryActionsScreenState._jobStatus(job),
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

class _RunActionButton extends StatelessWidget {
  const _RunActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final child = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18),
        const SizedBox(height: 1),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.fade,
          softWrap: false,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );

    return SizedBox(
      height: 46,
      child: filled
          ? FilledButton.tonal(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              ),
              child: child,
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              ),
              child: child,
            ),
    );
  }
}

class _FailureSummaryCard extends ConsumerWidget {
  const _FailureSummaryCard({
    required this.repositoryFullName,
    required this.job,
  });

  final String repositoryFullName;
  final RepositoryWorkflowJob job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final future = ref.read(repositoryGitServiceProvider).loadWorkflowFailure(
          repositoryFullName: repositoryFullName,
          job: job,
        );
    return FutureBuilder<RepositoryWorkflowFailure?>(
      future: future,
      builder: (context, snapshot) {
        final failure = snapshot.data;
        String? failedStep;
        for (final step in job.steps) {
          if (step.failed) {
            failedStep = step.name;
            break;
          }
        }

        final scheme = Theme.of(context).colorScheme;
        final message = failure?.message ??
            (snapshot.connectionState == ConnectionState.waiting
                ? 'Buscando a mensagem principal do erro...'
                : 'O GitHub não forneceu mais detalhes para esta falha.');

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: scheme.errorContainer.withValues(alpha: .42),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline_rounded, color: scheme.error, size: 21),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Erro principal',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: scheme.error,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${failure?.jobName ?? job.name} • '
                      '${failure?.stepName ?? failedStep ?? 'etapa não identificada'}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RunStatusIcon extends StatelessWidget {
  const _RunStatusIcon({required this.run});

  final RepositoryWorkflowRun run;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (run.isRunning) {
      return Icon(Icons.sync_rounded, color: scheme.primary);
    }
    return switch (run.conclusion) {
      'success' => Icon(Icons.check_circle_rounded, color: scheme.primary),
      'failure' => Icon(Icons.error_rounded, color: scheme.error),
      'cancelled' => Icon(Icons.cancel_rounded, color: scheme.onSurfaceVariant),
      _ => Icon(Icons.schedule_rounded, color: scheme.onSurfaceVariant),
    };
  }
}

class _JobIcon extends StatelessWidget {
  const _JobIcon({required this.job});

  final RepositoryWorkflowJob job;

  @override
  Widget build(BuildContext context) {
    if (job.status != 'completed') {
      return const Icon(Icons.sync_rounded);
    }
    return job.conclusion == 'success'
        ? const Icon(Icons.check_circle_outline_rounded)
        : Icon(
            Icons.error_outline_rounded,
            color: Theme.of(context).colorScheme.error,
          );
  }
}
