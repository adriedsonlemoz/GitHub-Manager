part of 'repository_artifacts_screen.dart';

mixin _RepositoryArtifactsScreenActions on ConsumerState<RepositoryArtifactsScreen> {
  late Future<List<ActionArtifact>> _future;
  late Future<List<ReleaseAsset>> _releaseFuture;
  final Set<int> _selectedArtifactIds = <int>{};
  final TextEditingController _searchController = TextEditingController();
  bool _selectionMode = false;
  bool _searchMode = false;
  _ArtifactListFilter _listFilter = _ArtifactListFilter.all;

  void initializeRepositoryArtifactsState() {
    _future = _load();
    _releaseFuture = _loadReleases();
  }

  void disposeRepositoryArtifactsState() {
    _searchController.dispose();
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

  List<ReleaseAssetGroup> _visibleReleaseGroups(
    List<ReleaseAssetGroup> groups,
  ) {
    if (_selectionMode || _listFilter == _ArtifactListFilter.artifacts) {
      return const <ReleaseAssetGroup>[];
    }
    return groups.where((group) {
      final searchable = <String>[
        group.version ?? '',
        group.tagName,
        group.releaseName,
        ...group.assets.map((asset) => asset.name),
      ].join(' ');
      return _matchesSearch(searchable);
    }).toList(growable: false);
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
    ref.invalidate(repositoryArtifactsProvider(widget.repositoryFullName));
    ref.invalidate(repositoryReleaseAssetsProvider(widget.repositoryFullName));
    final future = _load();
    final releases = _loadReleases();
    setState(() {
      _future = future;
      _releaseFuture = releases;
    });
    await Future.wait([future, releases]);
  }

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
    final version = _RepositoryArtifactsScreenState._versionFromName(artifact.name);
    if (version == null) return null;
    final normalized = version.toLowerCase();
    for (final asset in releases) {
      if (!asset.isApk) continue;
      final tag = asset.tagName.toLowerCase().replaceFirst(RegExp(r'^v'), '');
      final assetVersion = _RepositoryArtifactsScreenState._versionFromName(asset.name)?.toLowerCase();
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
                'É uma versão publicada do projeto. O APK fica anexado como arquivo da versão e pode ser baixado diretamente. Releases são independentes das builds e podem ser excluídas separadamente.',
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
    showCenteredNotice(
      context,
      'Download iniciado. Acompanhe pela Central de Downloads.',
    );
  }

  Future<void> _downloadReleaseGroup(ReleaseAssetGroup group) async {
    if (!group.hasMultipleAssets) {
      _downloadRelease(group.preferredAsset);
      return;
    }

    final selected = await showModalBottomSheet<ReleaseAsset>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                group.version == null
                    ? 'Escolha o arquivo'
                    : 'Versão ${group.version}',
                style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Escolha a variante para baixar. Universal funciona na maioria dos aparelhos.',
                style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                      color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 420),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: group.assets.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final asset = group.assets[index];
                    final recommended = releaseAssetIsRecommended(asset);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        child: Icon(
                          asset.isApk
                              ? Icons.android_rounded
                              : Icons.insert_drive_file_outlined,
                        ),
                      ),
                      title: Text(
                        releaseAssetVariantLabel(asset),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        '${asset.name} • ${_RepositoryArtifactsScreenState._formatBytes(asset.sizeBytes)}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: recommended
                          ? const Chip(label: Text('Recomendado'))
                          : const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.pop(sheetContext, asset),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && mounted) {
      _downloadRelease(selected);
    }
  }

  Future<void> _manageReleaseGroup(ReleaseAssetGroup group) async {
    if (group.assets.length == 1) {
      await _deleteReleaseAsset(group.assets.first);
      return;
    }

    final selected = await showModalBottomSheet<ReleaseAsset>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Gerenciar arquivos',
                style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Escolha qual arquivo desta versão deseja excluir.',
                style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                      color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 8),
              ...group.assets.map(
                (asset) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    asset.isApk
                        ? Icons.android_rounded
                        : Icons.insert_drive_file_outlined,
                  ),
                  title: Text(releaseAssetVariantLabel(asset)),
                  subtitle: Text(
                    asset.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.delete_outline_rounded),
                  onTap: () => Navigator.pop(sheetContext, asset),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && mounted) {
      await _deleteReleaseAsset(selected);
    }
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
            targetCommitish: artifact.workflowRunHeadSha?.trim().isNotEmpty == true
                ? artifact.workflowRunHeadSha!.trim()
                : repository.defaultBranch,
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

  Future<void> _deleteReleaseAsset(ReleaseAsset asset) async {
    if (widget.readOnly) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(asset.isApk ? 'Excluir APK da Release?' : 'Excluir arquivo da Release?'),
        content: Text(
          '${asset.name} será removido permanentemente da Release ${asset.tagName}. '
          'A Release e a tag serão mantidas; somente este arquivo será excluído.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_forever_outlined),
            label: Text(asset.isApk ? 'Excluir APK' : 'Excluir arquivo'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(artifactServiceProvider).deleteReleaseAsset(
            repositoryFullName: widget.repositoryFullName,
            assetId: asset.id,
          );
      ref.invalidate(repositoryReleaseAssetsProvider(widget.repositoryFullName));
      await _refresh();
      if (mounted) {
        showCenteredNotice(
          context,
          '${asset.isApk ? 'APK' : 'Arquivo'} ${asset.name} excluído da Release ${asset.tagName}.',
        );
      }
    } catch (error) {
      if (mounted) showCenteredNotice(context, _message(error));
    }
  }

  Future<void> _deleteOlderApks() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir APKs anteriores?'),
        content: const Text(
          'O APK mais recente de cada origem será mantido. O GitHub Manager vai limpar tanto artifacts APK antigos do Actions quanto APKs antigos anexados a Releases, sem apagar as Releases ou tags.',
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
      // Usa exatamente os itens que estão visíveis na tela. Assim a limpeza
      // não depende de uma segunda listagem que pode chegar vazia/atrasada
      // enquanto o usuário está vendo APKs antigos no card.
      final visibleArtifacts = await _future;
      final visibleReleaseAssets = await _releaseFuture;
      final result = await ref
          .read(artifactServiceProvider)
          .deleteOlderApkOutputs(
            widget.repositoryFullName,
            artifactsSnapshot: visibleArtifacts,
            releaseAssetsSnapshot: visibleReleaseAssets,
          );
      await _refresh();
      if (!mounted) return;
      final details = <String>[
        if (result.artifactsDeleted > 0)
          '${result.artifactsDeleted} artifact(s)',
        if (result.releaseAssetsDeleted > 0)
          '${result.releaseAssetsDeleted} APK(s) de Release',
      ].join(' • ');
      if (result.totalDeleted == 0 && !result.hasWarnings) {
        showCenteredNotice(
          context,
          'Não havia APKs anteriores para excluir.',
        );
      } else if (result.hasWarnings) {
        showCenteredNotice(
          context,
          result.totalDeleted == 0
              ? 'A limpeza não pôde ser concluída. Para APKs de Release, confirme Contents: write no token e tente novamente.'
              : '$details excluído(s). Alguns itens não puderam ser removidos; APKs de Release exigem Contents: write no token.',
          kind: CenteredNoticeKind.error,
        );
      } else {
        showCenteredNotice(
          context,
          '$details excluído(s) permanentemente.',
          kind: CenteredNoticeKind.success,
        );
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

  String _message(Object error) => error is AppException
      ? error.message
      : 'Não foi possível carregar os artifacts.';
}
