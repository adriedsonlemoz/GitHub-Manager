part of 'repository_actions_screen.dart';

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
    final duration = _RepositoryActionsScreenState._formatSpan(
      run.startedAt ?? run.createdAt,
      run.isRunning ? null : run.updatedAt,
    );
    final stages = steps.isEmpty
        ? 'Aguardando dados do GitHub'
        : '${steps.length} total • $success ok${failed > 0 ? ' • $failed falha' : ''}${skipped > 0 ? ' • $skipped ignoradas' : ''}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resumo',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 9),
          LayoutBuilder(
            builder: (context, constraints) {
              final tileWidth = constraints.maxWidth >= 340
                  ? (constraints.maxWidth - 8) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: tileWidth,
                    child: _RunSummaryTile(
                      icon: Icons.bolt_rounded,
                      label: 'Evento',
                      value:
                          '${_eventLabel(run.event)} • tentativa ${run.runAttempt}',
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: _RunSummaryTile(
                      icon: Icons.account_tree_outlined,
                      label: 'Branch',
                      value: run.branch.trim().isEmpty ? '-' : run.branch,
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: _RunSummaryTile(
                      icon: Icons.timer_outlined,
                      label: 'Duração',
                      value: duration,
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: _RunSummaryTile(
                      icon: Icons.fact_check_outlined,
                      label: 'Etapas',
                      value: stages,
                    ),
                  ),
                ],
              );
            },
          ),
          if (run.commitMessage.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Mensagem do commit',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              run.commitMessage.trim(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          if (apkOutcome != null) ...[
            const SizedBox(height: 10),
            _RunOutcomeBanner(text: apkOutcome),
          ],
          const SizedBox(height: 6),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 2),
              leading: const Icon(Icons.tune_rounded, size: 20),
              title: Text(
                'Detalhes técnicos',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              subtitle: const Text('Execução, commit, horários e workflow'),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(10, 9, 10, 7),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(alpha: .45),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InfoLine(label: 'Execução', value: '#${run.runNumber}'),
                      if (run.detectedVersion != null)
                        _InfoLine(label: 'Versão', value: run.detectedVersion!),
                      _InfoLine(
                        label: 'Commit',
                        value: run.shortSha.isEmpty ? '-' : run.shortSha,
                      ),
                      _InfoLine(
                        label: 'Criada',
                        value: _RepositoryActionsScreenState._formatDate(
                          run.createdAt,
                        ),
                      ),
                      _InfoLine(
                        label: 'Iniciada',
                        value: _RepositoryActionsScreenState._formatDate(
                          run.startedAt,
                        ),
                      ),
                      _InfoLine(
                        label: 'Finalizada',
                        value: run.isRunning
                            ? 'Em andamento'
                            : _RepositoryActionsScreenState._formatDate(
                                run.updatedAt,
                              ),
                      ),
                      if (run.workflowPath.trim().isNotEmpty)
                        _InfoLine(
                          label: 'Workflow',
                          value: run.workflowPath,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
        return 'A falha aconteceu durante a compilação. O APK desta execução não foi concluído.';
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
        return 'O workflow falhou antes da compilação. Por isso, o APK não chegou a ser gerado.';
      }
      final built = steps.any(
        (step) =>
            _looksLikeApkBuildStep(step.name) && step.conclusion == 'success',
      );
      final publishSteps = steps.where((step) => _looksLikePublishStep(step.name));
      if (built && publishSteps.isNotEmpty) {
        final published = publishSteps.any((step) => step.conclusion == 'success');
        if (!published) {
          return 'O APK foi compilado, mas a etapa de publicação não terminou com sucesso.';
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

class _RunSummaryTile extends StatelessWidget {
  const _RunSummaryTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: .42),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RunOutcomeBanner extends StatelessWidget {
  const _RunOutcomeBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: .34),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.android_rounded, size: 19, color: scheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'APK não gerado',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: scheme.error,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 2),
                Text(text, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
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
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
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
            borderRadius: BorderRadius.circular(4),
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
                          'Falha identificada',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: scheme.error,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          stepName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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
              Text(
                whatHappened,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: scheme.surface.withValues(alpha: .35),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  failure?.annotationMessage ??
                      (snapshot.connectionState == ConnectionState.waiting
                          ? 'Consultando o diagnóstico publicado pelo GitHub...'
                          : 'O GitHub não publicou uma mensagem detalhada para esta falha.'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 2),
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.manage_search_rounded, size: 20),
                  title: Text(
                    'Detalhes do diagnóstico',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  subtitle: const Text('Job, horários e contexto do log'),
                  children: [
                    _DiagnosticSection(
                      title: 'Onde aconteceu',
                      text: 'Job: $jobName\n'
                          'Etapa: $stepName\n'
                          'Tentativa: ${widget.run.runAttempt}$stepTiming',
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
                          borderRadius: BorderRadius.circular(4),
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
                      const SizedBox(height: 6),
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
              ),
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
