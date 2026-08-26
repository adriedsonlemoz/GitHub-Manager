import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:github_manager/core/errors/app_exception.dart';
import 'package:github_manager/features/downloads/presentation/download_center_button.dart';
import 'package:github_manager/features/downloads/presentation/download_providers.dart';
import 'package:github_manager/features/repositories/domain/repository_git_models.dart';
import 'package:github_manager/features/repositories/presentation/repository_providers.dart';
import 'package:go_router/go_router.dart';

class RepositoryActionsScreen extends ConsumerStatefulWidget {
  const RepositoryActionsScreen({
    required this.repositoryFullName,
    required this.defaultBranch,
    super.key,
  });

  final String repositoryFullName;
  final String defaultBranch;

  @override
  ConsumerState<RepositoryActionsScreen> createState() =>
      _RepositoryActionsScreenState();
}

class _RepositoryActionsScreenState
    extends ConsumerState<RepositoryActionsScreen> with WidgetsBindingObserver {
  late Future<List<RepositoryWorkflowRun>> _future;
  Timer? _timer;
  bool _hasRunning = false;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _future = _load();
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (_hasRunning && mounted) {
        _refresh(silent: true);
      }
    });
  }

  Future<List<RepositoryWorkflowRun>> _load() async {
    final runs = await ref
        .read(repositoryGitServiceProvider)
        .listWorkflowRuns(widget.repositoryFullName);
    _hasRunning = runs.any((run) => run.isRunning);
    return runs;
  }

  Future<void> _refresh({bool silent = false}) async {
    final future = _load();
    if (mounted) {
      setState(() => _future = future);
    }
    try {
      await future;
    } catch (_) {
      if (!silent) {
        rethrow;
      }
    }
  }

  Future<void> _runWorkflow() async {
    try {
      setState(() => _starting = true);
      final workflows = await ref
          .read(repositoryGitServiceProvider)
          .listWorkflows(widget.repositoryFullName);
      if (!mounted) {
        return;
      }
      final active = workflows.where((item) => item.isActive).toList();
      if (active.isEmpty) {
        throw const RepositoryFileException(
          'Nenhum workflow ativo foi encontrado neste repositório.',
          code: 'NO_ACTIVE_WORKFLOW',
        );
      }
      final selected = await showModalBottomSheet<RepositoryWorkflow>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                child: Text(
                  'Executar workflow',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              ...active.map(
                (workflow) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.play_arrow_rounded),
                    title: Text(workflow.name),
                    subtitle: Text(workflow.path),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.pop(context, workflow),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      if (selected == null || !mounted) {
        return;
      }
      await ref.read(repositoryGitServiceProvider).dispatchWorkflow(
            repositoryFullName: widget.repositoryFullName,
            workflow: selected,
            ref: widget.defaultBranch,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${selected.name} iniciado na branch ${widget.defaultBranch}.',
            ),
          ),
        );
        await Future<void>.delayed(const Duration(seconds: 2));
        await _refresh();
      }
    } catch (error) {
      if (mounted) {
        _showError(error);
      }
    } finally {
      if (mounted) {
        setState(() => _starting = false);
      }
    }
  }

  Future<void> _showRunDetails(RepositoryWorkflowRun run) async {
    if (!mounted) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _RunDetailsSheet(
        repositoryFullName: widget.repositoryFullName,
        run: run,
        onChanged: () => _refresh(silent: true),
        onOpenArtifacts: () {
          if (mounted) {
            context.push(
              '/repositories/${widget.repositoryFullName}/artifacts',
            );
          }
        },
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh(silent: true);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _showError(Object error) {
    final message = _message(error);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Builds'),
        actions: [
          IconButton(
            onPressed: () => _refresh(),
            tooltip: 'Atualizar',
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            onPressed: () => context.push(
              '/repositories/${widget.repositoryFullName}/artifacts',
            ),
            tooltip: 'APKs',
            icon: const Icon(Icons.android_rounded),
          ),
          const DownloadCenterButton(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _starting ? null : _runWorkflow,
        icon: _starting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.play_arrow_rounded),
        label: const Text('Executar build'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<RepositoryWorkflowRun>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 220),
                  Center(child: CircularProgressIndicator()),
                ],
              );
            }
            if (snapshot.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Text(_message(snapshot.error!)),
                    ),
                  ),
                ],
              );
            }
            final runs = snapshot.data ?? const <RepositoryWorkflowRun>[];
            if (runs.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: const [
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Text(
                        'Nenhuma execução encontrada. Use “Executar build” para iniciar um workflow com workflow_dispatch.',
                      ),
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
              itemCount: runs.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final run = runs[index];
                return Card(
                  child: ListTile(
                    onTap: () => _showRunDetails(run),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 5,
                    ),
                    leading: _RunStatusIcon(run: run),
                    title: Text(
                      run.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${run.name} #${run.runNumber}\n${run.branch} • ${_statusLabel(run)} • ${_formatDuration(run)}',
                    ),
                    isThreeLine: true,
                    trailing: run.isRunning
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chevron_right_rounded),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  String _message(Object error) {
    if (error is GitHubValidationException) {
      return 'O workflow não aceitou a execução manual. Confirme se ele possui workflow_dispatch.';
    }
    if (error is GitHubPermissionException) {
      return 'O token precisa da permissão Actions: write para executar, cancelar ou reexecutar builds.';
    }
    return error is AppException
        ? error.message
        : 'Não foi possível carregar as execuções.';
  }

  static String _statusLabel(RepositoryWorkflowRun run) {
    if (run.status != 'completed') {
      return switch (run.status) {
        'queued' => 'Na fila',
        'in_progress' => 'Compilando',
        'waiting' => 'Aguardando',
        _ => run.status,
      };
    }
    return switch (run.conclusion) {
      'success' => 'Sucesso',
      'failure' => 'Falhou',
      'cancelled' => 'Cancelada',
      'skipped' => 'Ignorada',
      _ => run.conclusion ?? 'Concluída',
    };
  }

  static String _formatDuration(RepositoryWorkflowRun run) {
    final start = run.createdAt;
    if (start == null) {
      return '-';
    }
    final end = run.isRunning ? DateTime.now() : run.updatedAt ?? DateTime.now();
    final duration = end.difference(start).abs();
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}min';
    }
    if (duration.inMinutes > 0) {
      return '${duration.inMinutes}min ${duration.inSeconds.remainder(60)}s';
    }
    return '${duration.inSeconds}s';
  }

  static String _jobStatus(RepositoryWorkflowJob job) {
    if (job.status != 'completed') {
      return switch (job.status) {
        'queued' => 'Na fila',
        'in_progress' => 'Em execução',
        'waiting' => 'Aguardando',
        _ => job.status,
      };
    }
    return switch (job.conclusion) {
      'success' => 'Concluído com sucesso',
      'failure' => 'Falhou',
      'cancelled' => 'Cancelado',
      'skipped' => 'Ignorado',
      _ => 'Concluído',
    };
  }

  static String _stepStatus(RepositoryWorkflowStep step) {
    if (step.status != 'completed') {
      return switch (step.status) {
        'queued' => 'Na fila',
        'in_progress' => 'Em andamento',
        'waiting' => 'Aguardando',
        _ => step.status,
      };
    }
    return switch (step.conclusion) {
      'success' => 'Concluída',
      'failure' => 'Falhou',
      'cancelled' => 'Cancelada',
      'skipped' => 'Ignorada',
      _ => 'Concluída',
    };
  }

  static String _stepExplanation(String name) {
    final value = name.toLowerCase();
    if (value.contains('checkout')) {
      return 'Baixando o código do repositório para o servidor de compilação.';
    }
    if (value.contains('java')) {
      return 'Preparando o Java necessário para compilar o aplicativo Android.';
    }
    if (value.contains('flutter')) {
      return 'Preparando o Flutter e as ferramentas usadas pelo projeto.';
    }
    if (value.contains('depend') || value.contains('pub get')) {
      return 'Baixando e conferindo as bibliotecas usadas pelo aplicativo.';
    }
    if (value.contains('analis') || value.contains('analyze')) {
      return 'Verificando o código em busca de erros antes da compilação.';
    }
    if (value.contains('test')) {
      return 'Executando testes automáticos do projeto.';
    }
    if (value.contains('gradle') || value.contains('wrapper')) {
      return 'Preparando o sistema de compilação do Android.';
    }
    if (value.contains('compil') ||
        value.contains('gerar apk') ||
        value.contains('build apk') ||
        value.contains('assemble')) {
      return 'Transformando o código em um APK instalável.';
    }
    if (value.contains('assin') || value.contains('sign')) {
      return 'Aplicando a assinatura necessária para instalar ou atualizar o APK.';
    }
    if (value.contains('valid')) {
      return 'Conferindo se a versão e o arquivo gerado estão corretos.';
    }
    if (value.contains('artifact') || value.contains('publicar') || value.contains('upload')) {
      return 'Publicando o resultado no GitHub para poder baixar depois.';
    }
    if (value.contains('prepar')) {
      return 'Organizando os arquivos necessários para a próxima etapa.';
    }
    return 'Etapa técnica executada pelo GitHub Actions.';
  }
}

