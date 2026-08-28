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

part 'repositories_screen_actions.dart';

class RepositoriesScreen extends ConsumerStatefulWidget {
  const RepositoriesScreen({this.initialSection = 0, super.key});

  final int initialSection;

  @override
  ConsumerState<RepositoriesScreen> createState() => _RepositoriesScreenState();
}

class _RepositoriesScreenState extends ConsumerState<RepositoriesScreen>
    with _RepositoriesScreenActions {
  final _searchController = TextEditingController();
  String _query = '';
  String _filter = 'Todos';
  late int _section;

  bool get _showingFollowed => _section == 1;

  @override
  void initState() {
    super.initState();
    _section = widget.initialSection;
  }

  @override
  void didUpdateWidget(covariant RepositoriesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSection != widget.initialSection) {
      setState(() {
        _section = widget.initialSection;
        _query = '';
        _filter = 'Todos';
        _searchController.clear();
      });
    }
  }

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
    try {
      if (_showingFollowed) {
        await ref
            .read(repositoryServiceProvider)
            .refreshFollowedRepositories();
        ref.invalidate(followedRepositoriesProvider);
        await ref.read(followedRepositoriesProvider.future);
      } else {
        ref.invalidate(repositoriesProvider);
        ref.invalidate(githubProfileProvider);
        await ref.read(repositoriesProvider.future);
      }
    } catch (error) {
      if (mounted) _showError(error);
    }
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
