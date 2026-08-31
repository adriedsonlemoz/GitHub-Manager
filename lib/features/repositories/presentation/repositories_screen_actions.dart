part of 'repositories_screen.dart';

mixin _RepositoriesScreenActions on ConsumerState<RepositoriesScreen> {
  int get _section;
  set _section(int value);
  Future<void> _refresh();

  Future<void> _editGitHubProfile(GitHubProfile profile) async {
    final draft = await showGitHubProfileEditDialog(context, profile);
    if (draft == null || !mounted) return;
    try {
      await ref.read(githubProfileRepositoryProvider).updateProfile(
            name: draft.name,
            email: draft.email,
            blog: draft.blog,
            twitterUsername: draft.twitterUsername,
            company: draft.company,
            location: draft.location,
            bio: draft.bio,
            hireable: draft.hireable,
          );
      ref.invalidate(githubProfileProvider);
      if (mounted) {
        showCenteredNotice(
          context,
          'Perfil atualizado no GitHub.',
          kind: CenteredNoticeKind.success,
        );
      }
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<void> _createRepository() async {
    final result = await showCreateRepositoryDialog(context);
    if (result == null || !mounted) return;
    try {
      final created = await ref.read(repositoryServiceProvider).createRepository(
            name: result.name,
            description: result.description,
            homepage: result.homepage,
            isPrivate: result.isPrivate,
          );
      if (mounted) {
        setState(() => _section = 0);
        showCenteredNotice(
          context,
          'Repositório ${created.name} criado com sucesso.',
          kind: CenteredNoticeKind.success,
        );
        await _refresh();
      }
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<void> _addFollowedRepository() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bookmark_add_outlined),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Acompanhar repositório',
                        style: Theme.of(dialogContext).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: 'Link ou owner/repo',
                    hintText: 'https://github.com/termux/termux-app',
                    prefixIcon: const Icon(Icons.link_rounded),
                    suffixIcon: IconButton(
                      tooltip: 'Colar URL',
                      icon: const Icon(Icons.content_paste_rounded),
                      onPressed: () async {
                        final data = await Clipboard.getData(Clipboard.kTextPlain);
                        final text = data?.text?.trim();
                        if (text != null && text.isNotEmpty) {
                          controller
                            ..text = text
                            ..selection = TextSelection.collapsed(offset: text.length);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Cole owner/repo ou a URL do repositório. Se colar apenas um perfil, como github.com/usuario, você poderá escolher um repositório público dessa conta.',
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () {
                        final text = controller.text.trim();
                        if (text.isNotEmpty) Navigator.pop(dialogContext, text);
                      },
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Adicionar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    controller.dispose();
    if (value == null || !mounted) return;
    try {
      final service = ref.read(repositoryServiceProvider);
      GitHubRepository repository;
      try {
        repository = await service.followRepository(value);
      } on FormatException catch (directError) {
        try {
          final candidates = await service.listOwnerRepositoriesFromReference(value);
          if (!mounted) return;
          if (candidates.isEmpty) {
            showCenteredNotice(
              context,
              'Esse perfil não possui repositórios públicos para acompanhar.',
            );
            return;
          }
          final selected = await _selectRepositoryFromProfile(candidates);
          if (selected == null || !mounted) return;
          repository = await service.followRepository(selected.fullName);
        } on GitHubNotFoundException {
          if (mounted) {
            showCenteredNotice(
              context,
              'Perfil do GitHub não encontrado. Confira o nome de usuário no link.',
            );
          }
          return;
        } on FormatException {
          throw directError;
        }
      }

      await ref.refresh(followedRepositoriesProvider.future);
      if (mounted) {
        showCenteredNotice(
          context,
          '${repository.name} adicionado aos acompanhados.',
          kind: CenteredNoticeKind.success,
        );
      }
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<GitHubRepository?> _selectRepositoryFromProfile(
    List<GitHubRepository> repositories,
  ) =>
      showDialog<GitHubRepository>(
        context: context,
        builder: (dialogContext) {
          final screen = MediaQuery.sizeOf(dialogContext);
          return Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 520,
                maxHeight: screen.height * .78 < 680.0 ? screen.height * .78 : 680.0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 8, 8),
                    child: Row(
                      children: [
                        const Icon(Icons.person_search_outlined),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Perfil do GitHub detectado',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                              ),
                              SizedBox(height: 2),
                              Text('Escolha qual repositório deseja acompanhar.'),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Flexible(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      itemCount: repositories.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final repository = repositories[index];
                        return ListTile(
                          leading: Icon(
                            repository.isPrivate
                                ? Icons.lock_outline_rounded
                                : Icons.bookmark_border_rounded,
                          ),
                          title: Text(repository.name),
                          subtitle: Text(
                            repository.description?.trim().isNotEmpty == true
                                ? repository.description!
                                : repository.fullName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => Navigator.pop(dialogContext, repository),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );

  Future<void> _manageRepository(GitHubRepository repository) async {
    final action = await showRepositoryActionsSheet(context, repository);
    if (action == null || !mounted) return;
    if (action == RepositoryAction.edit) {
      final result = await showEditRepositoryDialog(context, repository);
      if (result == null || !mounted) return;
      try {
        final updated = await ref.read(repositoryServiceProvider).updateRepository(
              fullName: repository.fullName,
              name: result.name,
              description: result.description,
              homepage: result.homepage,
              isPrivate: result.isPrivate,
              isArchived: result.isArchived,
            );
        if (mounted) {
          showCenteredNotice(
            context,
            'Repositório ${updated.name} atualizado com sucesso.',
            kind: CenteredNoticeKind.success,
          );
          await _refresh();
        }
      } catch (error) {
        if (mounted) _showError(error);
      }
    } else if (action == RepositoryAction.rename) {
      final newName = await showRenameRepositoryDialog(context, repository);
      if (newName == null || !mounted) return;
      try {
        final renamed = await ref.read(repositoryServiceProvider).renameRepository(
              fullName: repository.fullName,
              newName: newName,
            );
        ref
            .read(permissionPreflightServiceProvider)
            .invalidateRepository(repository.fullName);
        ref.invalidate(repositoryProjectInfoProvider(repository));
        if (mounted) {
          showCenteredNotice(
            context,
            'Repositório renomeado para ${renamed.name}.',
            kind: CenteredNoticeKind.success,
          );
          await _refresh();
        }
      } catch (error) {
        if (mounted) _showError(error);
      }
    } else if (action == RepositoryAction.delete) {
      final allowed = await ensureRepositoryPermission(
        context,
        ref,
        repositoryFullName: repository.fullName,
        action: RepositoryCriticalAction.deleteRepository,
      );
      if (!allowed || !mounted) return;
      final confirmed = await showDeleteRepositoryDialog(context, repository);
      if (confirmed != true || !mounted) return;
      try {
        await ref.read(repositoryServiceProvider).deleteRepository(repository.fullName);
        if (mounted) {
          showCenteredNotice(
            context,
            'Repositório ${repository.name} excluído com sucesso.',
            kind: CenteredNoticeKind.success,
          );
          await _refresh();
        }
      } catch (error) {
        if (mounted) _showError(error);
      }
    }
  }

  Future<void> _forkFollowed(GitHubRepository repository) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Criar fork na minha conta?'),
        content: Text(
          'O GitHub criará uma cópia de ${repository.fullName} na sua conta. '
          'Depois ela aparecerá em Meus repositórios e poderá ser editada normalmente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.call_split_rounded),
            label: const Text('Criar fork'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final fork = await ref.read(repositoryServiceProvider).forkRepository(
            repository.fullName,
          );
      if (!mounted) return;
      if (fork.fullName.isNotEmpty) {
      }
      showCenteredNotice(context, fork.fullName.isEmpty
                ? 'Fork solicitado ao GitHub. Ele pode levar alguns segundos para aparecer.'
                : 'Fork criado: ${fork.fullName}');
      setState(() => _section = 0);
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<void> _removeFollowed(GitHubRepository repository) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remover dos acompanhados?'),
        content: Text(
          '${repository.fullName} será removido apenas do GitHub Manager. Nada será apagado no GitHub.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(repositoryServiceProvider).unfollowRepository(repository.fullName);
    if (mounted) {
      showCenteredNotice(
        context,
        '${repository.name} removido dos acompanhados.',
        kind: CenteredNoticeKind.success,
      );
      await _refresh();
    }
  }

  Future<void> _copyLink(GitHubRepository repository) async {
    await Clipboard.setData(ClipboardData(text: repository.htmlUrl));
    if (mounted) {
      showCenteredNotice(context, 'Link do repositório copiado.');
    }
  }

  void _showError(Object error) {
    final message = error is AppException
        ? error.message
        : error is FormatException
            ? error.message
            : 'Não foi possível concluir a operação.';
    showCenteredNotice(context, message);
  }
}
