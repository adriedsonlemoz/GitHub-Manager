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

class _FailureSummaryCard extends StatelessWidget {
  const _FailureSummaryCard({
    required this.repositoryFullName,
    required this.run,
    required this.jobs,
  });

  final String repositoryFullName;
  final RepositoryWorkflowRun run;
  final List<RepositoryWorkflowJob> jobs;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final count = jobs.length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(11, 10, 9, 10),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: .42),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: scheme.error, size: 21),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count ${count == 1 ? 'erro encontrado' : 'erros encontrados'}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: scheme.error,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  count == 1
                      ? 'Veja o que aconteceu, a possível causa e como corrigir.'
                      : 'Abra a análise e navegue por cada falha separadamente.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => _FailureDetailsDialog(
                repositoryFullName: repositoryFullName,
                run: run,
                jobs: jobs,
              ),
            ),
            icon: const Icon(Icons.manage_search_rounded, size: 18),
            label: const Text('Ver erros'),
          ),
        ],
      ),
    );
  }
}

class _FailureDetailsDialog extends ConsumerStatefulWidget {
  const _FailureDetailsDialog({
    required this.repositoryFullName,
    required this.run,
    required this.jobs,
  });

  final String repositoryFullName;
  final RepositoryWorkflowRun run;
  final List<RepositoryWorkflowJob> jobs;

  @override
  ConsumerState<_FailureDetailsDialog> createState() => _FailureDetailsDialogState();
}

class _FailureDetailsDialogState extends ConsumerState<_FailureDetailsDialog> {
  final Map<int, Future<RepositoryWorkflowFailure?>> _futures = {};
  int _index = 0;

  Future<RepositoryWorkflowFailure?> _futureFor(RepositoryWorkflowJob job) =>
      _futures.putIfAbsent(
        job.id,
        () => ref.read(repositoryGitServiceProvider).loadWorkflowFailure(
              repositoryFullName: widget.repositoryFullName,
              runId: widget.run.id,
              job: job,
            ),
      );

