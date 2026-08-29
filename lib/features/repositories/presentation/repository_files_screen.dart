import 'package:flutter/material.dart';
import 'package:github_manager/core/widgets/app_main_navigation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:github_manager/core/errors/app_exception.dart';
import 'package:github_manager/core/widgets/adaptive_dialog.dart';
import 'package:github_manager/features/permissions/domain/repository_permission_preflight.dart';
import 'package:github_manager/features/permissions/presentation/permission_preflight_guard.dart';
import 'package:github_manager/features/repositories/domain/repository_git_models.dart';
import 'package:github_manager/features/repositories/presentation/repository_file_editor_screen.dart';
import 'package:github_manager/features/repositories/presentation/repository_providers.dart';
import 'package:github_manager/core/widgets/centered_notice.dart';
import 'package:go_router/go_router.dart';

class RepositoryFilesScreen extends ConsumerStatefulWidget {
  const RepositoryFilesScreen({
    required this.repositoryFullName,
    required this.defaultBranch,
    this.readOnly = false,
    super.key,
  });

  final String repositoryFullName;
  final String defaultBranch;
  final bool readOnly;

  @override
  ConsumerState<RepositoryFilesScreen> createState() => _RepositoryFilesScreenState();
}

class _RepositoryFilesScreenState extends ConsumerState<RepositoryFilesScreen> {
  String _path = '';
  late Future<List<RepositoryContentItem>> _future;
  bool _uploading = false;
  bool _clearing = false;
  int _uploadedCount = 0;
  int _uploadTotal = 0;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<RepositoryContentItem>> _load() => ref.read(repositoryGitServiceProvider).listContents(
        repositoryFullName: widget.repositoryFullName,
        branch: widget.defaultBranch,
        path: _path,
      );

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _future = future);
    await future;
  }

  void _openDirectory(RepositoryContentItem item) {
    setState(() {
      _path = item.path;
      _future = _load();
    });
  }

  void _upOneLevel() {
    if (_path.isEmpty) {
      Navigator.of(context).maybePop();
      return;
    }
    final parts = _path.split('/');
    parts.removeLast();
    setState(() {
      _path = parts.join('/');
      _future = _load();
    });
  }

  Future<void> _uploadFiles() async {
    final service = ref.read(repositoryGitServiceProvider);
    final files = await service.pickFiles();
    if (files.isEmpty || !mounted) {
      return;
    }
    setState(() {
      _uploading = true;
      _uploadedCount = 0;
      _uploadTotal = files.length;
    });
    try {
      for (final file in files) {
        await service.uploadPickedFile(
          repositoryFullName: widget.repositoryFullName,
          branch: widget.defaultBranch,
          directory: _path,
          pickedFile: file,
        );
        if (mounted) {
          setState(() => _uploadedCount++);
        }
      }
      await _refresh();
      if (mounted) {
        showCenteredNotice(context, '${files.length} arquivo(s) enviado(s) ao GitHub.');
      }
    } catch (error) {
      if (mounted) {
        _showError(error);
      }
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
      }
    }
  }

  Future<void> _createFile() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RepositoryFileEditorScreen.newFile(
          repositoryFullName: widget.repositoryFullName,
          branch: widget.defaultBranch,
          directory: _path,
        ),
      ),
    );
    if (created == true) {
      await _refresh();
    }
  }

  Future<void> _openFile(RepositoryContentItem item) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RepositoryFileEditorScreen.existing(
          repositoryFullName: widget.repositoryFullName,
          branch: widget.defaultBranch,
          item: item,
          readOnly: widget.readOnly,
        ),
      ),
    );
    if (changed == true) {
      await _refresh();
    }
  }

  Future<void> _delete(RepositoryContentItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir arquivo?'),
        content: AdaptiveDialogBody(
          child: Text(
            'Excluir permanentemente “${item.path}” da branch ${widget.defaultBranch}?',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir')),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    try {
      await ref.read(repositoryGitServiceProvider).deleteItem(
            repositoryFullName: widget.repositoryFullName,
            branch: widget.defaultBranch,
            item: item,
          );
      await _refresh();
      if (mounted) {
        showCenteredNotice(context, 'Arquivo excluído.');
      }
    } catch (error) {
      if (mounted) {
        _showError(error);
      }
    }
  }

  Future<void> _clearAllFiles() async {
    if (_uploading || _clearing) return;

    final allowed = await ensureRepositoryPermission(
      context,
      ref,
      repositoryFullName: widget.repositoryFullName,
      action: RepositoryCriticalAction.manageFiles,
    );
    if (!allowed || !mounted) return;

    setState(() => _clearing = true);
    try {
      final service = ref.read(repositoryGitServiceProvider);
      final count = await service.countRepositoryFiles(
        repositoryFullName: widget.repositoryFullName,
        branch: widget.defaultBranch,
      );
      if (!mounted) return;

      if (count == 0) {
        showCenteredNotice(
          context,
          'A branch ${widget.defaultBranch} já está sem arquivos.',
        );
        return;
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
          title: const Text('Limpar arquivos do repositório?'),
          content: AdaptiveDialogBody(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.repositoryFullName,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text('$count arquivo(s) serão removidos da branch '
                    '${widget.defaultBranch} em um único commit.'),
                const SizedBox(height: 8),
                const Text(
                  'O repositório NÃO será excluído. Histórico, Issues, Secrets, '
                  'Actions e configurações permanecem.',
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
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.cleaning_services_outlined),
              label: const Text('Limpar arquivos'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;

      final removed = await service.clearRepositoryFiles(
        repositoryFullName: widget.repositoryFullName,
        branch: widget.defaultBranch,
      );
      _path = '';
      await _refresh();
      if (mounted) {
        showCenteredNotice(
          context,
          '$removed arquivo(s) removido(s). O repositório foi mantido.',
          kind: CenteredNoticeKind.success,
        );
      }
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  void _showError(Object error) {
    final message = error is AppException ? error.message : 'Não foi possível concluir a operação.';
    showCenteredNotice(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: _path.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _path.isNotEmpty) {
          _upOneLevel();
        }
      },
      child: Scaffold(
        bottomNavigationBar: const AppMainNavigation(selectedIndex: 0),
        appBar: AppBar(
          leading: IconButton(
            onPressed: _upOneLevel,
            tooltip: _path.isEmpty ? 'Voltar' : 'Pasta anterior',
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: Text(
            widget.readOnly ? 'Arquivos • leitura' : 'Arquivos',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            IconButton(
              onPressed: _uploading || _clearing ? null : _refresh,
              tooltip: 'Atualizar',
              icon: const Icon(Icons.refresh_rounded),
            ),
            if (!widget.readOnly)
              PopupMenuButton<String>(
                tooltip: 'Mais ações',
                onSelected: (value) {
                  if (value == 'clear') _clearAllFiles();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'clear',
                    child: Row(
                      children: [
                        Icon(Icons.cleaning_services_outlined),
                        SizedBox(width: 10),
                        Text('Limpar arquivos'),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: Column(
            children: [
              _PathHeader(
                repositoryFullName: widget.repositoryFullName,
                branch: widget.defaultBranch,
                path: _path,
              ),
              if (!widget.readOnly)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 7, 12, 5),
                  child: Row(
                    children: [
                      Expanded(
                        child: _FileQuickAction(
                          icon: Icons.note_add_outlined,
                          label: 'Novo',
                          onPressed: _uploading || _clearing ? null : _createFile,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _FileQuickAction(
                          icon: Icons.upload_file_rounded,
                          label: 'Enviar',
                          filled: true,
                          onPressed: _uploading || _clearing ? null : _uploadFiles,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _FileQuickAction(
                          icon: Icons.verified_user_outlined,
                          label: 'Permissões',
                          onPressed: () => context.push(
                            '/repositories/${widget.repositoryFullName}/permissions',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_uploading)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LinearProgressIndicator(
                        value: _uploadTotal > 0
                            ? _uploadedCount / _uploadTotal
                            : null,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Enviando $_uploadedCount de $_uploadTotal',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: FutureBuilder<List<RepositoryContentItem>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: scheme.errorContainer.withValues(alpha: .35),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(_message(snapshot.error!)),
                          ),
                        ],
                      );
                    }

                    final items =
                        snapshot.data ?? const <RepositoryContentItem>[];
                    if (items.isEmpty) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(12, 18, 12, 88),
                        children: [
                          Center(
                            child: Text(
                              'Esta pasta está vazia.',
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    return ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(10, 5, 10, 88),
                      itemCount: items.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: 3),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return Material(
                          color: scheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(11),
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                            dense: true,
                            visualDensity: const VisualDensity(vertical: -2),
                            contentPadding:
                                const EdgeInsets.fromLTRB(10, 1, 4, 1),
                            leading: Icon(
                              item.isDirectory
                                  ? Icons.folder_rounded
                                  : _fileIcon(item.name),
                              size: 21,
                              color: item.isDirectory
                                  ? scheme.primary
                                  : scheme.onSurfaceVariant,
                            ),
                            title: Text(
                              item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(
                              item.isDirectory
                                  ? 'Pasta'
                                  : _formatBytes(item.size),
                              maxLines: 1,
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                            trailing: item.isFile
                                ? widget.readOnly
                                    ? const Icon(
                                        Icons.visibility_outlined,
                                        size: 19,
                                      )
                                    : PopupMenuButton<String>(
                                        tooltip: 'Ações',
                                        onSelected: (value) {
                                          if (value == 'open') {
                                            _openFile(item);
                                          } else if (value == 'delete') {
                                            _delete(item);
                                          }
                                        },
                                        itemBuilder: (_) => const [
                                          PopupMenuItem(
                                            value: 'open',
                                            child: Text('Abrir / editar'),
                                          ),
                                          PopupMenuItem(
                                            value: 'delete',
                                            child: Text('Excluir'),
                                          ),
                                        ],
                                      )
                                : const Icon(
                                    Icons.chevron_right_rounded,
                                    size: 20,
                                  ),
                            onTap: item.isDirectory
                                ? () => _openDirectory(item)
                                : () => _openFile(item),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _message(Object error) => error is AppException ? error.message : 'Não foi possível carregar os arquivos.';

  static IconData _fileIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.dart') || lower.endsWith('.js') || lower.endsWith('.ts') || lower.endsWith('.java') || lower.endsWith('.kt')) {
      return Icons.code_rounded;
    }
    if (lower.endsWith('.yml') || lower.endsWith('.yaml') || lower.endsWith('.json')) {
      return Icons.data_object_rounded;
    }
    if (lower.endsWith('.md') || lower.endsWith('.txt')) {
      return Icons.description_outlined;
    }
    if (lower.endsWith('.png') || lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.webp')) {
      return Icons.image_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  static String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '$bytes B';
  }
}

class _FileQuickAction extends StatelessWidget {
  const _FileQuickAction({
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
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, 40)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      ),
      visualDensity: VisualDensity.compact,
    );
    return filled
        ? FilledButton.tonalIcon(
            onPressed: onPressed,
            style: style,
            icon: Icon(icon, size: 17),
            label: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
            ),
          )
        : OutlinedButton.icon(
            onPressed: onPressed,
            style: style,
            icon: Icon(icon, size: 17),
            label: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
            ),
          );
  }
}

class _PathHeader extends StatelessWidget {
  const _PathHeader({
    required this.repositoryFullName,
    required this.branch,
    required this.path,
  });

  final String repositoryFullName;
  final String branch;
  final String path;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 3, 12, 0),
      child: Row(
        children: [
          Icon(Icons.account_tree_outlined,
              size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              path.isEmpty ? repositoryFullName : '/$path',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: .55),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              branch,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ],
      ),
    );
  }
}
