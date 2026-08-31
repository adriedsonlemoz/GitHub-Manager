import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:github_manager/core/background/build_monitor_service.dart';
import 'package:github_manager/core/errors/app_exception.dart';
import 'package:github_manager/core/widgets/app_main_navigation.dart';
import 'package:github_manager/core/widgets/centered_notice.dart';
import 'package:github_manager/features/downloads/presentation/download_center_button.dart';
import 'package:github_manager/features/downloads/presentation/download_providers.dart';
import 'package:github_manager/features/repositories/domain/repository_git_models.dart';
import 'package:github_manager/features/repositories/presentation/repository_providers.dart';
import 'package:github_manager/features/uploads/presentation/upload_center_button.dart';
import 'package:go_router/go_router.dart';

part 'repository_actions_widgets.dart';
part 'repository_run_details.dart';

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
  bool _refreshing = false;
  DateTime? _lastUpdatedAt;
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
    unawaited(BuildMonitorService.watchRepository(widget.repositoryFullName));
    _future = _load();
    _future.then<void>(
      (_) {
        if (mounted) _scheduleAutoRefresh();
      },
      onError: (_) {
        if (mounted) _scheduleAutoRefresh();
      },
    );
  }

  Future<RepositoryActionsData> _load() async {
    final data = await ref.read(repositoryGitServiceProvider).loadActions(
          widget.repositoryFullName,
          workflow: _selectedWorkflow,
        );
    _hasRunning = data.allRuns.any((run) => run.isRunning);
    _currentData = data;
    _lastUpdatedAt = DateTime.now();
    return data;
  }

  Future<void> _refresh({
    bool silent = false,
    bool lightweight = false,
  }) async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final data = lightweight ? await _pollRecentRuns() : await _load();
      if (mounted) {
        setState(() => _future = Future<RepositoryActionsData>.value(data));
      }
    } catch (_) {
      if (!silent) {
        rethrow;
      }
    } finally {
      _refreshing = false;
      if (mounted) _scheduleAutoRefresh();
    }
  }

  Future<RepositoryActionsData> _pollRecentRuns() async {
    final current = _currentData;
    if (current == null) return _load();
    if (_selectedWorkflow != null &&
        current.diagnostic.reason == 'fallback_workflow_especifico') {
      return _load();
    }
    final recent = await ref
        .read(repositoryGitServiceProvider)
        .listRecentWorkflowRuns(widget.repositoryFullName);
    final previousById = <int, RepositoryWorkflowRun>{
      for (final run in current.allRuns) run.id: run,
    };
    final allRuns = recent.map((run) {
      final previousVersion = previousById[run.id]?.buildVersion;
      if (run.buildVersion == null && previousVersion != null) {
        return run.withBuildVersion(previousVersion);
      }
      return run;
    }).toList(growable: false)
      ..sort((a, b) {
        final aDate = a.createdAt ?? a.startedAt;
        final bDate = b.createdAt ?? b.startedAt;
        if (aDate == null && bDate == null) return b.id.compareTo(a.id);
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });
    final selected = _selectedWorkflow;
    final visibleRuns = selected == null
        ? allRuns
        : allRuns.where((run) => run.belongsTo(selected)).toList(growable: false);
    final oldDiagnostic = current.diagnostic;
    final data = RepositoryActionsData(
      workflows: current.workflows,
      allRuns: List<RepositoryWorkflowRun>.unmodifiable(allRuns),
      runs: List<RepositoryWorkflowRun>.unmodifiable(visibleRuns),
      selectedWorkflow: selected,
      diagnostic: RepositoryActionsDiagnostic(
        endpoint: oldDiagnostic.endpoint,
        httpStatus: oldDiagnostic.httpStatus,
        repositoryRunsReceived: allRuns.length,
        runsAfterFilter: visibleRuns.length,
        totalCountReported: oldDiagnostic.totalCountReported,
        reason: oldDiagnostic.reason,
        workflowId: selected?.id,
        workflowName: selected?.name,
        workflowPath: selected?.path,
        workflowState: selected?.state,
        fallbackEndpoint: oldDiagnostic.fallbackEndpoint,
        fallbackHttpStatus: oldDiagnostic.fallbackHttpStatus,
        fallbackRunsReceived: oldDiagnostic.fallbackRunsReceived,
      ),
    );
    _hasRunning = allRuns.any((run) => run.isRunning);
    final availableIds = allRuns.map((run) => run.id).toSet();
    _selectedRunIds.removeWhere((id) => !availableIds.contains(id));
    _selectionMode = _selectedRunIds.isNotEmpty;
    _currentData = data;
    _lastUpdatedAt = DateTime.now();
    return data;
  }

  void _scheduleAutoRefresh() {
    _timer?.cancel();
    if (!mounted) return;
    final interval = _hasRunning
        ? const Duration(seconds: 6)
        : const Duration(seconds: 15);
    _timer = Timer(interval, () {
      if (mounted) unawaited(_refresh(silent: true, lightweight: true));
    });
  }

  void _selectWorkflow(RepositoryWorkflow? workflow) {
    _timer?.cancel();
    _selectedWorkflow = workflow;
    final next = _load();
    setState(() {
      _selectedRunIds.clear();
      _selectionMode = false;
      _future = next;
    });
    next.then<void>(
      (_) {
        if (mounted) _scheduleAutoRefresh();
      },
      onError: (_) {
        if (mounted) _scheduleAutoRefresh();
      },
    );
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

  void _handleRunLongPress(RepositoryWorkflowRun run) {
    if (widget.readOnly) return;
    if (!_selectionMode) {
      final hasFailures = (_currentData?.runs ?? const <RepositoryWorkflowRun>[])
          .any((item) => !item.isRunning && item.conclusion == 'failure');
      if (hasFailures) {
        _selectAllVisibleRuns(failedOnly: true);
        return;
      }
    }
    if (run.isRunning) return;
    _toggleRunSelection(run);
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
    final selectedRuns = (_currentData?.runs ?? const <RepositoryWorkflowRun>[])
        .where((run) => _selectedRunIds.contains(run.id))
        .toList(growable: false);
    final failuresOnly = selectedRuns.length == count &&
        selectedRuns.every((run) => run.conclusion == 'failure');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          failuresOnly
              ? 'Excluir $count build(s) com falha?'
              : 'Excluir $count execução(ões)?',
        ),
        content: Text(
          failuresOnly
              ? 'Somente as execuções que falharam serão removidas permanentemente do GitHub Actions. '
                  'As execuções concluídas com sucesso serão mantidas. Artifacts ligados às falhas também podem ser removidos pelo GitHub. '
                  'Esta ação não pode ser desfeita.'
              : 'As execuções selecionadas serão removidas permanentemente do GitHub Actions. '
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
      final result = await ref
          .read(repositoryGitServiceProvider)
          .deleteWorkflowRuns(
            repositoryFullName: widget.repositoryFullName,
            runIds: _selectedRunIds,
          );
      if (!mounted) return;
      setState(() {
        _selectedRunIds
          ..clear()
          ..addAll(result.failedIds);
        _selectionMode = _selectedRunIds.isNotEmpty;
      });
      await _refresh(silent: true);
      if (!mounted) return;
      if (result.hasFailures) {
        showCenteredNotice(
          context,
          '${result.deletedCount} excluída(s) • ${result.failedCount} não puderam ser excluída(s). As falhas restantes continuam selecionadas.',
        );
      } else {
        showCenteredNotice(
          context,
          '${result.deletedCount} execução(ões) excluída(s) permanentemente.',
        );
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
      useSafeArea: true,
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
      bottomNavigationBar: const AppMainNavigation(selectedIndex: 0),
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
              ? _selectionTitle()
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
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.checklist_rounded, size: 21),
              ),
            const UploadCenterButton(),
            const DownloadCenterButton(),
          ],
        ],
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
                if (!widget.readOnly && !_selectionMode) ...[
                  _ActionsQuickBar(
                    starting: _starting,
                    onRun: _runWorkflow,
                    onRefresh: () => _refresh(),
                    onArtifacts: () => context.push(
                      '/repositories/${widget.repositoryFullName}/artifacts?readOnly=${widget.readOnly ? '1' : '0'}',
                    ),
                    onDiagnostics: () => setState(() => _showDiagnostics = !_showDiagnostics),
                    onPermissions: () => context.push(
                      '/repositories/${widget.repositoryFullName}/permissions',
                    ),
                  ),
                  const SizedBox(height: 7),
                ],
                _WorkflowsPanel(
                  data: data,
                  selectedWorkflow: _selectedWorkflow,
                  onSelected: _selectWorkflow,
                ),
                if (_showDiagnostics || runs.isEmpty) ...[
                  const SizedBox(height: 7),
                  _ActionsDiagnosticCard(diagnostic: data.diagnostic),
                ],
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        data.selectedWorkflow == null
                            ? 'Todas as execuções'
                            : 'Execuções — ${data.selectedWorkflow!.name}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _refreshStatusLabel(),
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
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
                        onRunLongPress: _handleRunLongPress,
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

  String _selectionTitle() {
    final runs = _currentData?.runs ?? const <RepositoryWorkflowRun>[];
    final selected = runs.where((run) => _selectedRunIds.contains(run.id));
    final failures = selected.where((run) => run.conclusion == 'failure').length;
    if (failures == _selectedRunIds.length && failures > 0) {
      return '$failures falha(s) selecionada(s)';
    }
    return '${_selectedRunIds.length} selecionada(s)';
  }

  String _refreshStatusLabel() {
    final updated = _lastUpdatedAt;
    final cadence = _hasRunning ? '6 s' : '15 s';
    if (updated == null) return 'Atualizando • auto $cadence';
    final seconds = DateTime.now().difference(updated).inSeconds.abs();
    final when = seconds < 5
        ? 'Atualizado agora'
        : seconds < 60
            ? 'há ${seconds}s'
            : 'há ${seconds ~/ 60}min';
    return '$when • auto $cadence';
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

  static String _formatCompactDate(DateTime? value) {
    if (value == null) return 'sem data';
    final date = value.toLocal();
    const months = <String>[
      'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
      'jul', 'ago', 'set', 'out', 'nov', 'dez',
    ];
    String two(int value) => value.toString().padLeft(2, '0');
    final year = (date.year % 100).toString().padLeft(2, '0');
    return '${date.day} ${months[date.month - 1]} $year • ${two(date.hour)}:${two(date.minute)}';
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

  static String _formatSpan(DateTime? start, DateTime? end) {
    if (start == null) return '-';
    final effectiveEnd = end ?? DateTime.now();
    final duration = effectiveEnd.difference(start).abs();
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
    if (value.contains('set up job') || value.contains('setup job')) {
      return 'Preparando a máquina e o ambiente onde o workflow será executado.';
    }
    if (value.contains('complete job') ||
        value.contains('post job') ||
        value.contains('cleanup')) {
      return 'Finalizando o job e limpando recursos temporários.';
    }
    if (value.contains('checkout')) {
      return 'Baixando os arquivos do projeto para a máquina do GitHub Actions.';
    }
    if (value.contains('cache')) {
      return 'Restaurando ou salvando arquivos reutilizáveis para acelerar a build.';
    }
    if (value.contains('versão') || value.contains('version')) {
      return 'Lendo e conferindo a versão usada por esta execução.';
    }
    if (value.contains('ícone') || value.contains('icon')) {
      return 'Conferindo os recursos de ícone exigidos pelo aplicativo Android.';
    }
    if (value.contains('plataforma android') ||
        (value.contains('android') && value.contains('platform'))) {
      return 'Conferindo se a estrutura Android necessária está presente e versionada.';
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
