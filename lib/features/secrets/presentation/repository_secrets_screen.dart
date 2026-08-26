import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:github_manager/core/errors/app_exception.dart';
import 'package:github_manager/core/widgets/adaptive_dialog.dart';
import 'package:github_manager/features/secrets/data/repository_secrets_service.dart';
import 'package:github_manager/features/secrets/domain/repository_secret.dart';
import 'package:github_manager/features/secrets/presentation/secrets_providers.dart';

class RepositorySecretsScreen extends ConsumerStatefulWidget {
  const RepositorySecretsScreen({required this.repositoryFullName, super.key});

  final String repositoryFullName;

  @override
  ConsumerState<RepositorySecretsScreen> createState() =>
      _RepositorySecretsScreenState();
}

class _RepositorySecretsScreenState
    extends ConsumerState<RepositorySecretsScreen> {
  bool _working = false;

  Future<void> _refresh() async {
    ref.invalidate(repositorySecretsProvider(widget.repositoryFullName));
    await ref.read(repositorySecretsProvider(widget.repositoryFullName).future);
  }

  Future<void> _pasteInto(TextEditingController controller) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) {
      return;
    }
    controller
      ..text = text.trim()
      ..selection = TextSelection.collapsed(offset: controller.text.length);
  }

  Future<void> _manualSecret() async {
    final name = TextEditingController();
    final value = TextEditingController();
    var obscure = true;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Adicionar ou substituir Secret'),
          content: AdaptiveDialogBody(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: 'Nome',
                      hintText: 'KEYSTORE_PASSWORD',
                      suffixIcon: IconButton(
                        onPressed: () => _pasteInto(name),
                        tooltip: 'Colar',
                        icon: const Icon(Icons.content_paste_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: value,
                    obscureText: obscure,
                    minLines: 1,
                    maxLines: 4,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: 'Novo valor',
                      helperText:
                          'Criptografado no aparelho; o GitHub não devolve o valor depois.',
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () => _pasteInto(value),
                            tooltip: 'Colar',
                            icon: const Icon(Icons.content_paste_rounded),
                          ),
                          IconButton(
                            onPressed: () =>
                                setDialogState(() => obscure = !obscure),
                            tooltip: obscure ? 'Exibir' : 'Ocultar',
                            icon: Icon(
                              obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    if (result == true && mounted && name.text.trim().isNotEmpty) {
      await _run(
        () => ref.read(repositorySecretsServiceProvider).putSecret(
              repositoryFullName: widget.repositoryFullName,
              name: name.text,
              value: value.text,
            ),
      );
    }
    name.dispose();
    value.dispose();
  }

  Future<void> _pasteMany() async {
    final controller = TextEditingController();
    await _pasteInto(controller);
    if (!mounted) {
      controller.dispose();
      return;
    }
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Colar vários Secrets'),
        content: AdaptiveDialogBody(
          child: TextField(
            controller: controller,
            autofocus: true,
            minLines: 7,
            maxLines: 14,
            autocorrect: false,
            enableSuggestions: false,
            style: const TextStyle(fontFamily: 'monospace'),
            decoration: InputDecoration(
              hintText: 'TOKEN=valor\nKEYSTORE_PASSWORD=valor',
              helperText:
                  'Formato .env/TXT. Linhas iniciadas por # são ignoradas.',
              suffixIcon: IconButton(
                onPressed: () => _pasteInto(controller),
                tooltip: 'Colar',
                icon: const Icon(Icons.content_paste_rounded),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Importar'),
          ),
        ],
      ),
    );
    if (result == true && mounted) {
      try {
        final values = RepositorySecretsService.parseText(controller.text);
        if (values.isEmpty) {
          throw const FormatException('Nenhum Secret válido encontrado.');
        }
        await _putMany(values);
      } catch (error) {
        if (mounted) {
          _showError(error);
        }
      }
    }
    controller.dispose();
  }

  Future<void> _importFile() async {
    try {
      final service = ref.read(repositorySecretsServiceProvider);
      final file = await service.pickImportFile();
      if (file == null || !mounted) {
        return;
      }
      final values = await service.parseImportFile(file);
      if (values.isEmpty) {
        throw const FormatException(
          'O arquivo não contém Secrets reconhecíveis.',
        );
      }
      await _putMany(values);
    } catch (error) {
      if (mounted) {
        _showError(error);
      }
    }
  }

  Future<void> _putMany(Map<String, String> values) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Importar ${values.length} Secrets?'),
        content: AdaptiveDialogBody(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Secrets com o mesmo nome serão substituídos. O GitHub Manager nunca tenta recuperar valores já salvos.',
                ),
                const SizedBox(height: 10),
                ...values.keys.take(20).map((name) => Text('• $name')),
                if (values.length > 20) Text('… e mais ${values.length - 20}'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Importar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await _run(() async {
      final count = await ref.read(repositorySecretsServiceProvider).putMany(
            repositoryFullName: widget.repositoryFullName,
            values: values,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$count Secrets salvos.')),
        );
      }
    });
  }

  Future<void> _delete(RepositorySecret secret) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Excluir ${secret.name}?'),
        content: const AdaptiveDialogBody(
          child: Text('O valor não poderá ser recuperado depois da exclusão.'),
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
    if (confirmed != true || !mounted) {
      return;
    }
    await _run(
      () => ref.read(repositorySecretsServiceProvider).deleteSecret(
            repositoryFullName: widget.repositoryFullName,
            name: secret.name,
          ),
    );
  }

  Future<void> _replace(RepositorySecret secret) async {
    final controller = TextEditingController();
    var obscure = true;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Substituir ${secret.name}'),
          content: AdaptiveDialogBody(
            child: TextField(
              controller: controller,
              obscureText: obscure,
              autofocus: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: 'Novo valor',
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () => _pasteInto(controller),
                      tooltip: 'Colar',
                      icon: const Icon(Icons.content_paste_rounded),
                    ),
                    IconButton(
                      onPressed: () => setDialogState(() => obscure = !obscure),
                      tooltip: obscure ? 'Exibir' : 'Ocultar',
                      icon: Icon(
                        obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Substituir'),
            ),
          ],
        ),
      ),
    );
    if (result == true && mounted) {
      await _run(
        () => ref.read(repositorySecretsServiceProvider).putSecret(
              repositoryFullName: widget.repositoryFullName,
              name: secret.name,
              value: controller.text,
            ),
      );
    }
    controller.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_working) {
      return;
    }
    setState(() => _working = true);
    try {
      await action();
      await _refresh();
    } catch (error) {
      if (mounted) {
        _showError(error);
      }
    } finally {
      if (mounted) {
        setState(() => _working = false);
      }
    }
  }

  void _showError(Object error) {
    final message = error is GitHubPermissionException
        ? 'O token precisa permitir alteração de Secrets neste repositório.'
        : error is FormatException
            ? error.message
            : error is AppException
                ? error.message
                : 'Não foi possível concluir a operação de Secrets.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final secrets = ref.watch(
      repositorySecretsProvider(widget.repositoryFullName),
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('GitHub Secrets'),
        actions: [
          IconButton(
            onPressed: _working ? null : _refresh,
            tooltip: 'Atualizar',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(8, 2, 8, 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .secondaryContainer
                  .withValues(alpha: .5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              'O GitHub mostra somente nome e datas. Para trocar um valor, salve novamente usando o mesmo nome.',
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  onPressed: _working ? null : _importFile,
                  icon: const Icon(Icons.file_upload_outlined),
                  label: const Text('Importar arquivo de Secrets'),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _working ? null : _manualSecret,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Adicionar'),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _working ? null : _pasteMany,
                        icon: const Icon(Icons.content_paste_rounded),
                        label: const Text('Colar vários'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: secrets.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => ListView(
                padding: const EdgeInsets.all(10),
                children: [
                  Text(
                    error is AppException
                        ? error.message
                        : 'Não foi possível listar os Secrets.',
                  ),
                ],
              ),
              data: (items) => items.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      children: const [
                        Center(child: Text('Nenhum Secret cadastrado.')),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 20),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 5),
                      itemBuilder: (context, index) {
                        final secret = items[index];
                        return Card(
                          child: ListTile(
                            dense: true,
                            leading: const Icon(Icons.key_rounded),
                            title: Text(secret.name),
                            subtitle: Text(
                              'Atualizado: ${_formatDate(secret.updatedAt)}',
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (action) {
                                if (action == 'replace') {
                                  _replace(secret);
                                } else if (action == 'delete') {
                                  _delete(secret);
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'replace',
                                  child: Text('Substituir valor'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Excluir'),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime? date) {
    if (date == null) {
      return '-';
    }
    final local = date.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}
