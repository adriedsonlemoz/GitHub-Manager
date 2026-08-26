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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<GitHubRepository> _applyFilters(List<GitHubRepository> source) {
    final query = _query.trim().toLowerCase();
    return source.where((repository) {
      if (_filter == 'Públicos' && repository.isPrivate) {
        return false;
      }
      if (_filter == 'Privados' && !repository.isPrivate) {
        return false;
      }
      if (_filter == 'Arquivados' && !repository.isArchived) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      return repository.name.toLowerCase().contains(query) ||
          repository.fullName.toLowerCase().contains(query) ||
          (repository.description?.toLowerCase().contains(query) ?? false);
    }).toList(growable: false);
  }

  Future<void> _refresh() async {
    ref.invalidate(repositoriesProvider);
    ref.invalidate(githubProfileProvider);
    await ref.read(repositoriesProvider.future);
  }

  Future<void> _createRepository() async {
    final result = await showCreateRepositoryDialog(context);
    if (result == null || !mounted) {
      return;
    }
    try {
      await ref.read(repositoryServiceProvider).createRepository(
            name: result.name,
            description: result.description,
            homepage: result.homepage,
            isPrivate: result.isPrivate,
          );
      await _refresh();
    } catch (error) {
      if (mounted) {
        _showError(error);
      }
    }
  }

  Future<void> _manageRepository(GitHubRepository repository) async {
    final action = await showRepositoryActionsSheet(context, repository);
    if (action == null || !mounted) {
      return;
    }
    if (action == RepositoryAction.edit) {
      final result = await showEditRepositoryDialog(context, repository);
      if (result == null || !mounted) {
      return;
    }
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
        if (mounted) {
        _showError(error);
      }
      }
    } else if (action == RepositoryAction.delete) {
      final confirmed = await showDeleteRepositoryDialog(context, repository);
      if (confirmed != true || !mounted) {
        return;
      }
      try {
        await ref.read(repositoryServiceProvider).deleteRepository(repository.fullName);
        await _refresh();
      } catch (error) {
        if (mounted) {
        _showError(error);
      }
      }
    }
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
        : 'Não foi possível concluir a operação.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final connection = ref.watch(githubConnectionProvider);
    return connection.when(
      loading: () => const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Verificando a conexão segura com o GitHub...'),
              ],
            ),
          ),
        ),
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
    final repositories = ref.watch(repositoriesProvider);
    final profile = ref.watch(githubProfileProvider);
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              title: const Text('Projetos'),
              actions: [
                profile.maybeWhen(
                  data: (data) => Padding(
                    padding: const EdgeInsets.only(right: 2),
                    child: CircleAvatar(
                      radius: 15,
                      foregroundImage: data.avatarUrl.isEmpty
                          ? null
                          : NetworkImage(data.avatarUrl),
                      child: data.avatarUrl.isEmpty
                          ? const Icon(Icons.person_outline_rounded, size: 17)
                          : null,
                    ),
                  ),
                  orElse: () => const SizedBox.shrink(),
                ),
                IconButton(
                  onPressed: _createRepository,
                  tooltip: 'Novo repositório',
                  icon: const Icon(Icons.add_rounded),
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
                      hintText: 'Pesquisar projeto',
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
                  child: AppErrorCard(
                    error: error,
                    onRetry: () => ref.invalidate(repositoriesProvider),
                  ),
                ),
              ),
              data: (items) {
                final filtered = _applyFilters(items);
                if (filtered.isEmpty) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: Text('Nenhum projeto encontrado.')),
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
                        onTap: () => context.push(
                          '/repositories/${repository.fullName}',
                        ),
                        onMenu: () => _manageRepository(repository),
                        onOpenExternal: () => PlatformActions.openUri(
                          repository.htmlUrl,
                        ),
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
