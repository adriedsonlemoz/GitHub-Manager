import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:github_manager/core/errors/app_exception.dart';
import 'package:github_manager/core/platform/platform_actions.dart';
import 'package:github_manager/core/widgets/adaptive_dialog.dart';
import 'package:github_manager/features/builds/domain/action_artifact.dart';
import 'package:github_manager/features/builds/presentation/build_providers.dart';
import 'package:github_manager/features/downloads/presentation/download_center_button.dart';
import 'package:github_manager/features/downloads/presentation/download_providers.dart';
import 'package:github_manager/features/projects/domain/zip_project.dart';
import 'package:github_manager/features/projects/presentation/project_providers.dart';
import 'package:github_manager/features/repositories/domain/github_repository.dart';
import 'package:github_manager/features/repositories/domain/repository_git_models.dart';
import 'package:github_manager/features/repositories/domain/repository_project_info.dart';
import 'package:github_manager/features/repositories/presentation/repository_management_dialogs.dart';
import 'package:github_manager/features/repositories/presentation/repository_providers.dart';
import 'package:github_manager/features/repositories/presentation/technology_badge.dart';
import 'package:go_router/go_router.dart';

class RepositoryDetailScreen extends ConsumerStatefulWidget {
  const RepositoryDetailScreen({required this.repositoryFullName, super.key});

  final String repositoryFullName;

  @override
  ConsumerState<RepositoryDetailScreen> createState() =>
      _RepositoryDetailScreenState();
}

class _RepositoryDetailScreenState extends ConsumerState<RepositoryDetailScreen> {
  late Future<GitHubRepository> _repositoryFuture;
  late Future<List<RepositoryWorkflowRun>> _runsFuture;

  @override
  void initState() {
    super.initState();
    _repositoryFuture = _loadRepository();
    _runsFuture = _loadRuns();
  }

  Future<GitHubRepository> _loadRepository() => ref
      .read(repositoryServiceProvider)
      .getRepository(widget.repositoryFullName);

  Future<List<RepositoryWorkflowRun>> _loadRuns() => ref
      .read(repositoryGitServiceProvider)
      .listWorkflowRuns(widget.repositoryFullName);

  Future<void> _refresh() async {
    ref.invalidate(repositoryArtifactsProvider(widget.repositoryFullName));
    final repository = _loadRepository();
    final runs = _loadRuns();
    setState(() {
      _repositoryFuture = repository;
      _runsFuture = runs;
    });
    final resolved = await repository;
    ref.invalidate(repositoryProjectInfoProvider(resolved));
    await Future.wait([runs]);
  }

