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

class _RunInformationCard extends StatelessWidget {
  const _RunInformationCard({required this.run, required this.jobs});

  final RepositoryWorkflowRun run;
  final List<RepositoryWorkflowJob> jobs;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final steps = jobs.expand((job) => job.steps).toList(growable: false);
    final success = steps.where((step) => step.conclusion == 'success').length;
    final failed = steps.where((step) => step.conclusion == 'failure').length;
    final skipped = steps.where((step) => step.conclusion == 'skipped').length;
    final apkOutcome = _apkOutcome(run, jobs);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Informações da execução',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 7),
          _InfoLine(label: 'Execução', value: '#${run.runNumber}'),
          _InfoLine(
            label: 'Evento',
            value: '${_eventLabel(run.event)} • tentativa ${run.runAttempt}',
          ),
          _InfoLine(
            label: 'Branch',
            value: run.branch.trim().isEmpty ? '-' : run.branch,
          ),
          _InfoLine(
            label: 'Commit',
            value: run.shortSha.isEmpty ? '-' : run.shortSha,
          ),
          if (run.commitMessage.trim().isNotEmpty)
            _InfoLine(label: 'Mensagem', value: run.commitMessage.trim()),
          if (run.detectedVersion != null)
            _InfoLine(label: 'Versão', value: run.detectedVersion!),
          _InfoLine(
            label: 'Criada',
            value: _RepositoryActionsScreenState._formatDate(run.createdAt),
          ),
          _InfoLine(
            label: 'Iniciada',
            value: _RepositoryActionsScreenState._formatDate(run.startedAt),
          ),
          _InfoLine(
            label: 'Finalizada',
            value: run.isRunning
                ? 'Em andamento'
                : _RepositoryActionsScreenState._formatDate(run.updatedAt),
          ),
          _InfoLine(
            label: 'Duração',
            value: _RepositoryActionsScreenState._formatSpan(
              run.startedAt ?? run.createdAt,
              run.isRunning ? null : run.updatedAt,
            ),
          ),
          _InfoLine(
            label: 'Etapas',
            value: steps.isEmpty
                ? 'Ainda não publicadas pelo GitHub'
                : '${steps.length} total • $success concluída(s) • $failed falha(s)${skipped > 0 ? ' • $skipped ignorada(s)' : ''}',
          ),
          if (run.workflowPath.trim().isNotEmpty)
            _InfoLine(label: 'Workflow', value: run.workflowPath),
          if (apkOutcome != null) ...[
            const SizedBox(height: 5),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: scheme.secondaryContainer.withValues(alpha: .45),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                apkOutcome,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _eventLabel(String event) => switch (event) {
        'push' => 'Push',
        'workflow_dispatch' => 'Execução manual',
        'pull_request' => 'Pull request',
        'schedule' => 'Agendamento',
        'repository_dispatch' => 'Evento externo',
        _ => event.trim().isEmpty ? 'Não informado' : event,
      };

  static String? _apkOutcome(
    RepositoryWorkflowRun run,
    List<RepositoryWorkflowJob> jobs,
  ) {
    if (run.conclusion != 'failure') return null;
    for (final job in jobs) {
      final steps = job.steps;
      RepositoryWorkflowStep? failedStep;
      for (final step in steps) {
        if (step.failed) {
          failedStep = step;
          break;
        }
      }
      final failed = failedStep;
      if (failed == null) continue;
      if (_looksLikeApkBuildStep(failed.name)) {
        return 'APK: a execução falhou justamente na etapa de compilação/geração do aplicativo; o APK desta etapa não foi concluído.';
      }
      final laterBuild = steps.where(
        (step) =>
            step.number > failed.number && _looksLikeApkBuildStep(step.name),
      );
      if (laterBuild.any(
        (step) =>
            step.conclusion == 'skipped' ||
            step.conclusion == 'cancelled' ||
            step.status != 'completed',
      )) {
        return 'APK: o workflow falhou antes da etapa de compilação, por isso a geração do APK não chegou a ser concluída nesta execução.';
      }
      final built = steps.any(
        (step) => _looksLikeApkBuildStep(step.name) && step.conclusion == 'success',
      );
      final publishSteps = steps.where((step) => _looksLikePublishStep(step.name));
      if (built && publishSteps.isNotEmpty) {
        final published = publishSteps.any((step) => step.conclusion == 'success');
        if (!published) {
          return 'APK: a compilação aparece como concluída, mas a etapa de publicação/artifact não terminou com sucesso.';
        }
      }
    }
    return null;
  }

  static bool _looksLikeApkBuildStep(String name) {
    final value = name.toLowerCase();
    return value.contains('build apk') ||
        value.contains('gerar apk') ||
        value.contains('assemble') ||
        (value.contains('compil') &&
            (value.contains('android') || value.contains('apk')));
  }

  static bool _looksLikePublishStep(String name) {
    final value = name.toLowerCase();
    return value.contains('artifact') ||
        value.contains('upload') ||
        value.contains('publicar') ||
        value.contains('release');
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _FailureSummaryCard extends ConsumerStatefulWidget {
  const _FailureSummaryCard({
    required this.repositoryFullName,
    required this.run,
    required this.job,
  });

  final String repositoryFullName;
  final RepositoryWorkflowRun run;
  final RepositoryWorkflowJob job;

  @override
  ConsumerState<_FailureSummaryCard> createState() =>
      _FailureSummaryCardState();
}

class _FailureSummaryCardState extends ConsumerState<_FailureSummaryCard> {
  late Future<RepositoryWorkflowFailure?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant _FailureSummaryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.run.id != widget.run.id || oldWidget.job.id != widget.job.id) {
      _future = _load();
    }
  }

  Future<RepositoryWorkflowFailure?> _load() =>
      ref.read(repositoryGitServiceProvider).loadWorkflowFailure(
            repositoryFullName: widget.repositoryFullName,
            runId: widget.run.id,
            job: widget.job,
          );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RepositoryWorkflowFailure?>(
      future: _future,
      builder: (context, snapshot) {
        final failure = snapshot.data;
        RepositoryWorkflowStep? failedStepModel;
        for (final step in widget.job.steps) {
          if (step.failed) {
            failedStepModel = step;
            break;
          }
        }
        final jobName = failure?.jobName ?? widget.job.name;
        final stepName = failure?.stepName ??
            failedStepModel?.name ??
            'etapa não identificada';
        final stepTiming = failedStepModel == null
            ? ''
            : '\nInício da etapa: ${_RepositoryActionsScreenState._formatDate(failedStepModel.startedAt)}'
                '\nFim da etapa: ${_RepositoryActionsScreenState._formatDate(failedStepModel.completedAt)}'
                '\nDuração: ${_RepositoryActionsScreenState._formatSpan(failedStepModel.startedAt, failedStepModel.completedAt)}';
        final laterNotRun = failedStepModel == null
            ? 0
            : widget.job.steps
                .where(
                  (step) =>
                      step.number > failedStepModel!.number &&
                      (step.conclusion == 'skipped' ||
                          step.conclusion == 'cancelled' ||
                          step.status != 'completed'),
                )
                .length;
        final whatHappened = laterNotRun > 0
            ? 'A execução falhou no job “$jobName”, durante a etapa “$stepName”. Depois dessa falha, $laterNotRun etapa(s) posterior(es) não foram concluída(s).'
            : 'A execução terminou com falha no job “$jobName”, durante a etapa “$stepName”.';
        final scheme = Theme.of(context).colorScheme;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: scheme.errorContainer.withValues(alpha: .42),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    color: scheme.error,
                    size: 21,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Diagnóstico da falha',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: scheme.error,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '$jobName • $stepName',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 9),
              _DiagnosticSection(
                title: 'O que aconteceu',
                text: whatHappened,
              ),
              const SizedBox(height: 7),
              _DiagnosticSection(
                title: 'Onde aconteceu',
                text: 'Job: $jobName\n'
                    'Etapa: $stepName\n'
                    'Tentativa: ${widget.run.runAttempt}$stepTiming',
              ),
              const SizedBox(height: 7),
              _DiagnosticSection(
                title: 'GitHub informou',
                text: failure?.annotationMessage ??
                    (snapshot.connectionState == ConnectionState.waiting
                        ? 'Consultando annotations e logs do GitHub...'
                        : 'O GitHub não publicou uma annotation detalhada para esta falha.'),
              ),
              if (failure?.logHeadline != null) ...[
                const SizedBox(height: 7),
                _DiagnosticSection(
                  title: 'Leitura do GitHub Manager',
                  text:
                      'Linha mais relevante localizada automaticamente no log: ${failure!.logHeadline}',
                ),
              ],
              if (failure?.logContext.isNotEmpty == true) ...[
                const SizedBox(height: 7),
                Text(
                  'Contexto do log',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: scheme.surface.withValues(alpha: .52),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    failure!.logContext.join('\n'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          height: 1.3,
                        ),
                  ),
                ),
              ] else if (failure?.logUnavailableReason != null) ...[
                const SizedBox(height: 7),
                Text(
                  'Leitura automática do log indisponível: ${failure!.logUnavailableReason}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onErrorContainer,
                      ),
                ),
              ],
              if (failure != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _copyDiagnostic(failure, stepName),
                    icon: const Icon(Icons.copy_all_outlined, size: 18),
                    label: const Text('Copiar diagnóstico'),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _copyDiagnostic(
    RepositoryWorkflowFailure failure,
    String stepName,
  ) async {
    final run = widget.run;
    final lines = <String>[
      'GitHub Manager — diagnóstico de build',
      'Repositório: ${widget.repositoryFullName}',
      'Execução: ${run.name} #${run.runNumber}',
      'Status: ${_RepositoryActionsScreenState._statusLabel(run)}',
      if (run.detectedVersion != null) 'Versão: ${run.detectedVersion}',
      'Evento: ${run.event.isEmpty ? '-' : run.event}',
      'Branch: ${run.branch}',
      'Commit: ${run.shortSha.isEmpty ? '-' : run.shortSha}',
      'Tentativa: ${run.runAttempt}',
      'Criada: ${_RepositoryActionsScreenState._formatDate(run.createdAt)}',
      'Iniciada: ${_RepositoryActionsScreenState._formatDate(run.startedAt)}',
      'Finalizada: ${_RepositoryActionsScreenState._formatDate(run.updatedAt)}',
      'Job: ${failure.jobName}',
      'Etapa: $stepName',
      'GitHub informou: ${failure.annotationMessage ?? 'sem annotation detalhada'}',
      if (failure.logHeadline != null)
        'Linha relevante do log: ${failure.logHeadline}',
      if (failure.logContext.isNotEmpty) ...[
        'Contexto do log:',
        ...failure.logContext,
      ],
    ];
    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (mounted) {
      showCenteredNotice(context, 'Diagnóstico copiado.');
    }
  }
}

class _DiagnosticSection extends StatelessWidget {
  const _DiagnosticSection({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 2),
        Text(text, style: Theme.of(context).textTheme.bodySmall),
      ],
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
