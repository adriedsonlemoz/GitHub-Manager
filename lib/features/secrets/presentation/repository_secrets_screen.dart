import 'package:flutter/material.dart';
import 'package:github_manager/core/widgets/app_main_navigation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:github_manager/core/errors/app_exception.dart';
import 'package:github_manager/core/widgets/adaptive_dialog.dart';
import 'package:github_manager/core/widgets/centered_notice.dart';
import 'package:github_manager/features/permissions/domain/repository_permission_preflight.dart';
import 'package:github_manager/features/permissions/presentation/permission_preflight_guard.dart';
import 'package:github_manager/features/secrets/data/repository_secrets_service.dart';
import 'package:github_manager/features/secrets/domain/repository_secret.dart';
import 'package:github_manager/features/secrets/presentation/secrets_providers.dart';
import 'package:go_router/go_router.dart';

class RepositorySecretsScreen extends ConsumerStatefulWidget {
  const RepositorySecretsScreen({required this.repositoryFullName, super.key});

  final String repositoryFullName;

  @override
  ConsumerState<RepositorySecretsScreen> createState() =>
      _RepositorySecretsScreenState();
}

class _RepositorySecretsScreenState extends ConsumerState<RepositorySecretsScreen> {
  bool _working = false;

  Future<void> _refresh() async {
    ref.invalidate(repositorySecretsProvider(widget.repositoryFullName));
    await ref.read(repositorySecretsProvider(widget.repositoryFullName).future);
  }

