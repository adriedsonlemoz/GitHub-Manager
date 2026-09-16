import 'package:flutter/material.dart';
import 'package:github_manager/core/widgets/app_main_navigation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:github_manager/core/errors/app_exception.dart';
import 'package:github_manager/core/platform/platform_actions.dart';
import 'package:github_manager/core/widgets/adaptive_dialog.dart';
import 'package:github_manager/core/widgets/centered_notice.dart';
import 'package:github_manager/features/builds/domain/action_artifact.dart';
import 'package:github_manager/features/builds/presentation/build_providers.dart';
import 'package:github_manager/features/downloads/presentation/download_center_button.dart';
import 'package:github_manager/features/downloads/presentation/download_providers.dart';
import 'package:github_manager/features/permissions/domain/repository_permission_preflight.dart';
import 'package:github_manager/features/permissions/presentation/permission_preflight_guard.dart';
import 'package:github_manager/features/permissions/presentation/token_permission_providers.dart';
import 'package:github_manager/features/projects/domain/project_safety_check.dart';
import 'package:github_manager/features/projects/domain/zip_project.dart';
import 'package:github_manager/features/projects/presentation/project_providers.dart';
import 'package:github_manager/features/repositories/domain/github_repository.dart';
import 'package:github_manager/features/repositories/domain/repository_git_models.dart';
import 'package:github_manager/features/repositories/domain/repository_project_info.dart';
import 'package:github_manager/features/repositories/presentation/repository_management_dialogs.dart';
import 'package:github_manager/features/repositories/presentation/repository_providers.dart';
import 'package:github_manager/features/repositories/presentation/technology_badge.dart';
import 'package:github_manager/features/uploads/presentation/upload_center_button.dart';
import 'package:github_manager/features/uploads/presentation/upload_progress_dialog.dart';
import 'package:github_manager/features/uploads/presentation/upload_providers.dart';
import 'package:go_router/go_router.dart';

part 'repository_detail_widgets.dart';
part 'repository_detail_screen_actions.dart';

class RepositoryDetailScreen extends ConsumerStatefulWidget {
  const RepositoryDetailScreen({
    required this.repositoryFullName,
    this.readOnly = false,
    super.key,
  });

  final String repositoryFullName;
  final bool readOnly;

  @override
  ConsumerState<RepositoryDetailScreen> createState() =>
      _RepositoryDetailScreenState();
}

