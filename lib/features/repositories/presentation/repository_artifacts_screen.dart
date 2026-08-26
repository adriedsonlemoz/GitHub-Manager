import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:github_manager/core/errors/app_exception.dart';
import 'package:github_manager/features/builds/domain/action_artifact.dart';
import 'package:github_manager/features/builds/domain/release_asset.dart';
import 'package:github_manager/features/builds/presentation/build_providers.dart';
import 'package:github_manager/features/downloads/presentation/download_center_button.dart';
import 'package:github_manager/features/downloads/presentation/download_providers.dart';
import 'package:github_manager/features/repositories/presentation/repository_providers.dart';
import 'package:github_manager/core/widgets/centered_notice.dart';

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
  bool _selectionMode = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _releaseFuture = _loadReleases();
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

  Future<void> _refresh() async {
    final future = _load();
    final releases = _loadReleases();
    setState(() {
      _future = future;
      _releaseFuture = releases;
    });
    await Future.wait([future, releases]);
  }

  void _download(ActionArtifact artifact) {
    if (artifact.expired) {
      showCenteredNotice(context, 'Este artifact expirou no GitHub e não está mais disponível para download.');
      return;
    }
    final manager = ref.read(downloadManagerProvider);
    if (artifact.likelyContainsApk) {
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
    showCenteredNotice(context, 'Download iniciado. Acompanhe pela Central de Downloads.');
  }

  void _downloadRelease(ReleaseAsset asset) {
    ref.read(downloadManagerProvider).startPublicUrl(
          title: '${asset.tagName} • ${asset.name}',
          fileName: asset.name,
          repositoryFullName: widget.repositoryFullName,
          url: asset.downloadUrl,
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
      _selectedArtifactIds
        ..clear()
        ..addAll(items.map((item) => item.id));
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
      appBar: AppBar(
        leading: _selectionMode
            ? IconButton(
                onPressed: _clearSelection,
                tooltip: 'Cancelar seleção',
                icon: const Icon(Icons.close_rounded),
              )
            : null,
        title: Text(
          _selectionMode
              ? '${_selectedArtifactIds.length} selecionado(s)'
              : 'APKs e Artifacts',
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
          ] else if (!widget.readOnly) ...[
            IconButton(
              onPressed: () => setState(() => _selectionMode = true),
              tooltip: 'Selecionar artifacts',
              icon: const Icon(Icons.checklist_rounded),
            ),
            IconButton(
              onPressed: _deleteOlderApks,
              tooltip: 'Excluir APKs anteriores',
              icon: const Icon(Icons.auto_delete_outlined),
            ),
          ],
          if (!_selectionMode) const DownloadCenterButton(),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<ActionArtifact>>(
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
                padding: const EdgeInsets.all(18),
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
            final items = snapshot.data ?? const <ActionArtifact>[];
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              itemCount: items.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return FutureBuilder<List<ReleaseAsset>>(
                    future: _releaseFuture,
                    builder: (context, releaseSnapshot) {
                      final releases = releaseSnapshot.data ?? const <ReleaseAsset>[];
                      if (releaseSnapshot.connectionState == ConnectionState.waiting) {
                        return const Card(
                          child: Padding(
                            padding: EdgeInsets.all(14),
                            child: LinearProgressIndicator(),
                          ),
                        );
                      }
                      if (releases.isEmpty) {
                        if (items.isEmpty) {
                          return const Card(
                            child: Padding(
                              padding: EdgeInsets.all(18),
                              child: Text(
                                'Nenhum APK, artifact ou arquivo de Release disponível neste repositório.',
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      }
                      return Card(
                        child: ExpansionTile(
                          initiallyExpanded: widget.readOnly,
                          leading: const Icon(Icons.new_releases_outlined),
                          title: const Text('Releases públicas'),
                          subtitle: Text('${releases.length} arquivo(s) disponível(is)'),
                          children: releases.take(20).map(
                            (asset) => ListTile(
                              leading: Icon(
                                asset.isApk ? Icons.android_rounded : Icons.download_outlined,
                              ),
                              title: Text(asset.name),
                              subtitle: Text(
                                '${asset.tagName} • ${_formatBytes(asset.sizeBytes)} • ${_formatDate(asset.publishedAt)}',
                              ),
                              trailing: const Icon(Icons.download_rounded),
                              onTap: () => _downloadRelease(asset),
                            ),
                          ).toList(),
                        ),
                      );
                    },
                  );
                }
                final artifact = items[index - 1];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (_selectionMode && !widget.readOnly)
                              Checkbox(
                                value: _selectedArtifactIds.contains(artifact.id),
                                onChanged: (_) => _toggleSelection(artifact),
                              )
                            else
                              Icon(
                                artifact.likelyContainsApk
                                    ? Icons.android_rounded
                                    : Icons.inventory_2_outlined,
                              ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: InkWell(
                                onLongPress: widget.readOnly
                                    ? null
                                    : () => _toggleSelection(artifact),
                                onTap: _selectionMode && !widget.readOnly
                                    ? () => _toggleSelection(artifact)
                                    : null,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Text(
                                    artifact.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_formatBytes(artifact.sizeBytes)} • ${_formatDate(artifact.createdAt)}',
                        ),
                        if (artifact.expired) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Expirado — o GitHub removeu os arquivos deste artifact.',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        if (!_selectionMode)
                          Align(
                            alignment: Alignment.centerRight,
                            child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.end,
                            children: [
                              FilledButton.tonalIcon(
                                onPressed: artifact.expired ? null : () => _download(artifact),
                                icon: Icon(
                                  artifact.expired
                                      ? Icons.history_toggle_off_rounded
                                      : Icons.download_rounded,
                                ),
                                label: Text(
                                  artifact.expired
                                      ? 'Artifact expirado'
                                      : artifact.likelyContainsApk
                                          ? 'Baixar APK'
                                          : 'Baixar artifact',
                                ),
                              ),
                              if (!widget.readOnly &&
                                  artifact.likelyContainsApk &&
                                  !artifact.expired)
                                FilledButton.icon(
                                  onPressed: () => _publishRelease(artifact),
                                  icon: const Icon(Icons.rocket_launch_outlined),
                                  label: const Text('Publicar versão'),
                                ),
                              if (!widget.readOnly)
                                OutlinedButton.icon(
                                  onPressed: () => _deleteArtifact(artifact),
                                  icon: const Icon(Icons.delete_forever_outlined),
                                  label: const Text('Excluir'),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
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
