import 'package:flutter/material.dart';
import 'package:github_manager/core/widgets/adaptive_dialog.dart';
import 'package:github_manager/features/repositories/domain/github_repository.dart';

class RepositoryDraft {
  const RepositoryDraft({
    required this.name,
    required this.description,
    required this.isPrivate,
    required this.homepage,
    this.isArchived = false,
  });

  final String name;
  final String description;
  final String homepage;
  final bool isPrivate;
  final bool isArchived;
}

enum RepositoryAction { edit, delete }

Future<RepositoryDraft?> showCreateRepositoryDialog(BuildContext context) =>
    showDialog<RepositoryDraft>(
      context: context,
      builder: (context) => const _CreateRepositoryDialog(),
    );

Future<RepositoryDraft?> showEditRepositoryDialog(
  BuildContext context,
  GitHubRepository repository,
) =>
    showDialog<RepositoryDraft>(
      context: context,
      builder: (context) => _EditRepositoryDialog(repository: repository),
    );

Future<bool?> showDeleteRepositoryDialog(
  BuildContext context,
  GitHubRepository repository,
) =>
    showDialog<bool>(
      context: context,
      builder: (context) => _DeleteRepositoryDialog(repository: repository),
    );

Future<RepositoryAction?> showRepositoryActionsSheet(
  BuildContext context,
  GitHubRepository repository,
) =>
    showDialog<RepositoryAction>(
      context: context,
      builder: (context) => _RepositoryActionsDialog(repository: repository),
    );

class _CreateRepositoryDialog extends StatefulWidget {
  const _CreateRepositoryDialog();

  @override
  State<_CreateRepositoryDialog> createState() => _CreateRepositoryDialogState();
}

class _CreateRepositoryDialogState extends State<_CreateRepositoryDialog> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _homepage = TextEditingController();
  bool _private = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _homepage.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        Icons.create_new_folder_outlined,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Novo repositório',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Fechar',
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _name,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Nome',
                    hintText: 'meu-projeto',
                    prefixIcon: Icon(Icons.folder_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _description,
                  decoration: const InputDecoration(
                    labelText: 'Descrição',
                    prefixIcon: Icon(Icons.notes_rounded),
                  ),
                  minLines: 2,
                  maxLines: 3,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _homepage,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Site / link relacionado',
                    hintText: 'https://exemplo.com',
                    prefixIcon: Icon(Icons.link_rounded),
                  ),
                ),
                const SizedBox(height: 6),
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 2),
                  title: const Text('Repositório privado'),
                  subtitle: Text(_private ? 'Somente pessoas autorizadas' : 'Visível publicamente'),
                  value: _private,
                  onChanged: (value) => setState(() => _private = value),
                ),
                const SizedBox(height: 6),
                Text(
                  'O repositório será inicializado e ficará pronto para receber arquivos e builds.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () {
                        if (_name.text.trim().isEmpty) {
                          return;
                        }
                        Navigator.pop(
                          context,
                          RepositoryDraft(
                            name: _name.text.trim(),
                            description: _description.text.trim(),
                            homepage: _homepage.text.trim(),
                            isPrivate: _private,
                          ),
                        );
                      },
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Criar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

}

class _EditRepositoryDialog extends StatefulWidget {
  const _EditRepositoryDialog({required this.repository});
  final GitHubRepository repository;

  @override
  State<_EditRepositoryDialog> createState() => _EditRepositoryDialogState();
}

class _EditRepositoryDialogState extends State<_EditRepositoryDialog> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _homepage;
  late bool _private;
  late bool _archived;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.repository.name);
    _description = TextEditingController(text: widget.repository.description ?? '');
    _homepage = TextEditingController(text: widget.repository.homepage ?? '');
    _private = widget.repository.isPrivate;
    _archived = widget.repository.isArchived;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _homepage.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 720),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        Icons.edit_outlined,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Editar repositório',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Fechar',
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _name,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Nome do repositório',
                    prefixIcon: Icon(Icons.folder_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _description,
                  decoration: const InputDecoration(
                    labelText: 'Descrição',
                    prefixIcon: Icon(Icons.notes_rounded),
                    alignLabelWithHint: true,
                  ),
                  minLines: 3,
                  maxLines: 5,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _homepage,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Site / link relacionado',
                    hintText: 'https://exemplo.com',
                    prefixIcon: Icon(Icons.link_rounded),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Endereço do GitHub',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        widget.repository.htmlUrl,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'O endereço acompanha automaticamente o nome do repositório.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 2),
                  title: const Text('Privado'),
                  subtitle: const Text('Limitar acesso às pessoas autorizadas'),
                  value: _private,
                  onChanged: (value) => setState(() => _private = value),
                ),
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 2),
                  title: const Text('Arquivado'),
                  subtitle: const Text('Deixar o repositório em modo somente leitura no GitHub'),
                  value: _archived,
                  onChanged: (value) => setState(() => _archived = value),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () {
                        if (_name.text.trim().isEmpty) return;
                        Navigator.pop(
                          context,
                          RepositoryDraft(
                            name: _name.text.trim(),
                            description: _description.text.trim(),
                            homepage: _homepage.text.trim(),
                            isPrivate: _private,
                            isArchived: _archived,
                          ),
                        );
                      },
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Salvar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

}

class _RepositoryActionsDialog extends StatelessWidget {
  const _RepositoryActionsDialog({required this.repository});
  final GitHubRepository repository;

  @override
  Widget build(BuildContext context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        Icons.settings_outlined,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Gerenciar repositório',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            repository.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Fechar',
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.edit_outlined),
                        title: const Text('Editar repositório'),
                        subtitle: const Text('Nome, descrição, visibilidade e arquivamento'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.pop(context, RepositoryAction.edit),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(
                          Icons.delete_forever_outlined,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        title: Text(
                          'Excluir permanentemente',
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                        ),
                        subtitle: const Text('A exclusão exige uma confirmação adicional'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.pop(context, RepositoryAction.delete),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _DeleteRepositoryDialog extends StatefulWidget {
  const _DeleteRepositoryDialog({required this.repository});
  final GitHubRepository repository;

  @override
  State<_DeleteRepositoryDialog> createState() => _DeleteRepositoryDialogState();
}

class _DeleteRepositoryDialogState extends State<_DeleteRepositoryDialog> {
  final _confirmation = TextEditingController();

  @override
  void dispose() {
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Excluir repositório?'),
        content: AdaptiveDialogBody(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Esta ação é permanente. Digite o nome abaixo para confirmar:'),
              const SizedBox(height: 8),
              SelectableText(widget.repository.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                controller: _confirmation,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'Nome do repositório'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: _confirmation.text.trim() == widget.repository.name
                ? () => Navigator.pop(context, true)
                : null,
            child: const Text('Excluir'),
          ),
        ],
      );
}
