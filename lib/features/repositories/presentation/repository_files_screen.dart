import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:github_manager/core/errors/app_exception.dart';
import 'package:github_manager/core/widgets/adaptive_dialog.dart';
import 'package:github_manager/features/repositories/domain/repository_git_models.dart';
import 'package:github_manager/features/repositories/presentation/repository_file_editor_screen.dart';
import 'package:github_manager/features/repositories/presentation/repository_providers.dart';
import 'package:github_manager/core/widgets/centered_notice.dart';

class RepositoryFilesScreen extends ConsumerStatefulWidget {
  const RepositoryFilesScreen({
    required this.repositoryFullName,
    required this.defaultBranch,
    super.key,
  });

  final String repositoryFullName;
  final String defaultBranch;

  @override
  ConsumerState<RepositoryFilesScreen> createState() => _RepositoryFilesScreenState();
}

class _RepositoryFilesScreenState extends ConsumerState<RepositoryFilesScreen> {
  String _path = '';
  late Future<List<RepositoryContentItem>> _future;
  bool _uploading = false;
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

  void _showError(Object error) {
    final message = error is AppException ? error.message : 'Não foi possível concluir a operação.';
    showCenteredNotice(context, message);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _path.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _path.isNotEmpty) {
          _upOneLevel();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(onPressed: _upOneLevel, icon: const Icon(Icons.arrow_back_rounded)),
          title: const Text('Arquivos'),
          actions: [
            IconButton(onPressed: _uploading ? null : _createFile, tooltip: 'Novo arquivo', icon: const Icon(Icons.note_add_outlined)),
            IconButton(onPressed: _uploading ? null : _uploadFiles, tooltip: 'Enviar arquivos', icon: const Icon(Icons.upload_file_rounded)),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: Column(
            children: [
              _PathHeader(repositoryFullName: widget.repositoryFullName, branch: widget.defaultBranch, path: _path),
              if (_uploading)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LinearProgressIndicator(value: _uploadTotal > 0 ? _uploadedCount / _uploadTotal : null),
                      const SizedBox(height: 6),
                      Text('Enviando $_uploadedCount de $_uploadTotal arquivo(s)...'),
                    ],
                  ),
                ),
              Expanded(
                child: FutureBuilder<List<RepositoryContentItem>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(18),
                        children: [
                          Card(child: Padding(padding: const EdgeInsets.all(18), child: Text(_message(snapshot.error!)))),
                        ],
                      );
                    }
                    final items = snapshot.data ?? const <RepositoryContentItem>[];
                    if (items.isEmpty) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(18),
                        children: const [
                          Card(
                            child: Padding(
                              padding: EdgeInsets.all(18),
                              child: Text('Esta pasta está vazia. Use o botão de upload ou crie um arquivo.'),
                            ),
                          ),
                        ],
                      );
                    }
                    return ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return ListTile(
                          leading: Icon(item.isDirectory ? Icons.folder_rounded : _fileIcon(item.name)),
                          title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(item.isDirectory ? 'Pasta' : _formatBytes(item.size)),
                          trailing: item.isFile
                              ? PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'open') {
                                      _openFile(item);
                                    } else if (value == 'delete') {
                                      _delete(item);
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(value: 'open', child: Text('Abrir / editar')),
                                    PopupMenuItem(value: 'delete', child: Text('Excluir')),
                                  ],
                                )
                              : const Icon(Icons.chevron_right_rounded),
                          onTap: item.isDirectory ? () => _openDirectory(item) : () => _openFile(item),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _uploading ? null : _uploadFiles,
          icon: const Icon(Icons.upload_rounded),
          label: const Text('Enviar arquivos'),
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

class _PathHeader extends StatelessWidget {
  const _PathHeader({required this.repositoryFullName, required this.branch, required this.path});

  final String repositoryFullName;
  final String branch;
  final String path;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(repositoryFullName, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 3),
          Text('${path.isEmpty ? '/' : '/$path'}  •  $branch', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
