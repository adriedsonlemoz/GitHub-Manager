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
part 'repository_artifacts_screen_actions.dart';

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
    extends ConsumerState<RepositoryArtifactsScreen>
    with _RepositoryArtifactsScreenActions {
  @override
  void initState() {
    super.initState();
    initializeRepositoryArtifactsState();
  }

  @override
  void dispose() {
    disposeRepositoryArtifactsState();
    super.dispose();
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
                          onDelete: widget.readOnly
                              ? null
                              : () => _deleteReleaseAsset(asset),
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

  static String? _versionFromName(String value) => RegExp(
        r'(\d+\.\d+(?:\.\d+){0,3}(?:[-+][A-Za-z0-9._-]+)?)',
      ).firstMatch(value)?.group(1);

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
