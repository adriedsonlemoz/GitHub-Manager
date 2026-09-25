import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:github_manager/core/errors/app_exception.dart';
import 'package:github_manager/core/widgets/centered_notice.dart';
import 'package:github_manager/features/repositories/domain/repository_git_models.dart';
import 'package:github_manager/features/repositories/presentation/repository_providers.dart';

Future<RepositoryBranch?> showRepositoryBranchSelector({
  required BuildContext context,
  required WidgetRef ref,
  required String repositoryFullName,
  required String currentBranch,
  String? defaultBranch,
  String? emptyBranchName,
  bool allowCreate = true,
}) {
  return showDialog<RepositoryBranch>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => _RepositoryBranchDialog(
      repositoryFullName: repositoryFullName,
      currentBranch: currentBranch,
      defaultBranch: defaultBranch,
      emptyBranchName: emptyBranchName,
      allowCreate: allowCreate,
      onLoad: () => ref
          .read(repositoryGitServiceProvider)
          .listBranches(repositoryFullName)
          .timeout(const Duration(seconds: 12)),
      onCreate: (name, sourceBranch) => ref
          .read(repositoryGitServiceProvider)
          .createBranch(
            repositoryFullName: repositoryFullName,
            branchName: name,
            sourceBranch: sourceBranch,
          )
          .timeout(const Duration(seconds: 15)),
    ),
  );
}

class RepositoryBranchButton extends StatelessWidget {
  const RepositoryBranchButton({
    required this.branch,
    required this.onPressed,
    this.compact = false,
    super.key,
  });

  final String branch;
  final VoidCallback onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.account_tree_outlined, size: 18),
      label: Text(
        branch,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      style: compact
          ? OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            )
          : null,
    );
  }
}

class _RepositoryBranchDialog extends StatefulWidget {
  const _RepositoryBranchDialog({
    required this.repositoryFullName,
    required this.currentBranch,
    required this.defaultBranch,
    required this.emptyBranchName,
    required this.allowCreate,
    required this.onLoad,
    required this.onCreate,
  });

  final String repositoryFullName;
  final String currentBranch;
  final String? defaultBranch;
  final String? emptyBranchName;
  final bool allowCreate;
  final Future<List<RepositoryBranch>> Function() onLoad;
  final Future<RepositoryBranch> Function(String name, String sourceBranch)
      onCreate;

  @override
  State<_RepositoryBranchDialog> createState() =>
      _RepositoryBranchDialogState();
}

class _RepositoryBranchDialogState extends State<_RepositoryBranchDialog> {
  List<RepositoryBranch> _branches = const [];
  RepositoryBranch? _current;
  bool _loading = true;
  bool _creating = false;
  bool _showOthers = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      var branches = await widget.onLoad();
      if (branches.isEmpty && widget.emptyBranchName?.trim().isNotEmpty == true) {
        branches = [
          RepositoryBranch(
            name: widget.emptyBranchName!.trim(),
            sha: '',
            isProtected: false,
          ),
        ];
      }

      RepositoryBranch? current;
      for (final branch in branches) {
        if (branch.name == widget.currentBranch) {
          current = branch;
          break;
        }
      }
      if (current == null && branches.isNotEmpty) current = branches.first;
      if (!mounted) return;
      setState(() {
        _branches = branches;
        _current = current;
        _loading = false;
        _showOthers = branches.length > 1 && _showOthers;
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'O GitHub demorou para responder. Tente novamente.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is AppException
            ? error.message
            : 'Não foi possível carregar as branches.';
      });
    }
  }

  Future<void> _create() async {
    final source = _current;
    if (source == null || source.sha.isEmpty) return;
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Criar nova branch'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('A nova branch será criada a partir de ${source.name}.'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Nome da branch',
                hintText: 'ex.: develop ou release/2.1',
              ),
              onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Criar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || !mounted) return;
    setState(() => _creating = true);
    try {
      final created = await widget.onCreate(name, source.name);
      if (mounted) Navigator.pop(context, created);
    } on TimeoutException {
      if (mounted) {
        showCenteredNotice(context, 'O GitHub demorou para criar a branch. Tente novamente.');
      }
    } catch (error) {
      if (mounted) {
        showCenteredNotice(
          context,
          error is AppException
              ? error.message
              : 'Não foi possível criar a branch.',
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final current = _current;
    final repositoryIsEmpty =
        _branches.length == 1 && _branches.first.sha.isEmpty;
    final canCreate = widget.allowCreate &&
        current != null &&
        current.sha.isNotEmpty &&
        !_loading;
    final others = current == null
        ? _branches
        : _branches.where((branch) => branch.name != current.name).toList();

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Branch de destino',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.repositoryFullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  if (canCreate)
                    FilledButton.tonalIcon(
                      onPressed: _creating ? null : _create,
                      icon: _creating
                          ? const SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Adicionar'),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: Icon(
                    current?.isProtected == true
                        ? Icons.lock_outline_rounded
                        : Icons.account_tree_outlined,
                  ),
                  title: Text(current?.name ?? widget.currentBranch),
                  subtitle: Text(
                    _loading
                        ? 'Carregando detalhes e outras branches…'
                        : repositoryIsEmpty
                            ? 'Repositório vazio • será criada no primeiro envio'
                            : [
                                if (current?.name == widget.defaultBranch) 'padrão',
                                if (current?.isProtected == true) 'protegida',
                                if (current?.name != widget.defaultBranch &&
                                    current?.isProtected != true)
                                  'selecionada',
                              ].join(' • '),
                  ),
                  trailing: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_rounded),
                  onTap: current == null ? null : () => Navigator.pop(context, current),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.wifi_off_rounded, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!)),
                      TextButton(
                        onPressed: _load,
                        child: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                ),
              ],
              if (!_loading && _error == null && others.isNotEmpty) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: const ValueKey('repository_branch_others_toggle'),
                    onPressed: () => setState(() => _showOthers = !_showOthers),
                    icon: Icon(
                      _showOthers
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                    ),
                    label: Text(
                      _showOthers
                          ? 'Ocultar outras branches'
                          : 'Outras branches (${others.length})',
                    ),
                  ),
                ),
              ],
              if (_showOthers && others.isNotEmpty) ...[
                const SizedBox(height: 6),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: others.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (context, index) {
                      final branch = others[index];
                      return ListTile(
                        key: ValueKey('repository_branch_${branch.name}'),
                        dense: true,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        tileColor: scheme.surfaceContainerLow,
                        leading: Icon(
                          branch.isProtected
                              ? Icons.lock_outline_rounded
                              : Icons.account_tree_outlined,
                          size: 20,
                        ),
                        title: Text(branch.name),
                        subtitle: (branch.isProtected ||
                                branch.name == widget.defaultBranch)
                            ? Text([
                                if (branch.name == widget.defaultBranch) 'padrão',
                                if (branch.isProtected) 'protegida',
                              ].join(' • '))
                            : null,
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.pop(context, branch),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
