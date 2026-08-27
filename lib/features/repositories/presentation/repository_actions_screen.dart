import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:github_manager/core/errors/app_exception.dart';
import 'package:github_manager/core/widgets/centered_notice.dart';
import 'package:github_manager/features/downloads/presentation/download_center_button.dart';
import 'package:github_manager/features/downloads/presentation/download_providers.dart';
import 'package:github_manager/features/repositories/domain/repository_git_models.dart';
import 'package:github_manager/features/repositories/presentation/repository_providers.dart';
import 'package:github_manager/features/uploads/presentation/upload_center_button.dart';
import 'package:go_router/go_router.dart';

class RepositoryActionsScreen extends ConsumerStatefulWidget {
  const RepositoryActionsScreen({
    required this.repositoryFullName,
    required this.defaultBranch,
    this.readOnly = false,
    super.key,
  });

  final String repositoryFullName;
  final String defaultBranch;
  final bool readOnly;

  @override
  ConsumerState<RepositoryActionsScreen> createState() =>
      _RepositoryActionsScreenState();
}

class _RepositoryActionsScreenState extends ConsumerState<RepositoryActionsScreen>
    with WidgetsBindingObserver {
  late Future<RepositoryActionsData> _future;
  RepositoryWorkflow? _selectedWorkflow;
  Timer? _timer;
  bool _hasRunning = false;
  bool _starting = false;
  bool _showDiagnostics = false;
  RepositoryActionsData? _currentData;
  final Set<int> _selectedRunIds = <int>{};
  bool _selectionMode = false;
  bool _deletingSelected = false;

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

  Future<RepositoryActionsData> _load() async {
    final data = await ref.read(repositoryGitServiceProvider).loadActions(
          widget.repositoryFullName,
          workflow: _selectedWorkflow,
        );
    _hasRunning = data.allRuns.any((run) => run.isRunning);
    _currentData = data;
    return data;
  }

  Future<void> _refresh({bool silent = false}) async {
    try {
      final data = await _load();
      if (mounted) {
        setState(() => _future = Future<RepositoryActionsData>.value(data));
      }
    } catch (_) {
      if (!silent) {
        rethrow;
      }
    }
  }

  void _selectWorkflow(RepositoryWorkflow? workflow) {
    setState(() {
      _selectedRunIds.clear();
      _selectionMode = false;
      _selectedWorkflow = workflow;
      _future = _load();
    });
  }

  void _clearRunSelection() {
    setState(() {
      _selectedRunIds.clear();
      _selectionMode = false;
    });
  }

  void _toggleRunSelection(RepositoryWorkflowRun run) {
    if (widget.readOnly || run.isRunning) return;
    setState(() {
      _selectionMode = true;
      if (!_selectedRunIds.add(run.id)) {
        _selectedRunIds.remove(run.id);
      }
      if (_selectedRunIds.isEmpty) {
        _selectionMode = false;
      }
    });
  }

  void _selectAllVisibleRuns({bool failedOnly = false}) {
    final data = _currentData;
    if (data == null || widget.readOnly) return;
    final candidates = data.runs.where(
      (run) =>
          !run.isRunning &&
          (!failedOnly || run.conclusion == 'failure'),
    );
    setState(() {
      _selectionMode = true;
      _selectedRunIds
        ..clear()
        ..addAll(candidates.map((run) => run.id));
      if (_selectedRunIds.isEmpty) {
        _selectionMode = false;
      }
    });
  }

  Future<void> _deleteSelectedRuns() async {
    if (_selectedRunIds.isEmpty || widget.readOnly || _deletingSelected) return;
    final count = _selectedRunIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Excluir $count execução(ões)?'),
        content: const Text(
          'As execuções selecionadas serão removidas permanentemente do GitHub Actions. '
          'Artifacts ligados a essas execuções também podem ser removidos pelo GitHub. '
          'Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_forever_outlined),
            label: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deletingSelected = true);
    try {
      final deleted = await ref
          .read(repositoryGitServiceProvider)
          .deleteWorkflowRuns(
            repositoryFullName: widget.repositoryFullName,
            runIds: _selectedRunIds,
          );
      if (!mounted) return;
      _clearRunSelection();
      await _refresh(silent: true);
      if (mounted) {
        showCenteredNotice(context, '$deleted execução(ões) excluída(s) permanentemente.');
      }
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) {
        setState(() => _deletingSelected = false);
      }
    }
  }

  Future<void> _runWorkflow() async {
    try {
      setState(() => _starting = true);
      final service = ref.read(repositoryGitServiceProvider);
      final workflows = await service.listWorkflows(widget.repositoryFullName);
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

      final supportsDispatch = await service.workflowSupportsDispatch(
        repositoryFullName: widget.repositoryFullName,
        branch: widget.defaultBranch,
        workflow: selected,
      );
      if (!supportsDispatch) {
        throw RepositoryFileException(
          '${selected.name} não possui workflow_dispatch e não pode ser iniciado manualmente.',
          code: 'WORKFLOW_DISPATCH_UNAVAILABLE',
        );
      }

      await service.dispatchWorkflow(
        repositoryFullName: widget.repositoryFullName,
        workflow: selected,
        ref: widget.defaultBranch,
      );
      if (mounted) {
        showCenteredNotice(context, '${selected.name} iniciado na branch ${widget.defaultBranch}.');
        _selectedWorkflow = selected;
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
        readOnly: widget.readOnly,
        onOpenArtifacts: () {
          if (mounted) {
            context.push('/repositories/${widget.repositoryFullName}/artifacts?readOnly=${widget.readOnly ? '1' : '0'}');
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
    showCenteredNotice(context, _message(error));
  }

  @override
  Widget build(BuildContext context) {
    final screenTitle = _selectedWorkflow == null
        ? 'Builds'
        : 'Execuções — ${_selectedWorkflow!.name}';
    return Scaffold(
      appBar: AppBar(
        leading: _selectionMode
            ? IconButton(
                onPressed: _clearRunSelection,
                tooltip: 'Cancelar seleção',
                icon: const Icon(Icons.close_rounded),
              )
            : null,
        title: Text(
          _selectionMode
              ? '${_selectedRunIds.length} selecionada(s)'
              : screenTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (_selectionMode && !widget.readOnly) ...[
            IconButton(
              onPressed: () => _selectAllVisibleRuns(failedOnly: true),
              tooltip: 'Selecionar falhas',
              icon: const Icon(Icons.error_outline_rounded),
            ),
            IconButton(
              onPressed: () => _selectAllVisibleRuns(),
              tooltip: 'Selecionar todas',
              icon: const Icon(Icons.select_all_rounded),
            ),
            IconButton(
              onPressed: _selectedRunIds.isEmpty || _deletingSelected
                  ? null
                  : _deleteSelectedRuns,
              tooltip: 'Excluir selecionadas',
              icon: _deletingSelected
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_forever_outlined),
            ),
          ] else ...[
            if (!widget.readOnly)
              IconButton(
                onPressed: () => setState(() => _selectionMode = true),
                tooltip: 'Selecionar execuções',
                icon: const Icon(Icons.checklist_rounded),
              ),
            IconButton(
              onPressed: () => setState(() => _showDiagnostics = !_showDiagnostics),
              tooltip: 'Diagnóstico da API',
              icon: const Icon(Icons.monitor_heart_outlined),
            ),
            IconButton(
              onPressed: () => _refresh(),
              tooltip: 'Atualizar',
              icon: const Icon(Icons.refresh_rounded),
            ),
            IconButton(
              onPressed: () => context.push(
                '/repositories/${widget.repositoryFullName}/artifacts?readOnly=${widget.readOnly ? '1' : '0'}',
              ),
              tooltip: 'APKs e artifacts',
              icon: const Icon(Icons.android_rounded),
            ),
            const UploadCenterButton(),
            const DownloadCenterButton(),
          ],
        ],
      ),
      floatingActionButton: widget.readOnly || _selectionMode
          ? null
          : FloatingActionButton.extended(
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
        child: FutureBuilder<RepositoryActionsData>(
          future: _future,
          builder: (context, snapshot) {
            final retained = snapshot.data ?? _currentData;
            if (snapshot.connectionState == ConnectionState.waiting && retained == null) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 220),
                  Center(child: CircularProgressIndicator()),
                ],
              );
            }
            if (snapshot.hasError && retained == null) {
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

            final data = retained!;
            final runs = data.runs;
            final runGroups = _groupRuns(runs);
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 104),
              children: [
                _WorkflowsPanel(
                  data: data,
                  selectedWorkflow: _selectedWorkflow,
                  onSelected: _selectWorkflow,
                ),
                if (_showDiagnostics || runs.isEmpty) ...[
                  const SizedBox(height: 10),
                  _ActionsDiagnosticCard(diagnostic: data.diagnostic),
                ],
                const SizedBox(height: 16),
                Text(
                  data.selectedWorkflow == null
                      ? 'Todas as execuções'
                      : 'Execuções — ${data.selectedWorkflow!.name}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                if (runs.isEmpty)
                  _EmptyRunsCard(diagnostic: data.diagnostic)
                else
                  ...runGroups.map(
                    (group) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _RunGroupCard(
                        group: group,
                        selectionMode: _selectionMode,
                        selectedRunIds: _selectedRunIds,
                        onRunTap: _selectionMode
                            ? _toggleRunSelection
                            : _showRunDetails,
                        onRunLongPress: _toggleRunSelection,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  static List<_RunGroup> _groupRuns(List<RepositoryWorkflowRun> runs) {
    final grouped = <String, List<RepositoryWorkflowRun>>{};
    for (final run in runs) {
      final hasSha = run.headSha.trim().isNotEmpty;
      final key = run.event == 'push' && hasSha
          ? 'push:${run.headSha}'
          : 'run:${run.id}';
      grouped.putIfAbsent(key, () => <RepositoryWorkflowRun>[]).add(run);
    }

    final groups = grouped.values.map((items) {
      items.sort((a, b) {
        final aDate = a.createdAt ?? a.startedAt;
        final bDate = b.createdAt ?? b.startedAt;
        if (aDate == null && bDate == null) {
          return b.id.compareTo(a.id);
        }
        if (aDate == null) {
          return 1;
        }
        if (bDate == null) {
          return -1;
        }
        return bDate.compareTo(aDate);
      });
      return _RunGroup(List<RepositoryWorkflowRun>.unmodifiable(items));
    }).toList();

    groups.sort((a, b) {
      final aDate = a.latestAt;
      final bDate = b.latestAt;
      if (aDate == null && bDate == null) {
        return b.primary.id.compareTo(a.primary.id);
      }
      if (aDate == null) {
        return 1;
      }
      if (bDate == null) {
        return -1;
      }
      return bDate.compareTo(aDate);
    });

    return List<_RunGroup>.unmodifiable(groups);
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
        'in_progress' => 'Em andamento',
        'waiting' => 'Aguardando',
        'pending' => 'Pendente',
        _ => run.status,
      };
    }
    return switch (run.conclusion) {
      'success' => 'Sucesso',
      'failure' => 'Falhou',
      'cancelled' => 'Cancelada',
      'skipped' => 'Ignorada',
      'timed_out' => 'Tempo esgotado',
      'action_required' => 'Ação necessária',
      _ => run.conclusion ?? 'Concluída',
    };
  }

  static String _formatDuration(RepositoryWorkflowRun run) {
    final start = run.startedAt ?? run.createdAt;
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

  static String _formatDate(DateTime? value) {
    if (value == null) {
      return 'data -';
    }
    final date = value.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} '
        '${two(date.hour)}:${two(date.minute)}:${two(date.second)}';
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
      return 'Baixando os arquivos do projeto.';
    }
    if (value.contains('java')) {
      return 'Preparando o Java necessário para compilar o aplicativo Android.';
    }
    if (value.contains('flutter')) {
      return 'Preparando o Flutter para compilar o aplicativo.';
    }
    if (value.contains('depend') || value.contains('pub get')) {
      return 'Baixando as bibliotecas necessárias.';
    }
    if (value.contains('analis') || value.contains('analyze')) {
      return 'Verificando o código em busca de erros.';
    }
    if (value.contains('test')) {
      return 'Executando os testes automáticos.';
    }
    if (value.contains('gradle') || value.contains('wrapper')) {
      return 'Preparando o sistema de compilação do Android.';
    }
    if (value.contains('compil') ||
        value.contains('gerar apk') ||
        value.contains('build apk') ||
        value.contains('assemble')) {
      return 'Compilando o aplicativo Android.';
    }
    if (value.contains('assin') || value.contains('sign')) {
      return 'Assinando o APK.';
    }
    if (value.contains('artifact') ||
        value.contains('publicar') ||
        value.contains('upload')) {
      return 'Enviando o APK ou resultado para o GitHub.';
    }
    if (value.contains('valid')) {
      return 'Conferindo se os arquivos e configurações estão corretos.';
    }
    return 'Etapa técnica executada pelo GitHub Actions.';
  }
}

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
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
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
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      if (group.runs.first.detectedVersion != null) ...[
                        const SizedBox(height: 3),
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
                      const SizedBox(height: 3),
                      Text(
                        '$sha • ${group.eventLabel} • ${group.runs.length} ${group.runs.length == 1 ? 'workflow' : 'workflows'}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
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
    final isSuccess =
        run.status == 'completed' && run.conclusion == 'success';
    final isFailure =
        run.status == 'completed' && run.conclusion == 'failure';
    final successColor = Colors.green.shade700;
    final failureColor = Colors.red.shade700;
    final foreground = isSuccess
        ? Colors.white
        : isFailure
            ? failureColor
            : Theme.of(context).colorScheme.onSurface;
    final background = isSuccess
        ? successColor
        : isFailure
            ? Colors.white
            : Colors.transparent;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: isFailure
            ? Border.all(color: failureColor, width: 1.5)
            : null,
      ),
      child: ListTile(
        onTap: onTap,
        onLongPress: onLongPress,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
        leading: selectionMode
            ? Checkbox(
                value: selected,
                onChanged: run.isRunning ? null : (_) => onTap(),
                side: BorderSide(color: foreground),
                checkColor: isSuccess ? successColor : Colors.white,
                activeColor: isFailure ? failureColor : Theme.of(context).colorScheme.primary,
              )
            : Icon(
                run.isRunning
                    ? Icons.sync_rounded
                    : isSuccess
                        ? Icons.check_circle_rounded
                        : isFailure
                            ? Icons.error_rounded
                            : Icons.schedule_rounded,
                color: foreground,
              ),
        title: Text(
          '${run.name} #${run.runNumber}',
          style: TextStyle(
            color: foreground,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          '${run.detectedVersion == null ? '' : 'Versão ${run.detectedVersion} • '}'
          '${_RepositoryActionsScreenState._formatDate(run.createdAt)} • '
          'Tentativa ${run.runAttempt} • ${run.branch}\n'
          '${_RepositoryActionsScreenState._statusLabel(run)} • '
          '${_RepositoryActionsScreenState._formatDuration(run)}',
          style: TextStyle(color: foreground),
        ),
        isThreeLine: true,
        trailing: selectionMode
            ? run.isRunning
                ? Tooltip(
                    message: 'Execução em andamento não pode ser excluída',
                    child: Icon(Icons.lock_clock_outlined, color: foreground),
                  )
                : null
            : run.isRunning
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: foreground,
                    ),
                  )
                : Icon(Icons.chevron_right_rounded, color: foreground),
      ),
    );
  }
}

class _WorkflowStepTile extends StatelessWidget {
  const _WorkflowStepTile({required this.step});

  final RepositoryWorkflowStep step;

  @override
  Widget build(BuildContext context) {
    final isSuccess =
        step.status == 'completed' && step.conclusion == 'success';
    final isFailure =
        step.status == 'completed' && step.conclusion == 'failure';
    final successColor = Colors.green.shade700;
    final failureColor = Colors.red.shade700;
    final foreground = isSuccess
        ? Colors.white
        : isFailure
            ? failureColor
            : Theme.of(context).colorScheme.onSurface;
    final background = isSuccess
        ? successColor
        : isFailure
            ? Colors.white
            : Theme.of(context).colorScheme.surfaceContainerLow;

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 4, 10, 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
        border: isFailure
            ? Border.all(color: failureColor, width: 1.5)
            : null,
      ),
      child: ListTile(
        dense: true,
        leading: Icon(
          step.status != 'completed'
              ? Icons.radio_button_unchecked_rounded
              : isSuccess
                  ? Icons.check_rounded
                  : isFailure
                      ? Icons.close_rounded
                      : Icons.remove_rounded,
          size: 19,
          color: foreground,
        ),
        title: Text(
          step.name,
          style: TextStyle(
            color: foreground,
            fontWeight: isFailure ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
        subtitle: Text(
          '${_RepositoryActionsScreenState._stepExplanation(step.name)}\n'
          'Status: ${_RepositoryActionsScreenState._stepStatus(step)}',
          style: TextStyle(color: foreground),
        ),
        isThreeLine: true,
      ),
    );
  }
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
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Workflows (${data.workflows.length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                Text('${data.allRuns.length} runs recebidos'),
              ],
            ),
            const SizedBox(height: 8),
            _WorkflowTile(
              selected: selectedWorkflow == null,
              icon: Icons.all_inclusive_rounded,
              title: 'Todas as execuções',
              subtitle: '${data.allRuns.length} execuções recentes',
              onTap: () => onSelected(null),
            ),
            ...data.workflows.map((workflow) {
              final latest = data.latestFor(workflow);
              final status = latest == null
                  ? 'Sem execução no histórico carregado'
                  : '${_RepositoryActionsScreenState._statusLabel(latest)} • #${latest.runNumber}';
              return _WorkflowTile(
                selected: selectedWorkflow?.id == workflow.id,
                icon: workflow.isActive
                    ? Icons.check_circle_outline_rounded
                    : Icons.pause_circle_outline_rounded,
                title: workflow.name,
                subtitle:
                    '${workflow.isActive ? 'Ativo' : workflow.state} • ${data.countFor(workflow)} runs\n${workflow.path}\nÚltimo: $status',
                onTap: () => onSelected(workflow),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _WorkflowTile extends StatelessWidget {
  const _WorkflowTile({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      selected: selected,
      selectedTileColor: Theme.of(context).colorScheme.secondaryContainer.withAlpha(115),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      isThreeLine: subtitle.contains('\n'),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
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
      initialChildSize: .78,
      minChildSize: .48,
      maxChildSize: .95,
      builder: (context, scrollController) => FutureBuilder<
          List<RepositoryWorkflowJob>>(
        future: _jobsFuture,
        builder: (context, snapshot) {
          final jobs = snapshot.data ?? _currentJobs ?? const <RepositoryWorkflowJob>[];
          RepositoryWorkflowJob? failedJob;
          for (final job in jobs) {
            if (job.failed) {
              failedJob = job;
              break;
            }
          }
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
                          '${_run.name} #${_run.runNumber} • ${_run.branch} • ${_run.shortSha}',
                        ),
                        if (_run.detectedVersion != null) ...[
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              const Icon(Icons.new_releases_outlined, size: 16),
                              const SizedBox(width: 5),
                              Text(
                                'Versão ${_run.detectedVersion}',
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ],
                          ),
                        ],
                        if (_run.commitMessage.trim().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            _run.commitMessage.split('\n').first,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                        const SizedBox(height: 2),
                        Text(
                          'Início: ${_RepositoryActionsScreenState._formatDate(_run.startedAt ?? _run.createdAt)}',
                          style: Theme.of(context).textTheme.bodySmall,
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
              const SizedBox(height: 10),
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
                const SizedBox(height: 10),
                _FailureSummaryCard(
                  repositoryFullName: widget.repositoryFullName,
                  job: failedJob,
                ),
              ],
              const SizedBox(height: 12),
              if (snapshot.connectionState == ConnectionState.waiting && jobs.isEmpty)
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
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Os jobs ainda não foram publicados pelo GitHub.'),
                  ),
                )
              else
                ...jobs.map(
                  (job) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      child: ExpansionTile(
                        leading: _JobIcon(job: job),
                        title: Text(job.name),
                        subtitle: Text(
                          _RepositoryActionsScreenState._jobStatus(job),
                        ),
                        initiallyExpanded: job.status != 'completed' || job.failed,
                        children: job.steps
                            .map(
                              (step) => _WorkflowStepTile(step: step),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 10),

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
        Icon(icon, size: 20),
        const SizedBox(height: 3),
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
      height: 58,
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
        final errorColor = Colors.red.shade700;
        return Card(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: errorColor, width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Erro principal',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: errorColor,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Job: ${failure?.jobName ?? job.name}',
                  style: TextStyle(color: errorColor, fontWeight: FontWeight.w700),
                ),
                Text(
                  'Etapa: ${failure?.stepName ?? failedStep ?? '-'}',
                  style: TextStyle(color: errorColor, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  failure?.message ??
                      (snapshot.connectionState == ConnectionState.waiting
                          ? 'Buscando a mensagem principal do erro no GitHub...'
                          : 'O GitHub não forneceu uma annotation detalhada para esta falha.'),
                  style: TextStyle(color: errorColor),
                ),
              ],
            ),
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
