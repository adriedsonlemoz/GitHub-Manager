import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:github_manager/core/errors/app_exception.dart';
import 'package:github_manager/features/repositories/domain/repository_git_models.dart';
import 'package:github_manager/features/repositories/presentation/code_highlighting_controller.dart';
import 'package:github_manager/features/repositories/presentation/repository_providers.dart';
import 'package:github_manager/core/widgets/centered_notice.dart';

class RepositoryFileEditorScreen extends ConsumerStatefulWidget {
  const RepositoryFileEditorScreen._({
    required this.repositoryFullName,
    required this.branch,
    required this.directory,
    this.item,
  });

  factory RepositoryFileEditorScreen.newFile({
    required String repositoryFullName,
    required String branch,
    required String directory,
  }) =>
      RepositoryFileEditorScreen._(
        repositoryFullName: repositoryFullName,
        branch: branch,
        directory: directory,
      );

  factory RepositoryFileEditorScreen.existing({
    required String repositoryFullName,
    required String branch,
    required RepositoryContentItem item,
  }) =>
      RepositoryFileEditorScreen._(
        repositoryFullName: repositoryFullName,
        branch: branch,
        directory: item.path.contains('/')
            ? item.path.substring(0, item.path.lastIndexOf('/'))
            : '',
        item: item,
      );

  final String repositoryFullName;
  final String branch;
  final String directory;
  final RepositoryContentItem? item;

  bool get isNew => item == null;

  @override
  ConsumerState<RepositoryFileEditorScreen> createState() =>
      _RepositoryFileEditorScreenState();
}

class _RepositoryFileEditorScreenState
    extends ConsumerState<RepositoryFileEditorScreen> {
  final _nameController = TextEditingController();
  late final CodeHighlightingController _contentController;
  final _messageController = TextEditingController();
  RepositoryTextFile? _file;
  bool _loading = false;
  bool _saving = false;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    final initialName = widget.item?.name ?? '';
    _contentController = CodeHighlightingController(fileName: initialName);
    if (!widget.isNew) {
      _nameController.text = widget.item!.name;
      _loadExisting();
    }
  }

  Future<void> _loadExisting() async {
    setState(() => _loading = true);
    try {
      final file = await ref.read(repositoryGitServiceProvider).readTextFile(
            repositoryFullName: widget.repositoryFullName,
            branch: widget.branch,
            path: widget.item!.path,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _file = file;
        _contentController
          ..setFileName(file.name)
          ..text = file.content;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _loadError = error);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    final service = ref.read(repositoryGitServiceProvider);
    setState(() => _saving = true);
    try {
      if (widget.isNew) {
        final name = _nameController.text.trim();
        if (name.isEmpty) {
          throw const RepositoryFileException(
            'Informe o nome do arquivo.',
            code: 'FILE_NAME_REQUIRED',
          );
        }
        final path = widget.directory.isEmpty ? name : '${widget.directory}/$name';
        await service.createTextFile(
          repositoryFullName: widget.repositoryFullName,
          branch: widget.branch,
          path: path,
          content: _contentController.text,
          message: _messageController.text,
        );
      } else {
        final file = _file;
        if (file == null) {
          throw const RepositoryFileException(
            'O arquivo ainda não foi carregado.',
            code: 'FILE_NOT_READY',
          );
        }
        await service.updateTextFile(
          repositoryFullName: widget.repositoryFullName,
          branch: widget.branch,
          file: file,
          content: _contentController.text,
          message: _messageController.text,
        );
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted) {
        final message = error is AppException
            ? error.message
            : 'Não foi possível salvar o arquivo.';
        showCenteredNotice(context, message);
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contentController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _contentController.setBrightness(Theme.of(context).brightness);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? 'Novo arquivo' : widget.item!.name),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Text(
                _contentController.languageLabel,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ),
          const SizedBox(width: 4),
          TextButton(
            onPressed: _saving || _loading || _loadError != null ? null : _save,
            child: Text(_saving ? 'Salvando...' : 'Salvar'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? _ErrorBody(error: _loadError!)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
                  children: [
                    if (widget.isNew) ...[
                      TextField(
                        controller: _nameController,
                        onChanged: _contentController.setFileName,
                        decoration: InputDecoration(
                          labelText: 'Nome/caminho do arquivo',
                          hintText: widget.directory.isEmpty
                              ? 'ex.: README.md'
                              : 'ex.: novo.dart',
                          helperText: widget.directory.isEmpty
                              ? 'Você pode usar pastas, ex.: docs/guia.md'
                              : 'Pasta atual: /${widget.directory}',
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        labelText: 'Mensagem do commit (opcional)',
                        helperText: 'Vazio = mensagem automática com data e hora.',
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerLowest,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            color: Theme.of(context).colorScheme.surfaceContainer,
                            child: Row(
                              children: [
                                const Icon(Icons.code_rounded, size: 17),
                                const SizedBox(width: 7),
                                Text(
                                  _contentController.languageLabel,
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                                const Spacer(),
                                Text(
                                  widget.branch,
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ],
                            ),
                          ),
                          TextField(
                            controller: _contentController,
                            minLines: 22,
                            maxLines: null,
                            keyboardType: TextInputType.multiline,
                            autocorrect: false,
                            enableSuggestions: false,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 13,
                              height: 1.45,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.all(12),
                              border: InputBorder.none,
                              filled: false,
                              hintText: 'Digite o código...',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: const Icon(Icons.save_rounded),
                      label: Text(_saving ? 'Salvando...' : 'Salvar no GitHub'),
                    ),
                  ],
                ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final message = error is AppException
        ? (error as AppException).message
        : 'Não foi possível abrir este arquivo.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.insert_drive_file_outlined, size: 42),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
