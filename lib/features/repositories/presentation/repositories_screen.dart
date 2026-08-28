import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:github_manager/core/errors/app_exception.dart';
import 'package:github_manager/core/platform/platform_actions.dart';
import 'package:github_manager/core/widgets/app_error_card.dart';
import 'package:github_manager/core/widgets/app_main_navigation.dart';
import 'package:github_manager/core/widgets/centered_notice.dart';
import 'package:github_manager/features/auth/presentation/auth_providers.dart';
import 'package:github_manager/features/downloads/presentation/download_center_button.dart';
import 'package:github_manager/features/home/domain/github_profile.dart';
import 'package:github_manager/features/home/presentation/home_providers.dart';
import 'package:github_manager/features/home/presentation/github_profile_edit_dialog.dart';
import 'package:github_manager/features/permissions/domain/repository_permission_preflight.dart';
import 'package:github_manager/features/permissions/presentation/permission_preflight_guard.dart';
import 'package:github_manager/features/repositories/domain/github_repository.dart';
import 'package:github_manager/features/repositories/presentation/repository_card.dart';
import 'package:github_manager/features/repositories/presentation/repository_management_dialogs.dart';
import 'package:github_manager/features/repositories/presentation/repository_providers.dart';
import 'package:github_manager/features/setup/presentation/setup_wizard_screen.dart';
import 'package:github_manager/features/uploads/presentation/upload_center_button.dart';
import 'package:go_router/go_router.dart';

class RepositoriesScreen extends ConsumerStatefulWidget {
  const RepositoriesScreen({super.key});

  @override
  ConsumerState<RepositoriesScreen> createState() => _RepositoriesScreenState();
}

class _RepositoriesScreenState extends ConsumerState<RepositoriesScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String _filter = 'Todos';
  int _section = 0;

  bool get _showingFollowed => _section == 1;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<GitHubRepository> _applyFilters(List<GitHubRepository> source) {
    final query = _query.trim().toLowerCase();
    return source.where((repository) {
      if (_filter == 'Públicos' && repository.isPrivate) return false;
      if (_filter == 'Privados' && !repository.isPrivate) return false;
      if (_filter == 'Arquivados' && !repository.isArchived) return false;
      if (query.isEmpty) return true;
      return repository.name.toLowerCase().contains(query) ||
          repository.fullName.toLowerCase().contains(query) ||
          (repository.description?.toLowerCase().contains(query) ?? false);
    }).toList(growable: false);
  }

  Future<void> _refresh() async {
    if (_showingFollowed) {
      final refreshed =
          await ref.read(repositoryServiceProvider).refreshFollowedRepositories();
      ref.invalidate(followedRepositoriesProvider);
      if (mounted) {
        setState(() {});
      }
      if (refreshed.isEmpty) {
        await ref.read(followedRepositoriesProvider.future);
      }
    } else {
      ref.invalidate(repositoriesProvider);
      ref.invalidate(githubProfileProvider);
      await ref.read(repositoriesProvider.future);
    }
  }

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
      await _refresh();
      if (mounted) {
        showCenteredNotice(
          context,
          'Repositório ${created.name} criado com sucesso.',
          kind: CenteredNoticeKind.success,
        );
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

      await service.refreshFollowedRepositories();
      ref.invalidate(followedRepositoriesProvider);
      if (mounted) setState(() {});
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
        await _refresh();
        if (mounted) {
          showCenteredNotice(
            context,
            'Repositório ${updated.name} atualizado com sucesso.',
            kind: CenteredNoticeKind.success,
          );
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
        await _refresh();
        if (mounted) {
          showCenteredNotice(
            context,
            'Repositório ${repository.name} excluído com sucesso.',
            kind: CenteredNoticeKind.success,
          );
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
      ref.invalidate(repositoriesProvider);
      if (!mounted) return;
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
    ref.invalidate(followedRepositoriesProvider);
    if (mounted) {
      showCenteredNotice(
        context,
        '${repository.name} removido dos acompanhados.',
        kind: CenteredNoticeKind.success,
      );
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

  @override
  Widget build(BuildContext context) {
    final connection = ref.watch(githubConnectionProvider);
    return connection.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const Scaffold(body: SetupWizardScreen(embedded: true)),
      data: (connected) {
        if (!connected) {
          return const Scaffold(body: SetupWizardScreen(embedded: true));
        }
        return _connectedHome(context);
      },
    );
  }

  Widget _connectedHome(BuildContext context) {
    final repositories = _showingFollowed
        ? ref.watch(followedRepositoriesProvider)
        : ref.watch(repositoriesProvider);
    final profile = ref.watch(githubProfileProvider);
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      bottomNavigationBar: AppMainNavigation(selectedIndex: _showingFollowed ? 3 : 0),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              foregroundColor: scheme.onSurface,
              surfaceTintColor: Colors.transparent,
              shadowColor: Colors.transparent,
              scrolledUnderElevation: 0,
              forceMaterialTransparency: false,
              clipBehavior: Clip.hardEdge,
              toolbarHeight: 68,
              titleSpacing: 18,
              title: _showingFollowed
                  ? const Text('Acompanhados')
                  : Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'Meus ',
                            style: TextStyle(color: scheme.onSurface),
                          ),
                          TextSpan(
                            text: 'repositórios',
                            style: TextStyle(
                              color: dark ? const Color(0xFF8B80FF) : scheme.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
              actions: [
                IconButton(
                  onPressed: _showingFollowed ? _addFollowedRepository : _createRepository,
                  tooltip: _showingFollowed ? 'Acompanhar repositório' : 'Novo repositório',
                  icon: Icon(_showingFollowed ? Icons.bookmark_add_outlined : Icons.add_rounded),
                ),
                const UploadCenterButton(),
                const SizedBox(width: 4),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: [
                    SearchBar(
                      controller: _searchController,
                      hintText: _showingFollowed ? 'Pesquisar acompanhado' : 'Pesquisar projeto',
                      leading: const Icon(Icons.search_rounded),
                      trailing: _query.isEmpty
                          ? null
                          : [
                              IconButton(
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _query = '');
                                },
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ],
                      onChanged: (value) => setState(() => _query = value),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 43,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: 4,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final value = const ['Todos', 'Públicos', 'Privados', 'Arquivados'][index];
                          return ChoiceChip(
                            label: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(value),
                            ),
                            selected: _filter == value,
                            onSelected: (_) => setState(() => _filter = value),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            repositories.when(
              loading: () => const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => SliverPadding(
                padding: const EdgeInsets.all(14),
                sliver: SliverToBoxAdapter(
                  child: AppErrorCard(error: error, onRetry: _refresh),
                ),
              ),
              data: (items) {
                final filtered = _applyFilters(items);
                if (filtered.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Text(
                          _showingFollowed
                              ? 'Nenhum repositório acompanhado. Use + para adicionar quantos quiser.'
                              : 'Nenhum projeto encontrado.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
                  sliver: SliverList.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final repository = filtered[index];
                      return RepositoryCard(
                        repository: repository,
                        readOnly: _showingFollowed,
                        onTap: () => context.push(
                          '/repositories/${repository.fullName}?readOnly=${_showingFollowed ? '1' : '0'}',
                        ),
                        onMenu: _showingFollowed
                            ? () => _removeFollowed(repository)
                            : () => _manageRepository(repository),
                        onOpenExternal: () => PlatformActions.openUri(repository.htmlUrl),
                        onCopyLink: () => _copyLink(repository),
                        onFork: _showingFollowed
                            ? () => _forkFollowed(repository)
                            : null,
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
