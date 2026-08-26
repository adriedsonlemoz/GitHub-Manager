import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:github_manager/core/errors/app_exception.dart';
import 'package:github_manager/core/platform/platform_actions.dart';
import 'package:github_manager/core/widgets/app_error_card.dart';
import 'package:github_manager/features/auth/presentation/auth_providers.dart';
import 'package:github_manager/features/downloads/presentation/download_center_button.dart';
import 'package:github_manager/features/home/presentation/home_providers.dart';
import 'package:github_manager/features/repositories/domain/github_repository.dart';
import 'package:github_manager/features/repositories/presentation/repository_card.dart';
import 'package:github_manager/features/repositories/presentation/repository_management_dialogs.dart';
import 'package:github_manager/features/repositories/presentation/repository_providers.dart';
import 'package:github_manager/features/setup/presentation/setup_wizard_screen.dart';
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
      ref.invalidate(followedRepositoriesProvider);
      await ref.read(followedRepositoriesProvider.future);
    } else {
      ref.invalidate(repositoriesProvider);
      ref.invalidate(githubProfileProvider);
      await ref.read(repositoriesProvider.future);
    }
  }

  Future<void> _createRepository() async {
    final result = await showCreateRepositoryDialog(context);
    if (result == null || !mounted) return;
    try {
      await ref.read(repositoryServiceProvider).createRepository(
            name: result.name,
            description: result.description,
            homepage: result.homepage,
            isPrivate: result.isPrivate,
          );
      await _refresh();
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
                  decoration: const InputDecoration(
                    labelText: 'Link ou owner/repo',
                    hintText: 'https://github.com/termux/termux-app',
                    prefixIcon: Icon(Icons.link_rounded),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'O repositório será salvo somente como referência local e aberto em modo somente leitura.',
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
      await ref.read(repositoryServiceProvider).followRepository(value);
      ref.invalidate(followedRepositoriesProvider);
      await ref.read(followedRepositoriesProvider.future);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Repositório adicionado aos acompanhados.')),
        );
      }
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<void> _manageRepository(GitHubRepository repository) async {
    final action = await showRepositoryActionsSheet(context, repository);
    if (action == null || !mounted) return;
    if (action == RepositoryAction.edit) {
      final result = await showEditRepositoryDialog(context, repository);
      if (result == null || !mounted) return;
      try {
        await ref.read(repositoryServiceProvider).updateRepository(
              fullName: repository.fullName,
              name: result.name,
              description: result.description,
              homepage: result.homepage,
              isPrivate: result.isPrivate,
              isArchived: result.isArchived,
            );
        await _refresh();
      } catch (error) {
        if (mounted) _showError(error);
      }
    } else if (action == RepositoryAction.delete) {
      final confirmed = await showDeleteRepositoryDialog(context, repository);
      if (confirmed != true || !mounted) return;
      try {
        await ref.read(repositoryServiceProvider).deleteRepository(repository.fullName);
        await _refresh();
      } catch (error) {
        if (mounted) _showError(error);
      }
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
  }

  Future<void> _copyLink(GitHubRepository repository) async {
    await Clipboard.setData(ClipboardData(text: repository.htmlUrl));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link do repositório copiado.')),
      );
    }
  }

  void _showError(Object error) {
    final message = error is AppException
        ? error.message
        : error is FormatException
            ? error.message
            : 'Não foi possível concluir a operação.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
    return Scaffold(
      bottomNavigationBar: NavigationBar(
        selectedIndex: _section,
        onDestinationSelected: (value) {
          setState(() {
            _section = value;
            _query = '';
            _searchController.clear();
            _filter = 'Todos';
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.folder_copy_outlined),
            selectedIcon: Icon(Icons.folder_copy_rounded),
            label: 'Meus repositórios',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmarks_outlined),
            selectedIcon: Icon(Icons.bookmarks_rounded),
            label: 'Acompanhados',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              title: Text(_showingFollowed ? 'Acompanhados' : 'Projetos'),
              actions: [
                if (!_showingFollowed)
                  profile.maybeWhen(
                    data: (data) => Padding(
                      padding: const EdgeInsets.only(right: 2),
                      child: CircleAvatar(
                        radius: 15,
                        foregroundImage: data.avatarUrl.isEmpty ? null : NetworkImage(data.avatarUrl),
                        child: data.avatarUrl.isEmpty
                            ? const Icon(Icons.person_outline_rounded, size: 17)
                            : null,
                      ),
                    ),
                    orElse: () => const SizedBox.shrink(),
                  ),
                IconButton(
                  onPressed: _showingFollowed ? _addFollowedRepository : _createRepository,
                  tooltip: _showingFollowed ? 'Acompanhar repositório' : 'Novo repositório',
                  icon: Icon(_showingFollowed ? Icons.bookmark_add_outlined : Icons.add_rounded),
                ),
                const DownloadCenterButton(),
                IconButton(
                  onPressed: () => context.push('/settings'),
                  tooltip: 'Configurações',
                  icon: const Icon(Icons.settings_outlined),
                ),
                const SizedBox(width: 4),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
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
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 38,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: ['Todos', 'Públicos', 'Privados', 'Arquivados']
                            .map(
                              (value) => Padding(
                                padding: const EdgeInsets.only(right: 7),
                                child: ChoiceChip(
                                  label: Text(value),
                                  selected: _filter == value,
                                  onSelected: (_) => setState(() => _filter = value),
                                ),
                              ),
                            )
                            .toList(growable: false),
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
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                  sliver: SliverList.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 7),
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
