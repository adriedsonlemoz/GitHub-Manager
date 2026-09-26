import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:github_manager/core/platform/platform_actions.dart';
import 'package:github_manager/core/widgets/app_main_navigation.dart';
import 'package:github_manager/core/widgets/centered_notice.dart';
import 'package:github_manager/features/builds/domain/action_artifact.dart';
import 'package:github_manager/features/builds/domain/apk_variant.dart';
import 'package:github_manager/features/builds/domain/release_asset.dart';
import 'package:github_manager/features/builds/domain/global_build_entry.dart';
import 'package:github_manager/features/builds/presentation/build_providers.dart';
import 'package:github_manager/features/downloads/presentation/download_providers.dart';
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
    _schedulePoll();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _schedulePoll() {
    _pollTimer?.cancel();
    _pollTimer = Timer(const Duration(seconds: 6), () async {
      if (!mounted) return;
      try {
        await _refresh();
      } catch (_) {
        // Mantém o último snapshot válido. O próximo ciclo tenta novamente.
      }
      if (mounted) _schedulePoll();
    });
  }

  Future<void> _refresh({bool forceFull = false}) async {
    if (forceFull) {
      ref.read(globalBuildsServiceProvider).invalidate();
    }
    ref.invalidate(globalBuildsProvider);
    await ref.read(globalBuildsProvider.future);
  }

  List<GlobalRepositoryBuildGroup> _filtered(GlobalBuildsSnapshot snapshot) {
    return snapshot.groups.where((group) {
      return switch (_filter) {
        _GlobalBuildFilter.all => true,
        _GlobalBuildFilter.running => group.isRunning,
        _GlobalBuildFilter.success => group.isSuccess,
        _GlobalBuildFilter.failure => group.isFailure,
      };
    }).toList(growable: false);
  }

  Future<void> _downloadLogs(GlobalBuildEntry entry) async {
    ref.read(downloadManagerProvider).startWorkflowLogs(
          repositoryFullName: entry.repository.fullName,
          runId: entry.run.id,
          runTitle: '${entry.run.name}-${entry.run.runNumber}',
        );
    if (mounted) {
      showCenteredNotice(
        context,
        'Download dos logs iniciado. Acompanhe pela Central de Downloads.',
      );
    }
  }

  Future<void> _downloadApk(GlobalBuildEntry entry) async {
    try {
      final artifactService = ref.read(artifactServiceProvider);
      final artifactsFuture = artifactService.listArtifactsForRun(
        repositoryFullName: entry.repository.fullName,
        runId: entry.run.id,
      );
      final releasesFuture = artifactService.findReleaseApksForBuild(
        repositoryFullName: entry.repository.fullName,
        run: entry.run,
      );

      AndroidDeviceInfo? deviceInfo;
      try {
        deviceInfo = await PlatformActions.getAndroidDeviceInfo();
      } catch (_) {
        deviceInfo = null;
      }

      final artifacts = (await artifactsFuture)
          .where((artifact) => !artifact.expired && artifact.likelyContainsApk)
          .toList(growable: false);
      final releases = (await releasesFuture)
          .where((asset) => asset.isApk)
          .toList(growable: false);

      final candidates = <_GlobalApkCandidate>[
        ...releases.map(_GlobalApkCandidate.fromRelease),
      ];
      final releaseVariants = releases
          .map((asset) => ApkVariantInfo.fromName(asset.name).shortLabel)
          .toSet();
      for (final artifact in artifacts) {
        final variant = ApkVariantInfo.fromName(artifact.name).shortLabel;
        if (!releaseVariants.contains(variant)) {
          candidates.add(_GlobalApkCandidate.fromArtifact(artifact));
        }
      }

      if (!mounted) return;
      if (candidates.isEmpty) {
        showCenteredNotice(
          context,
          entry.run.isRunning
              ? 'O APK ainda não está disponível. A build continua em execução.'
              : 'Nenhum APK disponível foi encontrado para esta build.',
        );
        return;
      }

      final supportedAbis = deviceInfo?.supportedAbis ?? const <String>[];
      candidates.sort((left, right) {
        final leftRank = apkRecommendationRank(left.name, supportedAbis);
        final rightRank = apkRecommendationRank(right.name, supportedAbis);
        if (leftRank != rightRank) return leftRank.compareTo(rightRank);
        if (left.release != null && right.release == null) return -1;
        if (left.release == null && right.release != null) return 1;
        return left.name.toLowerCase().compareTo(right.name.toLowerCase());
      });

      _GlobalApkCandidate? selected;
      if (candidates.length == 1) {
        selected = candidates.first;
      } else {
        final bestRank = apkRecommendationRank(candidates.first.name, supportedAbis);
        final recommendedName = bestRank < 100 ? candidates.first.name : null;
        selected = await showModalBottomSheet<_GlobalApkCandidate>(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (sheetContext) => _GlobalApkPickerSheet(
            entry: entry,
            candidates: candidates,
            deviceInfo: deviceInfo,
            recommendedName: recommendedName,
          ),
        );
      }
      if (selected == null || !mounted) return;
      if (!await _confirmGlobalApkCompatibility(selected, deviceInfo)) return;
      _startGlobalApkDownload(entry, selected, deviceInfo);
    } catch (_) {
      if (mounted) {
        showCenteredNotice(
          context,
          'Não foi possível localizar os APKs desta build agora.',
        );
      }
    }
  }

  Future<bool> _confirmGlobalApkCompatibility(
    _GlobalApkCandidate candidate,
    AndroidDeviceInfo? deviceInfo,
  ) async {
    if (deviceInfo == null ||
        apkNameIsCompatible(candidate.name, deviceInfo.supportedAbis)) {
      return true;
    }
    final variant = ApkVariantInfo.fromName(candidate.name);
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('APK possivelmente incompatível'),
            content: Text(
              'Este APK é ${variant.label}, mas este aparelho usa ${deviceInfo.primaryAbi} como arquitetura principal e suporta ${deviceInfo.supportedAbis.join(', ')}. Ele provavelmente não poderá ser instalado.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Baixar mesmo assim'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _startGlobalApkDownload(
    GlobalBuildEntry entry,
    _GlobalApkCandidate candidate,
    AndroidDeviceInfo? deviceInfo,
  ) {
    final manager = ref.read(downloadManagerProvider);
    final release = candidate.release;
    final artifact = candidate.artifact;
    if (release != null) {
      manager.startReleaseAsset(
        title: '${release.tagName} • ${release.name}',
        fileName: release.name,
        repositoryFullName: entry.repository.fullName,
        assetId: release.id,
        isApk: true,
      );
    } else if (artifact != null) {
      manager.startArtifactApk(
        repositoryFullName: entry.repository.fullName,
        artifact: artifact,
        preferredAbi: deviceInfo?.primaryAbi,
        supportedAbis: deviceInfo?.supportedAbis,
      );
    }
    showCenteredNotice(
      context,
      'Download de ${candidate.variant.label} iniciado. Acompanhe pela Central de Downloads.',
      kind: CenteredNoticeKind.success,
    );
  }

  void _openRun(GlobalBuildEntry entry, {BuildContext? sheetContext}) {
    if (sheetContext != null) {
      Navigator.of(sheetContext).pop();
    }
    context.push(
      '/repositories/${entry.repository.fullName}/builds?branch=${Uri.encodeQueryComponent(entry.branch)}&runId=${entry.run.id}',
    );
  }

  Future<void> _showRepositoryBuilds(GlobalRepositoryBuildGroup group) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.78,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.repository.name,
                        style: Theme.of(sheetContext)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${group.buildCount} build${group.buildCount == 1 ? '' : 's'} da versão/commit mais recente • ${group.branch}',
                        style: Theme.of(sheetContext).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
                    itemCount: group.entries.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final entry = group.entries[index];
                      return _RepositoryBuildRunCard(
                        entry: entry,
                        onOpen: () => _openRun(entry, sheetContext: sheetContext),
                        onDownloadLogs: () => _downloadLogs(entry),
                        onDownloadApk: () => _downloadApk(entry),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
            tooltip: 'Atualizar todos os repositórios',
            onPressed: () => _refresh(forceFull: true),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _refresh(forceFull: true),
        child: builds.when(
          loading: () => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
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
                        onPressed: () => _refresh(forceFull: true),
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
            final groups = _filtered(snapshot);
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
                        label: 'Todos',
                        selected: _filter == _GlobalBuildFilter.all,
                        onSelected: () =>
                            setState(() => _filter = _GlobalBuildFilter.all),
                      ),
                      _FilterChip(
                        label: 'Executando',
                        selected: _filter == _GlobalBuildFilter.running,
                        onSelected: () =>
                            setState(() => _filter = _GlobalBuildFilter.running),
                      ),
                      _FilterChip(
                        label: 'Sucesso',
                        selected: _filter == _GlobalBuildFilter.success,
                        onSelected: () =>
                            setState(() => _filter = _GlobalBuildFilter.success),
                      ),
                      _FilterChip(
                        label: 'Falhou',
                        selected: _filter == _GlobalBuildFilter.failure,
                        onSelected: () =>
                            setState(() => _filter = _GlobalBuildFilter.failure),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                if (groups.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'Nenhum repositório com build encontrado para este filtro. Projetos sem workflow não aparecem aqui.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  ...groups.map(
                    (group) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _GlobalRepositoryBuildCard(
                        group: group,
                        onTap: () => _showRepositoryBuilds(group),
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
              'Última build de cada projeto',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 5),
            Text(
              '${snapshot.repositoryCount} projetos verificados • '
              '${snapshot.repositoriesWithBuilds} com builds • '
              'atualização automática a cada 6 s',
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

class _GlobalRepositoryBuildCard extends StatelessWidget {
  const _GlobalRepositoryBuildCard({
    required this.group,
    required this.onTap,
  });

  final GlobalRepositoryBuildGroup group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = _groupStatus(group);
    final version = group.version;
    final count = group.buildCount;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('repository-build-${group.repository.fullName}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: scheme.surfaceContainerHighest,
                child: Icon(status.$1, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.repository.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$count build${count == 1 ? '' : 's'} na versão mais recente',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${group.branch}${version == null ? '' : ' • $version'} • ${_formatDate(group.date)}',
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
              _StatusPill(label: status.$2),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlobalApkCandidate {
  const _GlobalApkCandidate._({this.release, this.artifact});

  factory _GlobalApkCandidate.fromRelease(ReleaseAsset asset) =>
      _GlobalApkCandidate._(release: asset);

  factory _GlobalApkCandidate.fromArtifact(ActionArtifact artifact) =>
      _GlobalApkCandidate._(artifact: artifact);

  final ReleaseAsset? release;
  final ActionArtifact? artifact;

  String get name => release?.name ?? artifact!.name;
  int get sizeBytes => release?.sizeBytes ?? artifact!.sizeBytes;
  ApkVariantInfo get variant => ApkVariantInfo.fromName(name);

  String originLabel(int runNumber) => release != null
      ? 'Release ${release!.tagName}'
      : 'Artifact da execução #$runNumber';
}

class _GlobalApkPickerSheet extends StatelessWidget {
  const _GlobalApkPickerSheet({
    required this.entry,
    required this.candidates,
    required this.deviceInfo,
    required this.recommendedName,
  });

  final GlobalBuildEntry entry;
  final List<_GlobalApkCandidate> candidates;
  final AndroidDeviceInfo? deviceInfo;
  final String? recommendedName;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final version = entry.run.detectedVersion;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'APKs disponíveis',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 3),
          Text(
            '${version == null ? '' : 'v$version • '}execução #${entry.run.runNumber}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          if (deviceInfo != null) ...[
            const SizedBox(height: 8),
            Text(
              'Seu aparelho: ${deviceInfo!.primaryAbi} • ${deviceInfo!.supports64Bit ? 'suporta 64 bits' : '32 bits'}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 520),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: candidates.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final candidate = candidates[index];
                final recommended = candidate.name == recommendedName;
                final compatible = deviceInfo == null ||
                    apkNameIsCompatible(
                      candidate.name,
                      deviceInfo!.supportedAbis,
                    );
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    compatible
                        ? Icons.android_rounded
                        : Icons.warning_amber_rounded,
                    color: compatible ? scheme.primary : scheme.error,
                  ),
                  title: Row(
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
                  subtitle: Text(
                    '${candidate.variant.description}\n${candidate.name} • ${_globalApkBytes(candidate.sizeBytes)} • ${candidate.originLabel(entry.run.runNumber)}',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.pop(context, candidate),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

String _globalApkBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
  return '${(kb / 1024).toStringAsFixed(1)} MB';
}

class _RepositoryBuildRunCard extends StatelessWidget {
  const _RepositoryBuildRunCard({
    required this.entry,
    required this.onOpen,
    required this.onDownloadLogs,
    required this.onDownloadApk,
  });

  final GlobalBuildEntry entry;
  final VoidCallback onOpen;
  final VoidCallback onDownloadLogs;
  final VoidCallback onDownloadApk;

  @override
  Widget build(BuildContext context) {
    final run = entry.run;
    final status = _runStatus(run.status, run.conclusion);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Column(
          children: [
            InkWell(
              key: ValueKey('run-${run.id}'),
              onTap: onOpen,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                child: Row(
                  children: [
                    Icon(status.$1, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${run.name} • #${run.runNumber}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${entry.branch}${run.detectedVersion == null ? '' : ' • ${run.detectedVersion}'} • ${_formatDate(entry.date)}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    _StatusPill(label: status.$2),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  key: ValueKey('logs-${run.id}'),
                  onPressed: onDownloadLogs,
                  icon: const Icon(Icons.receipt_long_outlined, size: 18),
                  label: const Text('Log'),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  key: ValueKey('apk-${run.id}'),
                  onPressed: onDownloadApk,
                  icon: const Icon(Icons.android_rounded, size: 18),
                  label: const Text('APK'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

(IconData, String) _groupStatus(GlobalRepositoryBuildGroup group) {
  if (group.isRunning) return (Icons.sync_rounded, 'Executando');
  if (group.isFailure) return (Icons.error_outline_rounded, 'Falhou');
  if (group.isSuccess) return (Icons.check_circle_outline_rounded, 'Sucesso');
  return (Icons.info_outline_rounded, 'Concluída');
}

(IconData, String) _runStatus(String status, String? conclusion) {
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

String _formatDate(DateTime? date) {
  if (date == null) return 'data indisponível';
  final local = date.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)} ${two(local.hour)}:${two(local.minute)}';
}