class _RunDetailsSheet extends ConsumerStatefulWidget {
  const _RunDetailsSheet({
    required this.repositoryFullName,
    required this.run,
    required this.onChanged,
    required this.onOpenArtifacts,
  });

  final String repositoryFullName;
  final RepositoryWorkflowRun run;
  final VoidCallback onChanged;
  final VoidCallback onOpenArtifacts;

  @override
  ConsumerState<_RunDetailsSheet> createState() => _RunDetailsSheetState();
}

class _RunDetailsSheetState extends ConsumerState<_RunDetailsSheet> {
  late RepositoryWorkflowRun _run;
  late Future<List<RepositoryWorkflowJob>> _jobsFuture;
  Timer? _timer;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _run = widget.run;
    _jobsFuture = _loadJobs();
    _updateTimer();
  }

  Future<List<RepositoryWorkflowJob>> _loadJobs() => ref
      .read(repositoryGitServiceProvider)
      .listWorkflowRunJobs(
        repositoryFullName: widget.repositoryFullName,
        runId: _run.id,
      );

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

  void _downloadLogs() {
    ref.read(downloadManagerProvider).startWorkflowLogs(
          repositoryFullName: widget.repositoryFullName,
          runId: _run.id,
          runTitle: '${_run.name}-${_run.runNumber}',
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Download dos logs iniciado. Acompanhe pelo botão de Downloads.'),
        ),
      );
    }
  }

  void _showError(Object error) {
    final message = error is GitHubPermissionException
        ? 'O token precisa de Actions: write para controlar builds.'
        : error is AppException
            ? error.message
            : 'Não foi possível atualizar esta execução.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
      initialChildSize: .76,
      minChildSize: .48,
      maxChildSize: .94,
      builder: (context, scrollController) => FutureBuilder<
          List<RepositoryWorkflowJob>>(
        future: _jobsFuture,
        builder: (context, snapshot) {
          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _run.title,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_run.name} #${_run.runNumber} • ${_run.branch}',
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _refresh(),
                    tooltip: 'Atualizar etapas',
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: _RunStatusIcon(run: _run),
                  title: Text(_RepositoryActionsScreenState._statusLabel(_run)),
                  subtitle: Text(
                    _run.isRunning
                        ? 'Atualização automática a cada 6 segundos'
                        : 'Duração: ${_RepositoryActionsScreenState._formatDuration(_run)}',
                  ),
                  trailing: _run.isRunning
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              if (snapshot.connectionState == ConnectionState.waiting)
                const LinearProgressIndicator()
              else if (snapshot.hasError)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    snapshot.error is AppException
                        ? (snapshot.error! as AppException).message
                        : 'Não foi possível carregar jobs e etapas.',
                  ),
                )
              else if ((snapshot.data ?? const <RepositoryWorkflowJob>[]).isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Os jobs ainda não foram publicados pelo GitHub.'),
                  ),
                )
              else
                ...(snapshot.data ?? const <RepositoryWorkflowJob>[]).map(
                  (job) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      child: ExpansionTile(
                        leading: _JobIcon(job: job),
                        title: Text(job.name),
                        subtitle: Text(
                          _RepositoryActionsScreenState._jobStatus(job),
                        ),
                        initiallyExpanded: job.status != 'completed',
                        children: job.steps
                            .map(
                              (step) => ListTile(
                                dense: true,
                                leading: _StepIcon(step: step),
                                title: Text(step.name),
                                subtitle: Text(
                                  '${_RepositoryActionsScreenState._stepExplanation(step.name)}\nStatus: ${_RepositoryActionsScreenState._stepStatus(step)}',
                                ),
                                isThreeLine: true,
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _working ? null : _downloadLogs,
                    icon: const Icon(Icons.download_for_offline_outlined),
                    label: const Text('Baixar logs'),
                  ),
                  if (_run.isRunning)
                    OutlinedButton.icon(
                      onPressed: _working ? null : _cancel,
                      icon: const Icon(Icons.stop_circle_outlined),
                      label: Text(_working ? 'Cancelando...' : 'Cancelar build'),
                    )
                  else ...[
                    OutlinedButton.icon(
                      onPressed: _working ? null : _rerun,
                      icon: const Icon(Icons.replay_rounded),
                      label: const Text('Reexecutar'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onOpenArtifacts();
                      },
                      icon: const Icon(Icons.android_rounded),
                      label: const Text('Baixar APK'),
                    ),
                  ],
                ],
              ),
            ],
          );
        },
      ),
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
        : const Icon(Icons.error_outline_rounded);
  }
}

class _StepIcon extends StatelessWidget {
  const _StepIcon({required this.step});

  final RepositoryWorkflowStep step;

  @override
  Widget build(BuildContext context) {
    if (step.status != 'completed') {
      return const Icon(Icons.radio_button_unchecked_rounded, size: 18);
    }
    if (step.conclusion == 'success') {
      return const Icon(Icons.check_rounded, size: 18);
    }
    if (step.conclusion == 'skipped') {
      return const Icon(Icons.remove_rounded, size: 18);
    }
    return const Icon(Icons.close_rounded, size: 18);
  }
}
