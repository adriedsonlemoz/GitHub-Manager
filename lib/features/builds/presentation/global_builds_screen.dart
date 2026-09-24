import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:github_manager/core/widgets/app_main_navigation.dart';
import 'package:github_manager/features/builds/domain/global_build_entry.dart';
import 'package:github_manager/features/builds/presentation/build_providers.dart';
import 'package:go_router/go_router.dart';

enum _GlobalBuildFilter { all, running, success, failure }

class GlobalBuildsScreen extends ConsumerStatefulWidget {
  const GlobalBuildsScreen({super.key});

  @override
  ConsumerState<GlobalBuildsScreen> createState() => _GlobalBuildsScreenState();
}

class _GlobalBuildsScreenState extends ConsumerState<GlobalBuildsScreen> {
  _GlobalBuildFilter _filter = _GlobalBuildFilter.all;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _schedulePoll(const Duration(seconds: 15));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _schedulePoll(Duration delay) {
    _pollTimer?.cancel();
    _pollTimer = Timer(delay, () async {
      if (!mounted) return;
      try {
        await _refresh();
      } catch (_) {
        // Mantém a fotografia anterior; próxima tentativa continua agendada.
      }
      if (!mounted) return;
      final snapshot = ref.read(globalBuildsProvider).valueOrNull;
      _schedulePoll(
        (snapshot?.runningCount ?? 0) > 0
            ? const Duration(seconds: 6)
            : const Duration(seconds: 30),
      );
    });
  }

  Future<void> _refresh() async {
    ref.invalidate(globalBuildsProvider);
    await ref.read(globalBuildsProvider.future);
  }

  List<GlobalBuildEntry> _filtered(GlobalBuildsSnapshot snapshot) {
    return snapshot.entries.where((entry) {
      return switch (_filter) {
        _GlobalBuildFilter.all => true,
        _GlobalBuildFilter.running => entry.isRunning,
        _GlobalBuildFilter.success => entry.isSuccess,
        _GlobalBuildFilter.failure => entry.isFailure,
      };
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final builds = ref.watch(globalBuildsProvider);
    return Scaffold(
      bottomNavigationBar: const AppMainNavigation(selectedIndex: 1),
      appBar: AppBar(
        title: const Text('Builds'),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: builds.when(
          loading: () => ListView(
            physics: AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(height: 240),
              Center(child: CircularProgressIndicator()),
            ],
          ),
          error: (error, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Não foi possível reunir as builds agora.',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(error.toString()),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _refresh,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          data: (snapshot) {
            final entries = _filtered(snapshot);
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
              children: [
                _GlobalBuildSummary(snapshot: snapshot),
                const SizedBox(height: 10),
                SizedBox(
                  height: 42,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _FilterChip(
                        label: 'Todas',
                        selected: _filter == _GlobalBuildFilter.all,
                        onSelected: () => setState(() => _filter = _GlobalBuildFilter.all),
                      ),
                      _FilterChip(
                        label: 'Executando',
                        selected: _filter == _GlobalBuildFilter.running,
                        onSelected: () => setState(() => _filter = _GlobalBuildFilter.running),
                      ),
                      _FilterChip(
                        label: 'Sucesso',
                        selected: _filter == _GlobalBuildFilter.success,
                        onSelected: () => setState(() => _filter = _GlobalBuildFilter.success),
                      ),
                      _FilterChip(
                        label: 'Falhou',
                        selected: _filter == _GlobalBuildFilter.failure,
                        onSelected: () => setState(() => _filter = _GlobalBuildFilter.failure),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                if (entries.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'Nenhuma build encontrada para este filtro. Projetos sem workflow não aparecem aqui, porque não possuem execuções do GitHub Actions.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  ...entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _GlobalBuildCard(
                        entry: entry,
                        onTap: () => context.push(
                          '/repositories/${entry.repository.fullName}/builds?branch=${Uri.encodeQueryComponent(entry.branch)}&runId=${entry.run.id}',
                        ),
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
}

class _GlobalBuildSummary extends StatelessWidget {
  const _GlobalBuildSummary({required this.snapshot});

  final GlobalBuildsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Últimas builds de todos os projetos',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 5),
            Text(
              '${snapshot.repositoryCount} projetos verificados • '
              '${snapshot.repositoriesWithBuilds} com builds • '
              '${snapshot.entries.length} execuções recentes',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            if (snapshot.unavailableRepositories > 0) ...[
              const SizedBox(height: 5),
              Text(
                '${snapshot.unavailableRepositories} projetos não puderam consultar Actions nesta atualização.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
      ),
    );
  }
}

class _GlobalBuildCard extends StatelessWidget {
  const _GlobalBuildCard({required this.entry, required this.onTap});

  final GlobalBuildEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final run = entry.run;
    final scheme = Theme.of(context).colorScheme;
    final (icon, label) = _status(run.status, run.conclusion);
    final version = run.detectedVersion;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: scheme.surfaceContainerHighest,
                child: Icon(icon, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.repository.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${run.name} • #${run.runNumber}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${entry.branch}${version == null ? '' : ' • $version'} • ${_formatDate(entry.date)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static (IconData, String) _status(String status, String? conclusion) {
    if (status == 'queued' ||
        status == 'waiting' ||
        status == 'pending' ||
        status == 'requested') {
      return (Icons.schedule_rounded, 'Fila');
    }
    if (status == 'in_progress') {
      return (Icons.sync_rounded, 'Executando');
    }
    return switch (conclusion) {
      'success' => (Icons.check_circle_outline_rounded, 'Sucesso'),
      'cancelled' => (Icons.cancel_outlined, 'Cancelada'),
      'timed_out' => (Icons.timer_off_outlined, 'Tempo esgotado'),
      'skipped' => (Icons.skip_next_rounded, 'Ignorada'),
      'action_required' => (Icons.warning_amber_rounded, 'Ação necessária'),
      'startup_failure' => (Icons.error_outline_rounded, 'Falhou'),
      'stale' => (Icons.hourglass_disabled_rounded, 'Obsoleta'),
      'neutral' => (Icons.remove_circle_outline_rounded, 'Neutra'),
      'failure' => (Icons.error_outline_rounded, 'Falhou'),
      _ => conclusion == null
          ? (Icons.hourglass_top_rounded, 'Pendente')
          : (Icons.info_outline_rounded, 'Concluída'),
    };
  }

  static String _formatDate(DateTime? date) {
    if (date == null) return 'data indisponível';
    final local = date.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)} ${two(local.hour)}:${two(local.minute)}';
  }
}
