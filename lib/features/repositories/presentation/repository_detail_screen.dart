import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:github_manager/core/errors/app_exception.dart';
import 'package:github_manager/core/platform/platform_actions.dart';
import 'package:github_manager/core/widgets/adaptive_dialog.dart';
import 'package:github_manager/core/widgets/centered_notice.dart';
import 'package:github_manager/core/widgets/installed_version_banner.dart';
import 'package:github_manager/features/builds/domain/action_artifact.dart';
import 'package:github_manager/features/builds/presentation/build_providers.dart';
import 'package:github_manager/features/downloads/presentation/download_center_button.dart';
import 'package:github_manager/features/downloads/presentation/download_providers.dart';
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

class _RepositoryDetailScreenState extends ConsumerState<RepositoryDetailScreen> {
  late Future<GitHubRepository> _repositoryFuture;
  late Future<List<RepositoryWorkflowRun>> _runsFuture;

  @override
  void initState() {
    super.initState();
    _repositoryFuture = _loadRepository();
    _runsFuture = widget.readOnly
        ? Future<List<RepositoryWorkflowRun>>.value(const [])
        : _loadRuns();
  }

  Future<GitHubRepository> _loadRepository() async {
    final service = ref.read(repositoryServiceProvider);
    if (widget.readOnly) {
      final cached = await service.getFollowedRepository(widget.repositoryFullName);
      if (cached != null) return cached;
    }
    return service.getRepository(widget.repositoryFullName);
  }

  Future<List<RepositoryWorkflowRun>> _loadRuns() => ref
      .read(repositoryGitServiceProvider)
      .listWorkflowRuns(widget.repositoryFullName);