  Future<void> _pasteInto(TextEditingController controller) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) return;
    controller
      ..text = text.trim()
      ..selection = TextSelection.collapsed(offset: controller.text.length);
  }

  Future<void> _manualSecret() async {
    final allowed = await ensureRepositoryPermission(
      context,
      ref,
      repositoryFullName: widget.repositoryFullName,
      action: RepositoryCriticalAction.manageSecrets,
    );
    if (!allowed || !mounted) return;
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
                    maxLines: 5,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: 'Novo valor',
                      helperText:
                          'Máximo 48 KB. O valor é criptografado no aparelho e nunca aparece nos diagnósticos.',
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () => _pasteInto(value),
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
        successMessage: 'Secret salvo.',
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
            minLines: 8,
            maxLines: 16,
            autocorrect: false,
            enableSuggestions: false,
            style: const TextStyle(fontFamily: 'monospace'),
            decoration: InputDecoration(
              hintText:
                  'TOKEN=valor\nKEYSTORE_PASSWORD: valor\nexport KEY_ALIAS=alias',
              helperText:
                  'Aceita NOME=valor, NOME: valor e export NOME=valor. Comentários com # ou // são ignorados.',
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
            child: const Text('Analisar'),
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
        if (mounted) _showError(error);
      }
    }
    controller.dispose();
  }

  Future<void> _importFile() async {
    try {
      final service = ref.read(repositorySecretsServiceProvider);
      final file = await service.pickImportFile();
      if (file == null || !mounted) return;
      final values = await service.parseImportFile(file);
      if (!mounted) return;
      if (values.isEmpty) {
        throw const FormatException('O arquivo não contém Secrets reconhecíveis.');
      }
      await _putMany(values);
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<void> _putMany(Map<String, String> values) async {
    if (_working) return;
    final allowed = await ensureRepositoryPermission(
      context,
      ref,
      repositoryFullName: widget.repositoryFullName,
      action: RepositoryCriticalAction.manageSecrets,
    );
    if (!allowed || !mounted) return;
    setState(() => _working = true);
    final SecretImportPlan plan;
    try {
      plan = await ref.read(repositorySecretsServiceProvider).prepareImport(
            repositoryFullName: widget.repositoryFullName,
            values: values,
          );
    } catch (error) {
      if (mounted) _showError(error);
      if (mounted) setState(() => _working = false);
      return;
    }
    if (mounted) setState(() => _working = false);
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Revisar ${plan.total} Secrets'),
        content: AdaptiveDialogBody(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SummaryCard(plan: plan),
                const SizedBox(height: 12),
                const Text(
                  'O GitHub Manager validou nomes, tamanho e limite do repositório. Nenhum valor é exibido nesta tela.',
                ),
                const SizedBox(height: 12),
                ...plan.items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Icon(
                          item.kind == SecretMutationKind.create
                              ? Icons.add_circle_outline_rounded
                              : Icons.sync_rounded,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Text(
                          item.kind == SecretMutationKind.create
                              ? 'Criar'
                              : 'Substituir',
                        ),
                        const SizedBox(width: 8),
                        Text(_formatBytes(item.utf8Bytes)),
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
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.lock_rounded),
            label: const Text('Criptografar e salvar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _working = true);
    try {
      final result = await ref.read(repositorySecretsServiceProvider).putMany(
            repositoryFullName: widget.repositoryFullName,
            values: values,
            preparedPlan: plan,
          );
      if (mounted) await _showBatchResult(result);
      if (mounted) {
        ref.invalidate(repositorySecretsProvider(widget.repositoryFullName));
      }
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _showBatchResult(SecretBatchResult result) async {
    final colorScheme = Theme.of(context).colorScheme;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(
              result.allSucceeded
                  ? Icons.check_circle_rounded
                  : result.saved > 0
                      ? Icons.warning_amber_rounded
                      : Icons.error_outline_rounded,
              color: result.allSucceeded
                  ? colorScheme.primary
                  : colorScheme.error,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                result.allSucceeded
                    ? 'Secrets salvos'
                    : result.saved > 0
                        ? 'Importação parcial'
                        : 'Falha ao salvar Secrets',
              ),
            ),
          ],
        ),
        content: AdaptiveDialogBody(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${result.saved} salvos • ${result.failed} falharam • ${result.total} analisados',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Os valores nunca são incluídos no resultado nem no diagnóstico copiável.',
                ),
                const SizedBox(height: 14),
                ...result.items.map(
                  (item) => Container(
                    margin: const EdgeInsets.only(bottom: 5),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ListTile(
                      dense: true,
                      visualDensity: const VisualDensity(vertical: -2),
                      leading: Icon(
                        item.success
                            ? Icons.check_circle_outline_rounded
                            : Icons.error_outline_rounded,
                        color: item.success ? colorScheme.primary : colorScheme.error,
                      ),
                      title: Text(item.name),
                      subtitle: Text(
                        item.success
                            ? item.message
                            : [
                                item.message,
                                if (item.httpStatus != null) 'HTTP ${item.httpStatus}',
                                if (item.apiMessage?.isNotEmpty == true)
                                  'GitHub: ${item.apiMessage}',
                              ].join('\n'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(
                  text: result.diagnosticText(
                    repositoryFullName: widget.repositoryFullName,
                  ),
                ),
              );
              if (dialogContext.mounted) {
                showCenteredNotice(dialogContext, 'Diagnóstico copiado.');
              }
            },
            icon: const Icon(Icons.copy_rounded),
            label: const Text('Copiar diagnóstico'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(RepositorySecret secret) async {
    final allowed = await ensureRepositoryPermission(
      context,
      ref,
      repositoryFullName: widget.repositoryFullName,
      action: RepositoryCriticalAction.manageSecrets,
    );
    if (!allowed || !mounted) return;
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
    if (confirmed != true || !mounted) return;
    await _run(
      () => ref.read(repositorySecretsServiceProvider).deleteSecret(
            repositoryFullName: widget.repositoryFullName,
            name: secret.name,
          ),
      successMessage: 'Secret excluído.',
    );
  }

  Future<void> _replace(RepositorySecret secret) async {
    final allowed = await ensureRepositoryPermission(
      context,
      ref,
      repositoryFullName: widget.repositoryFullName,
      action: RepositoryCriticalAction.manageSecrets,
    );
    if (!allowed || !mounted) return;
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
                helperText: 'Máximo 48 KB.',
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
        successMessage: 'Secret substituído.',
      );
    }
    controller.dispose();
  }

  Future<void> _run(
    Future<void> Function() action, {
    String? successMessage,
  }) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      await action();
      await _refresh();
      if (mounted && successMessage != null) {
        showCenteredNotice(context, successMessage);
      }
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _showError(Object error) {
    if (error is AppException &&
        (error.httpStatus != null ||
            error.endpoint?.isNotEmpty == true ||
            error.apiMessage?.isNotEmpty == true)) {
      _showDetailedError(error);
      return;
    }
    final message = error is GitHubPermissionException
        ? 'Permissão insuficiente. Token fine-grained: habilite Secrets: Read and write. Token clássico: use repo.'
        : error is FormatException
            ? error.message
            : error is AppException
                ? error.message
                : 'Não foi possível concluir a operação de Secrets.';
    showCenteredNotice(context, message);
  }

  Future<void> _showDetailedError(AppException error) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Não foi possível concluir'),
        content: AdaptiveDialogBody(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  error is GitHubPermissionException
                      ? 'O token não possui a permissão necessária. Para Secrets, use Secrets: Read and write em token fine-grained ou repo em token clássico.'
                      : error.message,
                ),
                const SizedBox(height: 14),
                if (error.httpStatus != null) Text('HTTP: ${error.httpStatus}'),
                if (error.technicalCode != null)
                  Text('Código: ${error.technicalCode}'),
                if (error.endpoint?.isNotEmpty == true)
                  Text('Endpoint: ${error.endpoint}'),
                if (error.apiMessage?.isNotEmpty == true)
                  Text('GitHub: ${error.apiMessage}'),
                const SizedBox(height: 10),
                const Text(
                  'Nenhum valor de Secret é incluído nestes detalhes.',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final secrets =
        ref.watch(repositorySecretsProvider(widget.repositoryFullName));
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      bottomNavigationBar: const AppMainNavigation(selectedIndex: 0),
      appBar: AppBar(
        title: const Text('Secrets'),
        actions: [
          IconButton(
            onPressed: _working ? null : _refresh,
            tooltip: 'Atualizar',
            icon: _working
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 3, 12, 5),
            child: Row(
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 16,
                  color: scheme.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Valores protegidos • até 48 KB por Secret',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ),
                Tooltip(
                  message:
                      'O GitHub exibe apenas nome e datas. Os valores não são mostrados nos diagnósticos.',
                  child: Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 3, 10, 7),
            child: Row(
              children: [
                Expanded(
                  child: _SecretQuickAction(
                    icon: Icons.add_rounded,
                    label: 'Adicionar',
                    onPressed: _working ? null : _manualSecret,
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: _SecretQuickAction(
                    icon: Icons.file_upload_outlined,
                    label: 'Importar',
                    filled: true,
                    onPressed: _working ? null : _importFile,
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: _SecretQuickAction(
                    icon: Icons.content_paste_rounded,
                    label: 'Colar',
                    onPressed: _working ? null : _pasteMany,
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: _SecretQuickAction(
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
          Expanded(
            child: secrets.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (error, _) => ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 88),
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: error is GitHubPermissionException
                          ? scheme.errorContainer.withValues(alpha: .35)
                          : scheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          error is GitHubPermissionException
                              ? 'Permissão insuficiente para listar Secrets.'
                              : error is AppException
                                  ? error.message
                                  : 'Não foi possível listar os Secrets.',
                        ),
                        if (error is GitHubPermissionException) ...[
                          const SizedBox(height: 7),
                          TextButton.icon(
                            onPressed: () => context.push(
                              '/repositories/${widget.repositoryFullName}/permissions',
                            ),
                            icon: const Icon(
                              Icons.verified_user_outlined,
                              size: 17,
                            ),
                            label: const Text('Diagnosticar'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              data: (items) {
                if (items.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(12, 24, 12, 88),
                    children: [
                      Icon(
                        Icons.key_off_outlined,
                        size: 30,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          'Nenhum Secret cadastrado.',
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
                  padding: const EdgeInsets.fromLTRB(10, 3, 10, 88),
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: 3),
                  itemBuilder: (context, index) {
                    final secret = items[index];
                    return Material(
                      color: scheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(11),
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        dense: true,
                        visualDensity: const VisualDensity(vertical: -2),
                        contentPadding:
                            const EdgeInsets.fromLTRB(10, 1, 2, 1),
                        leading: Container(
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer
                                .withValues(alpha: .5),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Icon(
                            Icons.key_rounded,
                            size: 18,
                            color: scheme.primary,
                          ),
                        ),
                        title: Text(
                          secret.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: Text(
                          'Atualizado ${_formatDate(secret.updatedAt)}',
                          maxLines: 1,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        trailing: PopupMenuButton<String>(
                          tooltip: 'Ações',
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime? date) {
    if (date == null) return '-';
    final local = date.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    return '${kb.toStringAsFixed(kb >= 10 ? 0 : 1)} KB';
  }
}

class _SecretQuickAction extends StatelessWidget {
  const _SecretQuickAction({
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
        EdgeInsets.symmetric(horizontal: 4, vertical: 7),
      ),
      visualDensity: VisualDensity.compact,
      textStyle: WidgetStatePropertyAll(
        Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
      ),
    );

    return filled
        ? FilledButton.tonalIcon(
            onPressed: onPressed,
            style: style,
            icon: Icon(icon, size: 16),
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
            icon: Icon(icon, size: 16),
            label: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
            ),
          );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.plan});

  final SecretImportPlan plan;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            Text('${plan.createCount} criar'),
            Text('${plan.updateCount} substituir'),
            Text('${plan.existingCount} existentes'),
            Text('${plan.finalCount}/100 após salvar'),
          ],
        ),
      );
}
