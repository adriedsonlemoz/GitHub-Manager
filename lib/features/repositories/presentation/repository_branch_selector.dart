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
}) async {
  List<RepositoryBranch> branches;
  try {
    branches = await ref
        .read(repositoryGitServiceProvider)
        .listBranches(repositoryFullName);
  } catch (error) {
    if (context.mounted) {
      showCenteredNotice(
        context,
        error is AppException
            ? error.message
            : 'Não foi possível carregar as branches.',
      );
    }
    return null;
  }
  if (!context.mounted) return null;

  if (branches.isEmpty && emptyBranchName?.trim().isNotEmpty == true) {
    branches = [
      RepositoryBranch(
        name: emptyBranchName!.trim(),
        sha: '',
        isProtected: false,
      ),
    ];
  }

  RepositoryBranch? current;
  for (final branch in branches) {
    if (branch.name == currentBranch) {
      current = branch;
      break;
    }
  }
  if (current == null && branches.isNotEmpty) current = branches.first;
  if (current == null) return null;
  final selectedCurrent = current;

  return showModalBottomSheet<RepositoryBranch>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (sheetContext) => _RepositoryBranchSheet(
      repositoryFullName: repositoryFullName,
      branches: branches,
      current: selectedCurrent,
      defaultBranch: defaultBranch,
      repositoryIsEmpty: branches.length == 1 && branches.first.sha.isEmpty,
      allowCreate: allowCreate && branches.any((branch) => branch.sha.isNotEmpty),
      onCreate: (name) async {
        final created = await ref.read(repositoryGitServiceProvider).createBranch(
              repositoryFullName: repositoryFullName,
              branchName: name,
              sourceBranch: selectedCurrent.name,
            );
        return created;
      },
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

class _RepositoryBranchSheet extends StatefulWidget {
  const _RepositoryBranchSheet({
    required this.repositoryFullName,
    required this.branches,
    required this.current,
    required this.defaultBranch,
    required this.repositoryIsEmpty,
    required this.allowCreate,
    required this.onCreate,
  });

  final String repositoryFullName;
  final List<RepositoryBranch> branches;
  final RepositoryBranch current;
  final String? defaultBranch;
  final bool repositoryIsEmpty;
  final bool allowCreate;
  final Future<RepositoryBranch> Function(String name) onCreate;

  @override
  State<_RepositoryBranchSheet> createState() => _RepositoryBranchSheetState();
}

class _RepositoryBranchSheetState extends State<_RepositoryBranchSheet> {
  bool _creating = false;

  Future<void> _create() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Criar nova branch'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('A nova branch será criada a partir de ${widget.current.name}.'),
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
      final created = await widget.onCreate(name);
      if (mounted) Navigator.pop(context, created);
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
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .62,
      minChildSize: .38,
      maxChildSize: .88,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Escolher branch',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
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
                if (widget.allowCreate)
                  FilledButton.tonalIcon(
                    onPressed: _creating ? null : _create,
                    icon: _creating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_rounded),
                    label: const Text('Criar'),
                  ),
              ],
            ),
          ),
          if (widget.repositoryIsEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  'Este repositório ainda está vazio. O primeiro envio inicializará a branch ${widget.current.name}.',
                ),
              ),
            ),
          if (widget.branches.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Este repositório ainda não possui branches.'),
              ),
            )
          else
            ...widget.branches.map(
              (branch) => Card(
                child: ListTile(
                  leading: Icon(
                    branch.isProtected
                        ? Icons.lock_outline_rounded
                        : Icons.account_tree_outlined,
                  ),
                  title: Text(branch.name),
                  subtitle: (branch.isProtected || branch.name == widget.defaultBranch)
                      ? Text([
                          if (branch.name == widget.defaultBranch) 'padrão',
                          if (branch.isProtected) 'protegida',
                        ].join(' • '))
                      : null,
                  trailing: branch.name == widget.current.name
                      ? const Icon(Icons.check_circle_rounded)
                      : const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.pop(context, branch),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