  Future<void> _refresh() async {
    if (!widget.readOnly) {
      ref.invalidate(repositoryArtifactsProvider(widget.repositoryFullName));
    }
    final repository = widget.readOnly
        ? ref.read(repositoryServiceProvider).getRepository(widget.repositoryFullName)
        : _loadRepository();
    final runs = widget.readOnly
        ? Future<List<RepositoryWorkflowRun>>.value(const [])
        : _loadRuns();
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
      showCenteredNotice(context, 'Link do repositório copiado.');
    }
  }

  Future<void> _forkRepository(GitHubRepository repository) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Criar fork na minha conta?'),
        content: Text(
          'O GitHub criará uma cópia de ${repository.fullName} na sua conta. '
          'A cópia aparecerá em Meus repositórios e poderá ser modificada normalmente.',
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
      final fork = await ref
          .read(repositoryServiceProvider)
          .forkRepository(repository.fullName);
      ref.invalidate(repositoriesProvider);
      if (!mounted) return;
      showCenteredNotice(context, fork.fullName.isEmpty
                ? 'Fork solicitado. O GitHub pode levar alguns segundos para criar a cópia.'
                : 'Fork criado: ${fork.fullName}');
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<void> _sendBuild(GitHubRepository repository) async {
    try {
      final project =
          await ref.read(localProjectServiceProvider).pickAndAnalyzeZip();
      if (project == null || !mounted) {
        return;
      }
      final repositoryInfo = await ref
          .read(repositoryProjectInfoServiceProvider)
          .load(repository);
      final confirmed = await _confirmZip(
        project,
        repository,
        repositoryInfo,
      );
      if (confirmed != true || !mounted) {
        return;
      }

      final manager = ref.read(uploadManagerProvider);
      final upload = manager.startBuild(
        project: project,
        repositoryFullName: repository.fullName,
        branch: repository.defaultBranch,
      );
      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (_) => UploadProgressDialog(uploadId: upload.id),
      );
    } catch (error) {
      if (mounted) {
        _showError(error);
      }
    }
  }

  Future<bool?> _confirmZip(
    ZipProjectPreview project,
    GitHubRepository repository,
    RepositoryProjectInfo repositoryInfo,
  ) {
    final check = ProjectSafetyCheck.compare(
      project: project,
      repository: repository,
      repositoryInfo: repositoryInfo,
    );

    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(check.blocked ? 'Envio bloqueado' : 'Conferir build'),
        content: AdaptiveDialogBody(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const InstalledVersionBanner(compact: true),
                const SizedBox(height: 12),
                _BuildSafetyRow(
                  label: 'Projeto detectado',
                  value: project.identityLabel,
                  icon: Icons.inventory_2_outlined,
                ),
                _BuildSafetyRow(
                  label: 'Identidade usada',
                  value: check.identitySource,
                  icon: Icons.fingerprint_rounded,
                ),
                _BuildSafetyRow(
                  label: 'Versão do ZIP',
                  value: project.versionLabel ?? 'Não identificada',
                  icon: Icons.new_releases_outlined,
                ),
                _BuildSafetyRow(
                  label: 'Repositório aberto',
                  value: repositoryInfo.projectName,
                  icon: Icons.cloud_outlined,
                ),
                _BuildSafetyRow(
                  label: 'Versão no GitHub',
                  value: repositoryInfo.versionLabel ?? 'Não identificada',
                  icon: Icons.history_rounded,
                ),
                if (project.applicationId?.isNotEmpty == true ||
                    repositoryInfo.applicationId?.isNotEmpty == true)
                  _BuildSafetyRow(
                    label: 'Identidade Android',
                    value:
                        '${project.applicationId ?? 'não identificada'} → ${repositoryInfo.applicationId ?? 'não identificada'}',
                    icon: Icons.android_rounded,
                  ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: check.blocked
                        ? Theme.of(context).colorScheme.errorContainer
                        : check.warning
                            ? Theme.of(context).colorScheme.tertiaryContainer
                            : Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        check.blocked
                            ? Icons.block_rounded
                            : check.warning
                                ? Icons.warning_amber_rounded
                                : Icons.verified_rounded,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          check.message,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${project.projectType} • ${project.fileCount} arquivos • ${project.folderCount} pastas',
                ),
                const SizedBox(height: 6),
                Text(
                  'Destino: ${repository.fullName}/${repository.defaultBranch}',
                ),
                const SizedBox(height: 10),
                const Text(
                  'O envio sincroniza completamente o repositório com o ZIP: arquivos antigos que não existem mais no projeto também são removidos.',
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
            onPressed: check.blocked
                ? null
                : () => Navigator.pop(dialogContext, true),
            icon: Icon(
              check.warning
                  ? Icons.warning_amber_rounded
                  : Icons.cloud_upload_outlined,
            ),
            label: Text(
              check.warning ? 'Enviar mesmo assim' : 'Enviar build',
            ),
          ),
        ],
      ),
    );
  }

  void _downloadLatestApk(
    GitHubRepository repository,
    ActionArtifact artifact,
  ) {
    ref.read(downloadManagerProvider).startArtifactApk(
          repositoryFullName: repository.fullName,
          artifact: artifact,
        );
    showCenteredNotice(context, 'Download do APK iniciado. Acompanhe pelo botão de Downloads.');
  }

  void _downloadProjectZip(
    GitHubRepository repository,
    RepositoryProjectInfo info,
  ) {
    ref.read(downloadManagerProvider).startRepositoryZip(
          repositoryFullName: repository.fullName,
          branch: repository.defaultBranch,
          projectName: info.projectName,
          version: info.version,
        );
    showCenteredNotice(context, 'Download do projeto iniciado em ZIP.');
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
    showCenteredNotice(context, message);
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
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                  sliver: SliverToBoxAdapter(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final width = (constraints.maxWidth - 8) / 2;
                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (!widget.readOnly)
                              _QuickActionButton(
                                width: width,
                                icon: Icons.folder_zip_outlined,
                                label: 'Enviar build',
                                filled: true,
                                onTap: () => _sendBuild(repository),
                              ),
                            _QuickActionButton(
                              width: width,
                              icon: Icons.open_in_new_rounded,
                              label: 'GitHub',
                              onTap: () => PlatformActions.openUri(repository.htmlUrl),
                            ),
                            if (widget.readOnly)
                              _QuickActionButton(
                                width: width,
                                icon: Icons.call_split_rounded,
                                label: 'Fork',
                                filled: true,
                                onTap: () => _forkRepository(repository),
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
                              enabled: widget.readOnly || latestApk != null,
                              onTap: widget.readOnly
                                  ? () => context.push(
                                        '/repositories/${repository.fullName}/artifacts?readOnly=1',
                                      )
                                  : latestApk == null
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
                        subtitle: 'Histórico da branch ${repository.defaultBranch}',
                        onTap: () => context.push(
                          '/repositories/${repository.fullName}/commits?branch=${Uri.encodeQueryComponent(repository.defaultBranch)}',
                        ),
                      ),
                      if (!widget.readOnly) ...[
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
    required this.readOnly,
  });

  final GitHubRepository repository;
  final RepositoryProjectInfo info;
  final Future<List<RepositoryWorkflowRun>> runsFuture;
  final bool readOnly;

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
                    _ProjectInfoBadge(
                      icon: Icons.new_releases_outlined,
                      label: 'v${info.version}',
                    ),
                  _ProjectInfoBadge(
                    icon: Icons.account_tree_outlined,
                    label: repository.defaultBranch,
                  ),
                  if (readOnly)
                    const _ProjectInfoBadge(
                      icon: Icons.visibility_outlined,
                      label: 'Somente leitura',
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
                        return const _ProjectInfoBadge(
                          icon: Icons.schedule_outlined,
                          label: 'Sem builds',
                        );
                      }
                      final label = latest.isRunning
                          ? 'Build em execução'
                          : latest.conclusion == 'success'
                              ? 'Última build OK'
                              : latest.conclusion == 'failure'
                                  ? 'Última build falhou'
                                  : 'Build ${latest.status}';
                      return _ProjectInfoBadge(
                        icon: latest.isRunning
                            ? Icons.sync_rounded
                            : latest.conclusion == 'success'
                                ? Icons.check_circle_outline_rounded
                                : latest.conclusion == 'failure'
                                    ? Icons.error_outline_rounded
                                    : Icons.schedule_outlined,
                        label: label,
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


class _BuildSafetyRow extends StatelessWidget {
  const _BuildSafetyRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.labelMedium),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _ProjectInfoBadge extends StatelessWidget {
  const _ProjectInfoBadge({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .7),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
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
