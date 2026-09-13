import 'package:flutter/material.dart';
import 'package:github_manager/core/widgets/app_main_navigation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:github_manager/core/errors/app_exception.dart';
import 'package:github_manager/core/widgets/centered_notice.dart';
import 'package:github_manager/features/builds/domain/action_artifact.dart';
import 'package:github_manager/features/builds/domain/release_asset.dart';
import 'package:github_manager/features/builds/presentation/build_providers.dart';
import 'package:github_manager/features/downloads/presentation/download_providers.dart';
import 'package:github_manager/features/repositories/presentation/repository_providers.dart';
import 'package:github_manager/features/uploads/presentation/upload_center_button.dart';

part 'repository_artifacts_widgets.dart';

enum _ArtifactListFilter { all, releases, artifacts }

enum _ArtifactsMenuAction { select, deleteOlder, help }

class RepositoryArtifactsScreen extends ConsumerStatefulWidget {
  const RepositoryArtifactsScreen({
    required this.repositoryFullName,
    this.readOnly = false,
    super.key,
  });

  final String repositoryFullName;
  final bool readOnly;

  @override
  ConsumerState<RepositoryArtifactsScreen> createState() =>
      _RepositoryArtifactsScreenState();
}

class _RepositoryArtifactsScreenState
    extends ConsumerState<RepositoryArtifactsScreen> {
  late Future<List<ActionArtifact>> _future;
  late Future<List<ReleaseAsset>> _releaseFuture;
  final Set<int> _selectedArtifactIds = <int>{};
  final TextEditingController _searchController = TextEditingController();
  bool _selectionMode = false;
  bool _searchMode = false;
  _ArtifactListFilter _listFilter = _ArtifactListFilter.all;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _releaseFuture = _loadReleases();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<ActionArtifact>> _load() async {
    try {
      return await ref
          .read(artifactServiceProvider)
          .listArtifacts(widget.repositoryFullName);
    } catch (_) {
      if (widget.readOnly) return const <ActionArtifact>[];
      rethrow;
    }
  }

  Future<List<ReleaseAsset>> _loadReleases() async {
    try {
      return await ref
          .read(artifactServiceProvider)
          .listReleaseAssets(widget.repositoryFullName);
    } catch (_) {
      if (widget.readOnly) return const <ReleaseAsset>[];
      rethrow;
    }
  }


  bool _matchesSearch(String value) {
    final query = _searchController.text.trim().toLowerCase();
    return query.isEmpty || value.toLowerCase().contains(query);
  }

  List<ActionArtifact> _visibleArtifacts(List<ActionArtifact> items) {
    if (_listFilter == _ArtifactListFilter.releases && !_selectionMode) {
      return const <ActionArtifact>[];
    }
    return items.where((item) => _matchesSearch(item.name)).toList();
  }

  List<ReleaseAsset> _visibleReleases(List<ReleaseAsset> releases) {
    if (_selectionMode || _listFilter == _ArtifactListFilter.artifacts) {
      return const <ReleaseAsset>[];
    }
    return releases
        .where((asset) => _matchesSearch('${asset.name} ${asset.tagName}'))
        .toList();
  }

  String get _filterLabel => switch (_listFilter) {
        _ArtifactListFilter.all => 'Todos',
        _ArtifactListFilter.releases => 'Releases',
        _ArtifactListFilter.artifacts => 'Artifacts',
      };

  void _toggleSearch() {
    setState(() {
      _searchMode = !_searchMode;
      if (!_searchMode) {
        _searchController.clear();
      }
    });
  }

  void _handleMoreAction(_ArtifactsMenuAction action) {
    switch (action) {
      case _ArtifactsMenuAction.select:
        setState(() {
          _selectionMode = true;
          _searchMode = false;
          _searchController.clear();
          _listFilter = _ArtifactListFilter.all;
        });
        return;
      case _ArtifactsMenuAction.deleteOlder:
        _deleteOlderApks();
        return;
      case _ArtifactsMenuAction.help:
        _showArtifactReleaseHelp();
        return;
    }
  }
  Future<void> _refresh() async {
    final future = _load();
    final releases = _loadReleases();
    setState(() {
      _future = future;
      _releaseFuture = releases;
    });
    await Future.wait([future, releases]);
  }

  static String? _versionFromName(String value) => RegExp(
        r'(\d+\.\d+(?:\.\d+){0,3}(?:[-+][A-Za-z0-9._-]+)?)',
      ).firstMatch(value)?.group(1);

  static bool _artifactLooksStable(ActionArtifact artifact) {
    final lower = artifact.name.toLowerCase();
    return !lower.contains('debug') &&
        !lower.contains('profile') &&
        !lower.contains('test') &&
        !lower.contains('alpha') &&
        !lower.contains('beta') &&
        !lower.contains('preview') &&
        !RegExp(r'(^|[-_.])rc\d*($|[-_.])').hasMatch(lower);
  }

  ReleaseAsset? _matchingRelease(
    ActionArtifact artifact,
    List<ReleaseAsset> releases,
  ) {
    if (!artifact.likelyContainsApk || !_artifactLooksStable(artifact)) {
      return null;
    }
    final version = _versionFromName(artifact.name);
    if (version == null) return null;
    final normalized = version.toLowerCase();
    for (final asset in releases) {
      if (!asset.isApk) continue;
      final tag = asset.tagName.toLowerCase().replaceFirst(RegExp(r'^v'), '');
      final assetVersion = _versionFromName(asset.name)?.toLowerCase();
      if (tag == normalized || assetVersion == normalized) {
        return asset;
      }
    }
    return null;
  }

  Future<void> _download(ActionArtifact artifact) async {
    if (artifact.expired) {
      showCenteredNotice(
        context,
        'Este artifact expirou no GitHub e não está mais disponível para download.',
      );
      return;
    }

    final manager = ref.read(downloadManagerProvider);

    if (artifact.likelyContainsApk) {
      try {
        final releases = await _releaseFuture;
        final release = _matchingRelease(artifact, releases);
        if (release != null) {
          manager.startReleaseAsset(
            title: '${release.tagName} | ${release.name}',
            fileName: release.name,
            repositoryFullName: widget.repositoryFullName,
            assetId: release.id,
            isApk: true,
          );
          if (mounted) {
            showCenteredNotice(
              context,
              'Mesma versão encontrada em Release. Download direto do APK iniciado.',
              kind: CenteredNoticeKind.success,
            );
          }
          return;
        }
      } catch (_) {
        // Release é uma otimização. Se a consulta falhar, o artifact continua
        // funcionando normalmente sem bloquear o download.
      }

      manager.startArtifactApk(
        repositoryFullName: widget.repositoryFullName,
        artifact: artifact,
      );
    } else {
      manager.startArtifactZip(
        repositoryFullName: widget.repositoryFullName,
        artifact: artifact,
      );
    }

    if (mounted) {
      showCenteredNotice(
        context,
        'Download iniciado. Acompanhe pela Central de Downloads.',
      );
    }
  }

  Future<void> _showArtifactReleaseHelp() =>
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
          titlePadding: const EdgeInsets.fromLTRB(16, 15, 16, 4),
          contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          actionsPadding: const EdgeInsets.fromLTRB(10, 2, 10, 10),
          title: const Text('Artifact ou Release?'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Artifact',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 3),
              Text(
                'É a saída temporária criada pelo GitHub Actions. É ideal para builds de teste, Debug e arquivos que podem expirar.',
              ),
              SizedBox(height: 12),
              Text(
                'Release',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 3),
              Text(
                'É uma versão publicada do projeto. O APK fica anexado como arquivo da versão e pode ser baixado diretamente, sem precisar extrair um artifact.',
              ),
              SizedBox(height: 12),
              Text(
                'O GitHub Manager usa automaticamente a Release quando encontra a mesma versão estável; caso contrário, baixa o Artifact.',
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Entendi'),
            ),
          ],
        ),
      );

  void _downloadRelease(ReleaseAsset asset) {
    ref.read(downloadManagerProvider).startReleaseAsset(
          title: '${asset.tagName} • ${asset.name}',
          fileName: asset.name,
          repositoryFullName: widget.repositoryFullName,
          assetId: asset.id,
          isApk: asset.isApk,
        );
    showCenteredNotice(context, 'Download da Release iniciado. Acompanhe pela Central de Downloads.');
  }

  Future<void> _publishRelease(ActionArtifact artifact) async {
    final versionMatch = RegExp(r'(\d+\.\d+\.\d+(?:[-+][A-Za-z0-9._-]+)?)')
        .firstMatch(artifact.name);
    final suggestedVersion = versionMatch?.group(1);
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    final fallbackTag =
        'build-${now.year}${two(now.month)}${two(now.day)}-${two(now.hour)}${two(now.minute)}';
    final tag = TextEditingController(
      text: suggestedVersion == null ? fallbackTag : 'v$suggestedVersion',
    );
    final title = TextEditingController(
      text: suggestedVersion == null
          ? 'Versão ${artifact.name}'
          : 'Versão $suggestedVersion',
    );
    final notes = TextEditingController(
      text: suggestedVersion == null
          ? 'APK publicado pelo GitHub Manager.'
          : 'GitHub Manager $suggestedVersion',
    );
    var latest = true;
    var prerelease = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Publicar GitHub Release'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: tag,
                  decoration: const InputDecoration(
                    labelText: 'Tag da versão',
                    hintText: 'v2.0.15',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Título'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notes,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Novidades / descrição',
                    alignLabelWithHint: true,
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: latest,
                  onChanged: (value) => setDialogState(() => latest = value),
                  title: const Text('Definir como versão mais recente'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: prerelease,
                  onChanged: (value) => setDialogState(() => prerelease = value),
                  title: const Text('Pré-lançamento'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () {
                if (tag.text.trim().isEmpty || title.text.trim().isEmpty) return;
                Navigator.pop(dialogContext, true);
              },
              icon: const Icon(Icons.rocket_launch_outlined),
              label: const Text('Publicar'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) {
      tag.dispose();
      title.dispose();
      notes.dispose();
      return;
    }

    final phase = ValueNotifier<String>('Preparando publicação');
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Publicando Release'),
        content: ValueListenableBuilder<String>(
          valueListenable: phase,
          builder: (context, value, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value),
              const SizedBox(height: 14),
              const LinearProgressIndicator(),
            ],
          ),
        ),
      ),
    );

    try {
      final repository =
          await ref.read(repositoryServiceProvider).getRepository(widget.repositoryFullName);
      final result = await ref.read(artifactServiceProvider).publishArtifactAsRelease(
            repositoryFullName: widget.repositoryFullName,
            targetCommitish: repository.defaultBranch,
            artifact: artifact,
            tagName: tag.text,
            releaseName: title.text,
            notes: notes.text,
            makeLatest: latest,
            prerelease: prerelease,
            onProgress: (value) => phase.value = value,
          );
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      await _refresh();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Release publicada'),
          content: Text(
            '${result.releaseName}\n\n'
            'Tag: ${result.tagName}\n'
            'APK: ${result.assetName}\n\n'
            'Agora o APK fica disponível na área Releases do GitHub.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Fechar'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        showCenteredNotice(context, _message(error));
      }
    } finally {
      phase.dispose();
      tag.dispose();
      title.dispose();
      notes.dispose();
    }
  }

  Future<void> _deleteOlderApks() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir APKs anteriores?'),
        content: const Text(
          'O artifact APK mais recente será mantido. Todos os APKs anteriores ainda disponíveis serão excluídos permanentemente do GitHub.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Excluir anteriores'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final count = await ref
          .read(artifactServiceProvider)
          .deleteOlderApkArtifacts(widget.repositoryFullName);
      await _refresh();
      if (mounted) {
        showCenteredNotice(context, count == 0
                  ? 'Não havia APKs anteriores para excluir.'
                  : '$count APK(s) anterior(es) excluído(s) permanentemente.');
      }
    } catch (error) {
      if (mounted) {
        showCenteredNotice(context, _message(error));
      }
    }
  }

  void _toggleSelection(ActionArtifact artifact) {
    if (widget.readOnly) return;
    setState(() {
      _selectionMode = true;
      if (!_selectedArtifactIds.add(artifact.id)) {
        _selectedArtifactIds.remove(artifact.id);
      }
      if (_selectedArtifactIds.isEmpty) {
        _selectionMode = false;
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedArtifactIds.clear();
      _selectionMode = false;
    });
  }

  Future<void> _selectAllArtifacts() async {
    final items = await _future;
    if (!mounted) return;
    setState(() {
      _selectionMode = true;
      final visibleItems = items.where((item) => _matchesSearch(item.name));
      _selectedArtifactIds
        ..clear()
        ..addAll(visibleItems.map((item) => item.id));
    });
  }

  Future<void> _deleteSelectedArtifacts() async {
    if (_selectedArtifactIds.isEmpty || widget.readOnly) return;
    final count = _selectedArtifactIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Excluir $count artifact(s)?'),
        content: const Text(
          'Os artifacts selecionados serão removidos permanentemente do GitHub. '
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

    try {
      final deleted = await ref.read(artifactServiceProvider).deleteArtifacts(
            repositoryFullName: widget.repositoryFullName,
            artifactIds: _selectedArtifactIds,
          );
      _clearSelection();
      await _refresh();
      if (mounted) {
        showCenteredNotice(context, '$deleted artifact(s) excluído(s) permanentemente.');
      }
    } catch (error) {
      if (mounted) {
        showCenteredNotice(context, _message(error));
      }
    }
  }

  Future<void> _deleteArtifact(ActionArtifact artifact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir artifact permanentemente?'),
        content: Text(
          '${artifact.name} será removido do GitHub. Esta ação não pode ser desfeita.',
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
    try {
      await ref.read(artifactServiceProvider).deleteArtifact(
            repositoryFullName: widget.repositoryFullName,
            artifactId: artifact.id,
          );
      await _refresh();
      if (mounted) {
        showCenteredNotice(context, 'Artifact excluído permanentemente.');
      }
    } catch (error) {
      if (mounted) {
        showCenteredNotice(context, _message(error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const AppMainNavigation(selectedIndex: 0),
      appBar: AppBar(
        leading: _selectionMode
            ? IconButton(
                onPressed: _clearSelection,
                tooltip: 'Cancelar seleção',
                icon: const Icon(Icons.close_rounded),
              )
            : null,
        title: _selectionMode
            ? Text('${_selectedArtifactIds.length} selecionado(s)')
            : const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('APKs'),
                  Text(
                    'Releases e artifacts',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
        actions: [
          if (!widget.readOnly && _selectionMode) ...[
            IconButton(
              onPressed: _selectAllArtifacts,
              tooltip: 'Selecionar todos',
              icon: const Icon(Icons.select_all_rounded),
            ),
            IconButton(
              onPressed: _selectedArtifactIds.isEmpty
                  ? null
                  : _deleteSelectedArtifacts,
              tooltip: 'Excluir selecionados',
              icon: const Icon(Icons.delete_forever_outlined),
            ),
          ] else ...[
            IconButton(
              onPressed: _toggleSearch,
              tooltip: _searchMode ? 'Fechar busca' : 'Buscar arquivo',
              icon: Icon(
                _searchMode ? Icons.search_off_rounded : Icons.search_rounded,
              ),
            ),
            PopupMenuButton<_ArtifactListFilter>(
              tooltip: 'Filtrar: $_filterLabel',
              initialValue: _listFilter,
              onSelected: (value) => setState(() => _listFilter = value),
              icon: Badge(
                isLabelVisible: _listFilter != _ArtifactListFilter.all,
                smallSize: 7,
                child: const Icon(Icons.filter_list_rounded),
              ),
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _ArtifactListFilter.all,
                  child: Text('Todos'),
                ),
                PopupMenuItem(
                  value: _ArtifactListFilter.releases,
                  child: Text('Somente Releases'),
                ),
                PopupMenuItem(
                  value: _ArtifactListFilter.artifacts,
                  child: Text('Somente Artifacts'),
                ),
              ],
            ),
            const UploadCenterButton(),
            if (!widget.readOnly)
              PopupMenuButton<_ArtifactsMenuAction>(
                tooltip: 'Mais opções',
                onSelected: _handleMoreAction,
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: _ArtifactsMenuAction.select,
                    child: ListTile(
                      dense: true,
                      leading: Icon(Icons.checklist_rounded),
                      title: Text('Selecionar artifacts'),
                    ),
                  ),
                  PopupMenuItem(
                    value: _ArtifactsMenuAction.deleteOlder,
                    child: ListTile(
                      dense: true,
                      leading: Icon(Icons.auto_delete_outlined),
                      title: Text('Excluir APKs anteriores'),
                    ),
                  ),
                  PopupMenuItem(
                    value: _ArtifactsMenuAction.help,
                    child: ListTile(
                      dense: true,
                      leading: Icon(Icons.help_outline_rounded),
                      title: Text('Artifact ou Release?'),
                    ),
                  ),
                ],
              )
            else
              IconButton(
                onPressed: _showArtifactReleaseHelp,
                tooltip: 'Artifact x Release',
                icon: const Icon(Icons.help_outline_rounded),
              ),
            const SizedBox(width: 2),
          ],
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<ActionArtifact>>(
          future: _future,
          builder: (context, artifactSnapshot) {
            if (artifactSnapshot.connectionState == ConnectionState.waiting) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 220),
                  Center(child: CircularProgressIndicator()),
                ],
              );
            }
            if (artifactSnapshot.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(18),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Text(_message(artifactSnapshot.error!)),
                    ),
                  ),
                ],
              );
            }

            final artifacts =
                artifactSnapshot.data ?? const <ActionArtifact>[];
            return FutureBuilder<List<ReleaseAsset>>(
              future: _releaseFuture,
              builder: (context, releaseSnapshot) {
                final releases =
                    releaseSnapshot.data ?? const <ReleaseAsset>[];
                final visibleArtifacts = _visibleArtifacts(artifacts);
                final visibleReleases = _visibleReleases(releases);
                final releaseLoading =
                    releaseSnapshot.connectionState == ConnectionState.waiting;
                final noResults = !releaseLoading &&
                    visibleArtifacts.isEmpty &&
                    visibleReleases.isEmpty;

                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
                  children: [
                    if (_searchMode) ...[
                      TextField(
                        controller: _searchController,
                        autofocus: true,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Buscar por nome ou versão',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _searchController.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Limpar busca',
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                  icon: const Icon(Icons.close_rounded),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (!_selectionMode)
                      _ArtifactsOverview(
                        releases: releases.length,
                        artifacts: artifacts.length,
                        filterLabel: _filterLabel,
                      ),
                    if (!_selectionMode) const SizedBox(height: 10),
                    if (releaseLoading && !_selectionMode)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(14),
                          child: LinearProgressIndicator(),
                        ),
                      )
                    else if (releaseSnapshot.hasError && !_selectionMode)
                      const _ArtifactsInlineNotice(
                        icon: Icons.cloud_off_outlined,
                        text: 'Não foi possível carregar as Releases agora.',
                      ),
                    if (visibleReleases.isNotEmpty) ...[
                      _ArtifactsSectionHeader(
                        icon: Icons.new_releases_outlined,
                        title: 'Releases',
                        count: visibleReleases.length,
                        subtitle: 'Download direto, sem abrir outra lista',
                      ),
                      const SizedBox(height: 8),
                      ...visibleReleases.map(
                        (asset) => _ReleaseAssetCard(
                          asset: asset,
                          onDownload: () => _downloadRelease(asset),
                        ),
                      ),
                    ],
                    if (visibleArtifacts.isNotEmpty) ...[
                      if (visibleReleases.isNotEmpty)
                        const SizedBox(height: 6),
                      _ArtifactsSectionHeader(
                        icon: Icons.inventory_2_outlined,
                        title: 'Artifacts',
                        count: visibleArtifacts.length,
                        subtitle: 'Arquivos temporários do GitHub Actions',
                      ),
                      const SizedBox(height: 8),
                      ...visibleArtifacts.map(
                        (artifact) => _ArtifactCard(
                          artifact: artifact,
                          readOnly: widget.readOnly,
                          selectionMode: _selectionMode,
                          selected: _selectedArtifactIds.contains(artifact.id),
                          onToggleSelection: () => _toggleSelection(artifact),
                          onDownload:
                              artifact.expired ? null : () => _download(artifact),
                          onPublish: !widget.readOnly &&
                                  artifact.likelyContainsApk &&
                                  !artifact.expired
                              ? () => _publishRelease(artifact)
                              : null,
                          onDelete: widget.readOnly
                              ? null
                              : () => _deleteArtifact(artifact),
                        ),
                      ),
                    ],
                    if (noResults)
                      _ArtifactsEmptyState(
                        filtered: _searchController.text.trim().isNotEmpty ||
                            _listFilter != _ArtifactListFilter.all,
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  String _message(Object error) => error is AppException
      ? error.message
      : 'Não foi possível carregar os artifacts.';

  static String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }

  static String _formatDate(DateTime? date) {
    if (date == null) {
      return 'Data indisponível';
    }
    final local = date.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
  }
}