class _RepositoryDetailScreenState extends ConsumerState<RepositoryDetailScreen>
    with _RepositoryDetailScreenActions {
  @override
  void initState() {
    super.initState();
    initializeRepositoryDetailState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const AppMainNavigation(selectedIndex: 0),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<GitHubRepository>(
          future: _repositoryFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CustomScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverAppBar(title: Text('Projeto')),
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
              );
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  const SliverAppBar(title: Text('Projeto')),
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverToBoxAdapter(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Text(_message(snapshot.error)),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }

            final repository = snapshot.data!;
            final infoAsync = ref.watch(repositoryProjectInfoProvider(repository));
            final info = infoAsync.maybeWhen(
              data: (value) => value,
              orElse: () => RepositoryProjectInfo(
                projectName: repository.name,
                version: null,
                technologies: [
                  if (repository.language != null) repository.language!,
                ],
              ),
            );
            final artifactsAsync = widget.readOnly
                ? null
                : ref.watch(repositoryArtifactsProvider(repository.fullName));
            final latestApk = artifactsAsync?.maybeWhen<ActionArtifact?>(
              data: (items) => items
                  .where(
                    (artifact) => artifact.likelyContainsApk && !artifact.expired,
                  )
                  .firstOrNull,
              orElse: () => null,
            );

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverAppBar(
                  pinned: true,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  surfaceTintColor: Theme.of(context).colorScheme.surface,
                  scrolledUnderElevation: 2,
                  title: Text(
                    info.projectName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  actions: [
                    IconButton(
                      onPressed: () => _downloadProjectZip(repository, info),
                      tooltip: 'Baixar ZIP do projeto',
                      icon: const Icon(Icons.folder_zip_outlined),
                    ),
                    const UploadCenterButton(),
                    const DownloadCenterButton(),
                    if (!widget.readOnly)
                      IconButton(
                        onPressed: () => _manageRepository(repository),
                        tooltip: 'Gerenciar repositório',
                        icon: const Icon(Icons.settings_outlined),
                      ),
                    const SizedBox(width: 4),
                  ],
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
                  sliver: SliverToBoxAdapter(
                    child: _RepositoryHeader(
                      repository: repository,
                      info: info,
                      runsFuture: _runsFuture,
                      readOnly: widget.readOnly,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(14, 9, 14, 0),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      children: [
                        if (!widget.readOnly) ...[
                          Expanded(
                            child: _CompactQuickAction(
                              icon: Icons.cloud_upload_outlined,
                              label: 'Enviar',
                              filled: true,
                              onTap: () => _sendBuild(repository),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: _CompactQuickAction(
                            icon: widget.readOnly
                                ? Icons.call_split_rounded
                                : Icons.open_in_new_rounded,
                            label: widget.readOnly ? 'Fork' : 'GitHub',
                            filled: widget.readOnly,
                            onTap: widget.readOnly
                                ? () => _forkRepository(repository)
                                : () => PlatformActions.openUri(repository.htmlUrl),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _CompactQuickAction(
                            icon: Icons.copy_rounded,
                            label: 'Copiar',
                            onTap: () => _copyLink(repository),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _CompactQuickAction(
                            icon: Icons.android_rounded,
                            label: 'APK',
                            enabled: widget.readOnly || latestApk != null,
                            onTap: widget.readOnly
                                ? () => context.push(
                                      '/repositories/${repository.fullName}/artifacts?readOnly=1',
                                    )
                                : latestApk == null
                                    ? null
                                    : () => _downloadLatestApk(repository, latestApk),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      'Projeto',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 7)),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 22),
                  sliver: SliverList.list(
                    children: [
                      _WorkspaceTile(
                        icon: Icons.menu_book_outlined,
                        title: 'README',
                        subtitle: 'Ler a apresentação e documentação do projeto',
                        onTap: () => context.push(
                          '/repositories/${repository.fullName}/readme?branch=${Uri.encodeQueryComponent(repository.defaultBranch)}',
                        ),
                      ),
                      const SizedBox(height: 7),
                      _WorkspaceTile(
                        icon: Icons.folder_open_rounded,
                        title: 'Arquivos',
                        subtitle: widget.readOnly
                            ? 'Navegar pelas pastas e visualizar arquivos'
                            : 'Navegar, editar, criar, excluir e enviar arquivos',
                        onTap: () => context.push(
                          '/repositories/${repository.fullName}/files?branch=${Uri.encodeQueryComponent(repository.defaultBranch)}&readOnly=${widget.readOnly ? '1' : '0'}',
                        ),
                      ),
                      const SizedBox(height: 7),
                      _WorkspaceTile(
                        icon: Icons.play_circle_outline_rounded,
                        title: 'Builds',
                        subtitle: 'Executar, acompanhar etapas, abrir logs e baixar APK',
                        onTap: () => context.push(
                          '/repositories/${repository.fullName}/builds?branch=${Uri.encodeQueryComponent(repository.defaultBranch)}&readOnly=${widget.readOnly ? '1' : '0'}',
                        ),
                      ),
                      const SizedBox(height: 7),
                      if (!widget.readOnly) ...[
                        _WorkspaceTile(
                          icon: Icons.cloud_upload_outlined,
                          title: 'Central de envios',
                          subtitle: 'Acompanhar sincronizações, fila, falhas e builds iniciadas',
                          onTap: () => context.push('/uploads'),
                        ),
                        const SizedBox(height: 7),
                      ],
                      if (!widget.readOnly) ...[
                        _WorkspaceTile(
                          icon: Icons.verified_user_outlined,
                          title: 'Diagnóstico do token',
                          subtitle: 'Verificar Contents, Actions, Secrets e administração sem alterar dados',
                          onTap: () => context.push(
                            '/repositories/${repository.fullName}/permissions',
                          ),
                        ),
                        const SizedBox(height: 7),
                      ],
                      if (!widget.readOnly) ...[
                        _WorkspaceTile(
                          icon: Icons.key_rounded,
                          title: 'Secrets',
                          subtitle: 'Adicionar, importar, substituir e excluir Secrets',
                          onTap: () => context.push(
                            '/repositories/${repository.fullName}/secrets',
                          ),
                        ),
                        const SizedBox(height: 7),
                      ],
                      _WorkspaceTile(
                        icon: Icons.android_rounded,
                        title: 'APKs e artifacts',
                        subtitle: widget.readOnly
                            ? 'Baixar arquivos públicos disponíveis no GitHub'
                            : 'Baixar ou excluir APKs e artifacts',
                        onTap: () => context.push(
                          '/repositories/${repository.fullName}/artifacts?readOnly=${widget.readOnly ? '1' : '0'}',
                        ),
                      ),
                      const SizedBox(height: 7),
                      _WorkspaceTile(
                        icon: Icons.commit_rounded,
                        title: 'Commits',
                        subtitle: 'Histórico, autores, datas e SHA por branch',
                        onTap: () => context.push(
                          '/repositories/${repository.fullName}/commits?branch=${Uri.encodeQueryComponent(repository.defaultBranch)}',
                        ),
                      ),
                      if (!widget.readOnly) ...[
                        const SizedBox(height: 7),
                        _WorkspaceTile(
                          icon: Icons.bug_report_outlined,
                          title: 'Issues / Bugs',
                          subtitle: 'Criar, acompanhar, editar, fechar e reabrir problemas',
                          onTap: () => context.push(
                            '/repositories/${repository.fullName}/bugs',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _message(Object? error) => error is AppException
      ? error.message
      : 'Não foi possível carregar este repositório.';
}