  @override
  Widget build(BuildContext context) {
    final job = widget.jobs[_index];
    final total = widget.jobs.length;
    final scheme = Theme.of(context).colorScheme;
    final media = MediaQuery.sizeOf(context);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 18),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 720,
          maxHeight: media.height * .88,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded, color: scheme.error),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Erros do Build',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        Text(
                          'Erro ${_index + 1} de $total • ${widget.run.name} #${widget.run.runNumber}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Fechar',
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: FutureBuilder<RepositoryWorkflowFailure?>(
                future: _futureFor(job),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final failure = snapshot.data;
                  final explanation = _BuildFailureExplanation.fromFailure(
                    failure,
                    job: job,
                  );
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                    children: [
                      _ErrorExplanationSection(
                        title: 'O que aconteceu',
                        icon: Icons.info_outline_rounded,
                        text: explanation.whatHappened,
                      ),
                      const SizedBox(height: 12),
                      if (failure?.location != null) ...[
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Arquivo identificado',
                                    style: TextStyle(fontWeight: FontWeight.w800)),
                                const SizedBox(height: 5),
                                SelectableText(failure!.location!.path),
                                Text(
                                  '${failure.location!.line == null ? 'Linha não fornecida' : 'Linha ${failure.location!.line}'} • ${failure.location!.confirmed ? 'Confirmado pela annotation' : 'Detectado no log (verificar)'}',
                                ),
                                if (failure.location!.githubUrl(widget.repositoryFullName, widget.run.headSha) != null)
                                  TextButton.icon(
                                    onPressed: () async {
                                      final uri = failure.location!.githubUrl(
                                          widget.repositoryFullName, widget.run.headSha)!;
                                      try {
                                        await PlatformActions.openUri(uri);
                                      } catch (_) {
                                        if (context.mounted) showCenteredNotice(context,
                                            'Não foi possível abrir o arquivo no GitHub.');
                                      }
                                    },
                                    icon: const Icon(Icons.open_in_new_rounded),
                                    label: const Text('Ver arquivo no commit'),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      _ErrorExplanationSection(
                        title: 'Onde aconteceu',
                        icon: Icons.location_on_outlined,
                        text: explanation.whereHappened,
                      ),
                      const SizedBox(height: 12),
                      _ErrorExplanationSection(
                        title: explanation.causeIdentified
                            ? 'Causa identificada'
                            : 'Possível causa',
                        icon: explanation.causeIdentified
                            ? Icons.verified_outlined
                            : Icons.help_outline_rounded,
                        text: explanation.cause,
                        emphasized: explanation.causeIdentified,
                      ),
                      const SizedBox(height: 12),
                      _ErrorExplanationSection(
                        title: 'Como corrigir',
                        icon: Icons.build_outlined,
                        text: explanation.fix,
                      ),
                      const SizedBox(height: 10),
                      Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          childrenPadding: const EdgeInsets.only(bottom: 8),
                          leading: const Icon(Icons.code_rounded, size: 20),
                          title: const Text(
                            'Detalhes técnicos',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                          subtitle: const Text('Mensagem original e contexto do log'),
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: SelectableText(
                                explanation.technicalDetails,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      fontFamily: 'monospace',
                                      height: 1.35,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _copyError(explanation),
                            icon: const Icon(Icons.copy_rounded, size: 18),
                            label: const Text('Copiar erro'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _copyDiagnostic(explanation),
                            icon: const Icon(Icons.copy_all_outlined, size: 18),
                            label: const Text('Copiar diagnóstico'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _downloadLogs,
                            icon: const Icon(Icons.download_for_offline_outlined, size: 18),
                            label: const Text('Logs completos'),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
            if (total > 1) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 7, 10, 9),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: _index == 0
                            ? null
                            : () => setState(() => _index--),
                        icon: const Icon(Icons.chevron_left_rounded),
                        label: const Text('Anterior'),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '${_index + 1}/$total',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    Expanded(
                      child: TextButton.icon(
                        onPressed: _index >= total - 1
                            ? null
                            : () => setState(() => _index++),
                        icon: const Icon(Icons.chevron_right_rounded),
                        label: const Text('Próximo'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _copyError(_BuildFailureExplanation explanation) async {
    await Clipboard.setData(ClipboardData(text: explanation.rawError));
    if (mounted) showCenteredNotice(context, 'Erro copiado.');
  }

  Future<void> _copyDiagnostic(_BuildFailureExplanation explanation) async {
    final run = widget.run;
    final text = <String>[
      'GitHub Manager — diagnóstico de build',
      'Repositório: ${widget.repositoryFullName}',
      'Execução: ${run.name} #${run.runNumber}',
      if (run.detectedVersion != null) 'Versão: ${run.detectedVersion}',
      'Branch: ${run.branch}',
      'Commit: ${run.shortSha}',
      '',
      'O que aconteceu: ${explanation.whatHappened}',
      'Onde aconteceu: ${explanation.whereHappened}',
      '${explanation.causeIdentified ? 'Causa identificada' : 'Possível causa'}: ${explanation.cause}',
      'Como corrigir: ${explanation.fix}',
      '',
      'Detalhes técnicos:',
      explanation.technicalDetails,
    ].join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) showCenteredNotice(context, 'Diagnóstico copiado.');
  }

  void _downloadLogs() {
    ref.read(downloadManagerProvider).startWorkflowLogs(
          repositoryFullName: widget.repositoryFullName,
          runId: widget.run.id,
          runTitle: '${widget.run.name}-${widget.run.runNumber}',
        );
    showCenteredNotice(
      context,
      'Download dos logs completos iniciado. Acompanhe pela Central de Downloads.',
    );
  }
}

class _ErrorExplanationSection extends StatelessWidget {
  const _ErrorExplanationSection({
    required this.title,
    required this.icon,
    required this.text,
    this.emphasized = false,
  });

  final String title;
  final IconData icon;
  final String text;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: emphasized
            ? scheme.primaryContainer.withValues(alpha: .38)
            : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: emphasized ? scheme.primary : scheme.onSurfaceVariant),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(text),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BuildFailureExplanation {
  const _BuildFailureExplanation({
    required this.whatHappened,
    required this.whereHappened,
    required this.cause,
    required this.fix,
    required this.causeIdentified,
    required this.technicalDetails,
    required this.rawError,
  });

  final String whatHappened;
  final String whereHappened;
  final String cause;
  final String fix;
  final bool causeIdentified;
  final String technicalDetails;
  final String rawError;

  factory _BuildFailureExplanation.fromFailure(
    RepositoryWorkflowFailure? failure, {
    required RepositoryWorkflowJob job,
  }) {
    RepositoryWorkflowStep? failedStep;
    for (final step in job.steps) {
      if (step.failed) {
        failedStep = step;
        break;
      }
    }
    final stepName = failure?.stepName ?? failedStep?.name ?? 'Etapa não identificada';
    final message = failure?.message.trim().isNotEmpty == true
        ? failure!.message.trim()
        : 'O GitHub marcou esta etapa como falha, mas não publicou uma mensagem detalhada.';
    final technical = <String>[
      'Job: ${failure?.jobName ?? job.name}',
      'Etapa: $stepName',
      if (failure?.location != null) 'Arquivo: ${failure!.location!.path}:${failure.location!.line ?? '?'} (${failure.location!.source})',
      if (failure?.annotationMessage?.trim().isNotEmpty == true)
        'GitHub: ${failure!.annotationMessage!.trim()}',
      if (failure?.logHeadline?.trim().isNotEmpty == true)
        'Linha relevante: ${failure!.logHeadline!.trim()}',
      if (failure?.logContext.isNotEmpty == true) ...[
        '',
        'Contexto do log:',
        ...failure!.logContext,
      ],
      if (failure?.logUnavailableReason?.trim().isNotEmpty == true)
        'Leitura automática do log indisponível: ${failure!.logUnavailableReason}',
    ].join('\n');
    final corpus = <String>[
      message,
      failure?.annotationMessage ?? '',
      failure?.logHeadline ?? '',
      ...?failure?.logContext,
    ].join('\n').toLowerCase();
    final logCorpus = <String>[
      failure?.logHeadline ?? '',
      ...?failure?.logContext,
    ].join('\n').toLowerCase();
    final provenByLog = failure?.logsInspected == true &&
        failure?.logHeadline?.trim().isNotEmpty == true;

    String cause;
    String fix;
    var strongSignature = false;
    if (corpus.contains('no space left on device')) {
      strongSignature = true;
      cause = 'O ambiente de build ficou sem espaço em disco durante a execução.';
      fix = 'Reduza arquivos gerados/cache do workflow ou libere espaço antes de compilar novamente.';
    } else if (corpus.contains('keystore') &&
        (corpus.contains('not found') ||
            corpus.contains('does not exist') ||
            corpus.contains('failed to read key') ||
            corpus.contains('password was incorrect'))) {
      strongSignature = true;
      cause = 'A assinatura Android não conseguiu acessar corretamente o keystore ou suas credenciais.';
      fix = 'Confira o arquivo de keystore, alias e secrets de senha usados no workflow. Verifique também se o arquivo é criado no caminho esperado antes do Gradle.';
    } else if (corpus.contains('manifest merger failed')) {
      strongSignature = true;
      cause = 'O Android não conseguiu combinar os manifests do aplicativo e das dependências.';
      fix = 'Abra as linhas logo abaixo de “Manifest merger failed” e ajuste o atributo, permissão ou componente que entrou em conflito.';
    } else if (corpus.contains('requires compilesdk') ||
        (corpus.contains('compilesdk') && corpus.contains('at least'))) {
      strongSignature = true;
      cause = 'Uma dependência exige um compileSdk mais novo do que o configurado no projeto.';
      fix = 'Aumente o compileSdk para a versão mínima indicada no log e confirme a compatibilidade do Android Gradle Plugin/Gradle.';
    } else if (corpus.contains('uses-sdk:minsdkversion') ||
        corpus.contains('minsdkversion') && corpus.contains('cannot be smaller')) {
      strongSignature = true;
      cause = 'Uma dependência exige uma versão mínima do Android maior do que o minSdk atual.';
      fix = 'Ajuste o minSdk se isso for aceitável ou use uma versão da dependência compatível com o minSdk do projeto.';
    } else if (corpus.contains('could not resolve') ||
        corpus.contains('failed to resolve') ||
        corpus.contains('could not find ')) {
      strongSignature = true;
      cause = 'O sistema de build não conseguiu localizar ou baixar uma dependência necessária.';
      fix = 'Confira o nome/versão da dependência, os repositórios configurados e se a execução tem acesso à internet ou a credenciais privadas necessárias.';
    } else if (corpus.contains('unresolved reference') ||
        corpus.contains('cannot find symbol') ||
        corpus.contains("isn't defined") ||
        corpus.contains('undefined name')) {
      strongSignature = true;
      cause = 'O compilador encontrou uma referência de código que não existe ou não está acessível.';
      fix = 'Abra o arquivo e a linha indicados no log e corrija o nome, import, classe, método ou variável ausente.';
    } else if ((corpus.contains('aapt2') && corpus.contains('error')) ||
        corpus.contains('resource linking failed') ||
        corpus.contains('resource not found')) {
      strongSignature = true;
      cause = 'A etapa de recursos Android falhou ao compilar ou localizar um recurso.';
      fix = 'Confira o recurso citado no log, incluindo XML, drawable, string, tema ou referência inexistente, e execute o build novamente.';
    } else if (corpus.contains('permission denied')) {
      strongSignature = true;
      cause = 'Uma etapa tentou acessar ou executar um arquivo sem permissão suficiente.';
      fix = 'Confira permissões do arquivo/script e, no workflow, garanta chmod adequado antes de executá-lo.';
    } else {
      cause = message;
      fix = 'Use os detalhes técnicos para localizar a primeira mensagem específica de erro. Se ela apontar um arquivo ou etapa, corrija esse ponto e execute o workflow novamente.';
    }

    final identified = provenByLog &&
        strongSignature &&
        _containsStrongFailureSignature(logCorpus);
    return _BuildFailureExplanation(
      whatHappened: 'A execução falhou no job “${failure?.jobName ?? job.name}”, durante a etapa “$stepName”.',
      whereHappened: 'Job: ${failure?.jobName ?? job.name}\nEtapa: $stepName${failure?.location == null ? '' : '\nArquivo: ${failure!.location!.path}:${failure.location!.line ?? '?'}'}${failedStep == null ? '' : '\nDuração: ${_RepositoryActionsScreenState._formatSpan(failedStep.startedAt, failedStep.completedAt)}'}',
      cause: cause,
      fix: fix,
      causeIdentified: identified,
      technicalDetails: technical,
      rawError: message,
    );
  }

  static bool _containsStrongFailureSignature(String corpus) {
    if (corpus.contains('no space left on device')) return true;
    if (corpus.contains('keystore') &&
        (corpus.contains('not found') ||
            corpus.contains('does not exist') ||
            corpus.contains('failed to read key') ||
            corpus.contains('password was incorrect'))) {
      return true;
    }
    if (corpus.contains('manifest merger failed')) return true;
    if (corpus.contains('requires compilesdk') ||
        (corpus.contains('compilesdk') && corpus.contains('at least'))) {
      return true;
    }
    if (corpus.contains('uses-sdk:minsdkversion') ||
        (corpus.contains('minsdkversion') &&
            corpus.contains('cannot be smaller'))) {
      return true;
    }
    if (corpus.contains('could not resolve') ||
        corpus.contains('failed to resolve') ||
        corpus.contains('could not find ')) {
      return true;
    }
    if (corpus.contains('unresolved reference') ||
        corpus.contains('cannot find symbol') ||
        corpus.contains("isn't defined") ||
        corpus.contains('undefined name')) {
      return true;
    }
    if ((corpus.contains('aapt2') && corpus.contains('error')) ||
        corpus.contains('resource linking failed') ||
        corpus.contains('resource not found')) {
      return true;
    }
    return corpus.contains('permission denied');
  }
}

class _RunApkCandidate {
  const _RunApkCandidate._({this.release, this.artifact});

  factory _RunApkCandidate.fromRelease(ReleaseAsset asset) =>
      _RunApkCandidate._(release: asset);
  factory _RunApkCandidate.fromArtifact(ActionArtifact artifact) =>
      _RunApkCandidate._(artifact: artifact);

  final ReleaseAsset? release;
  final ActionArtifact? artifact;

  String get name => release?.name ?? artifact!.name;
  int get sizeBytes => release?.sizeBytes ?? artifact!.sizeBytes;
  ApkVariantInfo get variant => ApkVariantInfo.fromName(name);
  String originLabel(int runNumber) => release != null
      ? 'Release ${release!.tagName}'
      : 'Artifact da execução #$runNumber';
}

class _RunApkPickerSheet extends StatelessWidget {
  const _RunApkPickerSheet({
    required this.run,
    required this.candidates,
    required this.deviceInfo,
    required this.recommendedName,
  });

  final RepositoryWorkflowRun run;
  final List<_RunApkCandidate> candidates;
  final AndroidDeviceInfo? deviceInfo;
  final String? recommendedName;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final version = run.detectedVersion;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'APKs disponíveis',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 3),
          Text(
            '${version == null ? '' : 'v$version • '}execução #${run.runNumber}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          if (deviceInfo != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: .35),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Seu aparelho: ${deviceInfo!.primaryAbi} • ${deviceInfo!.supports64Bit ? 'suporta 64 bits' : '32 bits'}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 520),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: candidates.length,
              separatorBuilder: (_, __) => const SizedBox(height: 7),
              itemBuilder: (context, index) {
                final candidate = candidates[index];
                final recommended = candidate.name == recommendedName;
                final compatible = deviceInfo == null ||
                    apkNameIsCompatible(candidate.name, deviceInfo!.supportedAbis);
                return Material(
                  color: recommended
                      ? scheme.primaryContainer.withValues(alpha: .30)
                      : scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(4),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: () => Navigator.pop(context, candidate),
                    child: Padding(
                      padding: const EdgeInsets.all(11),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            compatible ? Icons.android_rounded : Icons.warning_amber_rounded,
                            color: compatible ? scheme.primary : scheme.error,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        candidate.variant.label,
                                        style: const TextStyle(fontWeight: FontWeight.w900),
                                      ),
                                    ),
                                    if (recommended)
                                      const Chip(
                                        visualDensity: VisualDensity.compact,
                                        label: Text('Recomendado'),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  candidate.variant.description,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${candidate.name} • ${_formatApkBytes(candidate.sizeBytes)} • ${candidate.originLabel(run.runNumber)}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                if (!compatible) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Não corresponde às arquiteturas informadas por este aparelho.',
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                          color: scheme.error,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

String _formatApkBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
  final mb = kb / 1024;
  return '${mb.toStringAsFixed(1)} MB';
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