  Future<void> _copyLink(GitHubRepository repository) async {
    await Clipboard.setData(ClipboardData(text: repository.htmlUrl));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link do repositório copiado.')),
      );
    }
  }

  Future<void> _importZip(GitHubRepository repository) async {
    try {
      final project =
          await ref.read(localProjectServiceProvider).pickAndAnalyzeZip();
      if (project == null || !mounted) {
        return;
      }
      final confirmed = await _confirmZip(project, repository);
      if (confirmed != true || !mounted) {
        return;
      }

      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => const AlertDialog(
          title: Text('Enviando build'),
          content: AdaptiveDialogBody(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Validando o ZIP e publicando os arquivos em um único commit...'),
                SizedBox(height: 14),
                LinearProgressIndicator(),
              ],
            ),
          ),
        ),
      );

      try {
        final result = await ref.read(gitProjectUploadServiceProvider).uploadZip(
              project: project,
              repositoryFullName: repository.fullName,
              branch: repository.defaultBranch,
              commitMessage: '',
            );
        if (!mounted) {
        return;
      }
        Navigator.of(context, rootNavigator: true).pop();
        await _refresh();
        if (!mounted) {
        return;
      }
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Projeto enviado'),
            content: AdaptiveDialogBody(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${result.fileCount} arquivos publicados no commit ${result.commitSha.substring(0, 7)}.',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Se o repositório possui GitHub Actions configurado para push, a build deve aparecer em seguida.',
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Fechar'),
              ),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  context.push(
                    '/repositories/${repository.fullName}/builds?branch=${Uri.encodeQueryComponent(repository.defaultBranch)}',
                  );
                },
                icon: const Icon(Icons.monitor_heart_outlined),
                label: const Text('Acompanhar build'),
              ),
            ],
          ),
        );
      } catch (error) {
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          _showError(error);
        }
      }
    } catch (error) {
      if (mounted) {
        _showError(error);
      }
    }
  }

  Future<bool?> _confirmZip(
    ZipProjectPreview project,
    GitHubRepository repository,
  ) =>
      showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Enviar build'),
          content: AdaptiveDialogBody(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${project.projectType} • ${project.fileCount} arquivos • ${project.folderCount} pastas',
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Destino: ${repository.fullName}/${repository.defaultBranch}',
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'O envio sincroniza completamente o repositório com o novo ZIP: atualiza arquivos existentes, adiciona os novos e remove automaticamente arquivos antigos que não fazem mais parte do projeto. Tudo é publicado em um único commit com data e hora.',
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
              icon: const Icon(Icons.cloud_upload_outlined),
              label: const Text('Enviar build'),
            ),
          ],
        ),
      );

  void _downloadLatestApk(
    GitHubRepository repository,
    ActionArtifact artifact,
  ) {
    ref.read(downloadManagerProvider).startArtifactApk(
          repositoryFullName: repository.fullName,
          artifact: artifact,
        );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Download do APK iniciado. Acompanhe pelo botão de Downloads.'),
      ),
    );
  }

  void _downloadProjectZip(
    GitHubRepository repository,
    RepositoryProjectInfo info,
  ) {
    ref.read(downloadManagerProvider).startRepositoryZip(
          repositoryFullName: repository.fullName,
          branch: repository.defaultBranch,
          projectName: info.projectName,
        );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Download do projeto iniciado em ZIP.'),
      ),
    );
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
        final updated = await ref.read(repositoryServiceProvider).updateRepository(
              fullName: repository.fullName,
              name: result.name,
              description: result.description,
              homepage: result.homepage,
              isPrivate: result.isPrivate,
              isArchived: result.isArchived,
            );
        ref.invalidate(repositoriesProvider);
        if (!mounted) {
        return;
      }
        if (updated.fullName != widget.repositoryFullName) {
          context.go('/repositories/${updated.fullName}');
          return;
        }
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
        ref.invalidate(repositoriesProvider);
        if (mounted) {
      context.go('/');
    }
      } catch (error) {
        if (mounted) {
        _showError(error);
      }
      }
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
    return Scaffold(
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
            final artifactsAsync = ref.watch(
              repositoryArtifactsProvider(repository.fullName),
            );
            final latestApk = artifactsAsync.maybeWhen<ActionArtifact?>(
              data: (items) => items
                  .where((artifact) => artifact.likelyContainsApk)
                  .firstOrNull,
              orElse: () => null,
            );

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverAppBar(
                  pinned: true,
                  title: Text(info.projectName),
                  actions: [
                    IconButton(
                      onPressed: () => _downloadProjectZip(repository, info),
                      tooltip: 'Baixar ZIP do projeto',
                      icon: const Icon(Icons.folder_zip_outlined),
                    ),
                    const DownloadCenterButton(),
                    IconButton(
                      onPressed: () => _manageRepository(repository),
                      tooltip: 'Gerenciar repositório',
                      icon: const Icon(Icons.more_vert_rounded),
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
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                  sliver: SliverToBoxAdapter(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final width = (constraints.maxWidth - 8) / 2;
                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _QuickActionButton(
                              width: width,
                              icon: Icons.folder_zip_outlined,
                              label: 'Enviar build',
                              filled: true,
                              onTap: () => _importZip(repository),
                            ),
                            _QuickActionButton(
                              width: width,
                              icon: Icons.open_in_new_rounded,
                              label: 'GitHub',
                              onTap: () => PlatformActions.openUri(repository.htmlUrl),
                            ),
                            _QuickActionButton(
                              width: width,
                              icon: Icons.copy_rounded,
                              label: 'Copiar link',
                              onTap: () => _copyLink(repository),
                            ),
                            _QuickActionButton(
                              width: width,
                              icon: Icons.android_rounded,
                              label: 'APK',
                              enabled: latestApk != null,
                              onTap: latestApk == null
                                  ? null
                                  : () => _downloadLatestApk(repository, latestApk),
                            ),
                          ],
                        );
                      },
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
                        icon: Icons.folder_open_rounded,
                        title: 'Arquivos',
                        subtitle: 'Navegar, editar, criar, excluir e enviar arquivos',
                        onTap: () => context.push(
                          '/repositories/${repository.fullName}/files?branch=${Uri.encodeQueryComponent(repository.defaultBranch)}',
                        ),
                      ),
                      const SizedBox(height: 7),
                      _WorkspaceTile(
                        icon: Icons.play_circle_outline_rounded,
                        title: 'Builds',
                        subtitle: 'Executar, acompanhar etapas, abrir logs e baixar APK',
                        onTap: () => context.push(
                          '/repositories/${repository.fullName}/builds?branch=${Uri.encodeQueryComponent(repository.defaultBranch)}',
                        ),
                      ),
                      const SizedBox(height: 7),
                      _WorkspaceTile(
                        icon: Icons.key_rounded,
                        title: 'Secrets',
                        subtitle: 'Adicionar, importar, substituir e excluir Secrets',
                        onTap: () => context.push(
                          '/repositories/${repository.fullName}/secrets',
                        ),
                      ),
                      const SizedBox(height: 7),
                      _WorkspaceTile(
                        icon: Icons.commit_rounded,
                        title: 'Commits',
                        subtitle: 'Histórico da branch ${repository.defaultBranch}',
                        onTap: () => context.push(
                          '/repositories/${repository.fullName}/commits?branch=${Uri.encodeQueryComponent(repository.defaultBranch)}',
                        ),
                      ),
                      const SizedBox(height: 7),
                      _WorkspaceTile(
                        icon: Icons.bug_report_outlined,
                        title: 'Bugs',
                        subtitle: 'GitHub Issues — mantido sem alterações nesta versão',
                        onTap: () => context.push(
                          '/repositories/${repository.fullName}/bugs',
                        ),
                      ),
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

class _RepositoryHeader extends StatelessWidget {
  const _RepositoryHeader({
    required this.repository,
    required this.info,
    required this.runsFuture,
  });

  final GitHubRepository repository;
  final RepositoryProjectInfo info;
  final Future<List<RepositoryWorkflowRun>> runsFuture;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    repository.isPrivate
                        ? Icons.lock_outline_rounded
                        : Icons.public_rounded,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          info.projectName,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        Text(
                          repository.fullName,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (repository.description?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 10),
                Text(repository.description!),
              ],
              if (repository.homepage?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 7),
                Text(
                  repository.homepage!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  if (info.version?.isNotEmpty == true)
                    Chip(label: Text('v${info.version}')),
                  Chip(
                    avatar: const Icon(Icons.account_tree_outlined, size: 15),
                    label: Text(repository.defaultBranch),
                  ),
                  ...info.technologies.map((item) => TechnologyBadge(name: item)),
                  FutureBuilder<List<RepositoryWorkflowRun>>(
                    future: runsFuture,
                    builder: (context, snapshot) {
                      final data = snapshot.data;
                      final latest = data != null && data.isNotEmpty
                          ? data.first
                          : null;
                      if (latest == null) {
                        return const Chip(label: Text('Sem builds'));
                      }
                      final label = latest.isRunning
                          ? 'Build em execução'
                          : latest.conclusion == 'success'
                              ? 'Última build OK'
                              : latest.conclusion == 'failure'
                                  ? 'Última build falhou'
                                  : 'Build ${latest.status}';
                      return Chip(
                        avatar: Icon(
                          latest.isRunning
                              ? Icons.sync_rounded
                              : latest.conclusion == 'success'
                                  ? Icons.check_circle_outline_rounded
                                  : Icons.error_outline_rounded,
                          size: 15,
                        ),
                        label: Text(label),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.width,
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
    this.enabled = true,
  });

  final double width;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool filled;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final callback = enabled ? onTap : null;
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 19),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
    return SizedBox(
      width: width,
      height: 48,
      child: filled
          ? FilledButton(
              onPressed: callback,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                visualDensity: VisualDensity.compact,
              ),
              child: child,
            )
          : OutlinedButton(
              onPressed: callback,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                visualDensity: VisualDensity.compact,
              ),
              child: child,
            ),
    );
  }
}

class _WorkspaceTile extends StatelessWidget {
  const _WorkspaceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right_rounded),
        ),
      );
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
