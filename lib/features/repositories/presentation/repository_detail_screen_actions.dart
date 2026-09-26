part of 'repository_detail_screen.dart';

mixin _RepositoryDetailScreenActions on ConsumerState<RepositoryDetailScreen> {
  late Future<GitHubRepository> _repositoryFuture;
  late Future<List<RepositoryWorkflowRun>> _runsFuture;

  void initializeRepositoryDetailState() {
    final cached = ref
        .read(repositoryServiceProvider)
        .cachedRepository(widget.repositoryFullName);
    _repositoryFuture = cached == null
        ? _loadRepository()
        : Future<GitHubRepository>.value(cached);
    _runsFuture = widget.readOnly
        ? Future<List<RepositoryWorkflowRun>>.value(const [])
        : _loadRuns();
    if (cached != null) {
      Future<void>.microtask(_refreshRepositoryInBackground);
    }
  }

  Future<void> _refreshRepositoryInBackground() async {
    try {
      final fresh = await _loadRepository();
      if (!mounted) return;
      setState(() => _repositoryFuture = Future<GitHubRepository>.value(fresh));
      ref.invalidate(repositoryProjectInfoProvider(fresh));
    } catch (_) {
      // O cache já permite usar a tela; uma atualização remota lenta não deve
      // substituir conteúdo válido por um spinner ou erro.
    }
  }

  Future<GitHubRepository> _loadRepository() async {
    final service = ref.read(repositoryServiceProvider);
    return service
        .getRepository(widget.repositoryFullName)
        .timeout(const Duration(seconds: 12));
  }

  void _retryRepositoryLoad() {
    final cached = ref
        .read(repositoryServiceProvider)
        .cachedRepository(widget.repositoryFullName);
    setState(() {
      _repositoryFuture = cached == null
          ? _loadRepository()
          : Future<GitHubRepository>.value(cached);
      _runsFuture = widget.readOnly
          ? Future<List<RepositoryWorkflowRun>>.value(const [])
          : _loadRuns();
    });
    if (cached != null) {
      Future<void>.microtask(_refreshRepositoryInBackground);
    }
  }

  Future<List<RepositoryWorkflowRun>> _loadRuns() => ref
      .read(repositoryGitServiceProvider)
      .listWorkflowRuns(widget.repositoryFullName)
      .timeout(
        const Duration(seconds: 12),
        onTimeout: () => const <RepositoryWorkflowRun>[],
      );

  Future<void> _refresh() async {
    if (!widget.readOnly) {
      ref.invalidate(repositoryArtifactsProvider(widget.repositoryFullName));
      ref.invalidate(repositoryReleaseAssetsProvider(widget.repositoryFullName));
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
            onPressed: () => Navigator.pop(dialogContext),
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
      if (project == null || !mounted) return;

      final selectedBranch = await _chooseUploadBranch(repository);
      if (selectedBranch == null || !mounted) return;
      var targetBranch = selectedBranch;

      late final ManagedUploadBuildPolicy buildPolicy;
      while (true) {
        final preparation = await _prepareUpload(
          project: project,
          repository: repository,
          targetBranch: targetBranch,
        );
        if (preparation == null || !mounted) return;

        if (preparation.permissionDecision.blocked) {
          await presentRepositoryPermissionDecision(
            context,
            preparation.permissionDecision,
          );
          return;
        }

        final confirmation = await _confirmZip(
          project,
          repository,
          preparation.repositoryInfo!,
          targetBranch,
          preparation.branchHasApkWorkflow,
          preparation.syncPreview,
          preparation.rateLimit,
        );
        if (confirmation == null || !mounted) return;

        if (confirmation.changeBranch) {
          final changedBranch = await _chooseUploadBranch(
            repository,
            initialBranchName: targetBranch.name,
          );
          if (!mounted) return;
          if (changedBranch == null) continue;
          targetBranch = changedBranch;
          continue;
        }
        final confirmedPolicy = confirmation.buildPolicy;
        if (confirmedPolicy == null) return;
        buildPolicy = confirmedPolicy;
        break;
      }

      if (buildPolicy == ManagedUploadBuildPolicy.automatic) {
        final buildDecision = await _checkPermissionWithProgress(
          repositoryFullName: repository.fullName,
          action: RepositoryCriticalAction.sendBuild,
          label: 'Verificando permissão para iniciar a build…',
        );
        if (buildDecision == null || !mounted) return;
        final buildAllowed = await presentRepositoryPermissionDecision(
          context,
          buildDecision,
        );
        if (!buildAllowed || !mounted) return;
      }

      final manager = ref.read(uploadManagerProvider);
      final upload = manager.startBuild(
        project: project,
        repositoryFullName: repository.fullName,
        branch: targetBranch.name,
        buildPolicy: buildPolicy,
      );
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (_) => UploadProgressDialog(uploadId: upload.id),
      );
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<_UploadPreparation?> _prepareUpload({
    required ZipProjectPreview project,
    required GitHubRepository repository,
    required RepositoryBranch targetBranch,
  }) async {
    final status = ValueNotifier<String>('Verificando permissões da branch…');
    final overlay = _showOperationOverlay(status, targetBranch.name);
    try {
      final action = project.hasWorkflowFiles
          ? RepositoryCriticalAction.syncProjectWithWorkflows
          : RepositoryCriticalAction.syncProject;
      final decision = await ref
          .read(permissionPreflightServiceProvider)
          .check(repository.fullName, action)
          .timeout(const Duration(seconds: 15));
      if (decision.blocked) {
        return _UploadPreparation(permissionDecision: decision);
      }

      status.value = 'Analisando versão, arquivos e workflow…';
      final repositoryInfoFuture = ref
          .read(repositoryProjectInfoServiceProvider)
          .load(repository, branch: targetBranch.name)
          .timeout(const Duration(seconds: 18));
      final syncPreviewFuture = (() async {
        try {
          return await ref
              .read(gitProjectUploadServiceProvider)
              .previewZipSync(
                project: project,
                repositoryFullName: repository.fullName,
                branch: targetBranch.name,
              )
              .timeout(const Duration(seconds: 18));
        } catch (_) {
          return null;
        }
      })();
      final rateLimitFuture = (() async {
        try {
          return await ref
              .read(repositoryGitServiceProvider)
              .loadRateLimit()
              .timeout(const Duration(seconds: 10));
        } catch (_) {
          return null;
        }
      })();
      final workflowFuture = _detectBranchApkWorkflow(
        repository,
        targetBranch,
        project,
      ).timeout(const Duration(seconds: 12), onTimeout: () => null);

      final repositoryInfo = await repositoryInfoFuture;
      final syncPreview = await syncPreviewFuture;
      final rateLimit = await rateLimitFuture;
      final branchHasApkWorkflow = await workflowFuture;
      return _UploadPreparation(
        permissionDecision: decision,
        repositoryInfo: repositoryInfo,
        syncPreview: syncPreview,
        rateLimit: rateLimit,
        branchHasApkWorkflow: branchHasApkWorkflow,
      );
    } finally {
      overlay.remove();
      status.dispose();
    }
  }

  Future<RepositoryPermissionPreflightDecision?> _checkPermissionWithProgress({
    required String repositoryFullName,
    required RepositoryCriticalAction action,
    required String label,
  }) async {
    final status = ValueNotifier<String>(label);
    final overlay = _showOperationOverlay(status, null);
    try {
      return await ref
          .read(permissionPreflightServiceProvider)
          .check(repositoryFullName, action)
          .timeout(const Duration(seconds: 15));
    } finally {
      overlay.remove();
      status.dispose();
    }
  }

  OverlayEntry _showOperationOverlay(
    ValueNotifier<String> status,
    String? branch,
  ) {
    final entry = OverlayEntry(
      builder: (_) => _RepositoryOperationOverlay(
        status: status,
        branch: branch,
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(entry);
    return entry;
  }

  Future<RepositoryBranch?> _chooseUploadBranch(
    GitHubRepository repository, {
    String? initialBranchName,
  }) async {
    final preferenceKey =
        'uploads.last_branch.${repository.fullName.toLowerCase()}';
    dynamic stored;
    try {
      stored = await ref.read(localDatabaseProvider).readJson(preferenceKey);
    } catch (_) {
      // Preferência é best-effort: falha local não pode bloquear o envio.
    }
    if (!mounted) return null;

    final initial = initialBranchName?.trim().isNotEmpty == true
        ? initialBranchName!.trim()
        : stored is String && stored.trim().isNotEmpty
            ? stored.trim()
            : repository.defaultBranch.trim().isEmpty
                ? 'main'
                : repository.defaultBranch.trim();

    final selected = await showRepositoryBranchSelector(
      context: context,
      ref: ref,
      repositoryFullName: repository.fullName,
      currentBranch: initial,
      defaultBranch: repository.defaultBranch,
      emptyBranchName: repository.defaultBranch.trim().isEmpty
          ? 'main'
          : repository.defaultBranch.trim(),
      allowCreate: true,
    );
    if (selected != null) {
      try {
        await ref.read(localDatabaseProvider).putJson(preferenceKey, selected.name);
      } catch (_) {
        // Preferência é best-effort. O envio continua normalmente.
      }
    }
    return selected;
  }

  Future<bool?> _detectBranchApkWorkflow(
    GitHubRepository repository,
    RepositoryBranch targetBranch,
    ZipProjectPreview project,
  ) async {
    if (project.hasWorkflowFiles) return null;

    try {
      return await ref.read(repositoryGitServiceProvider).hasApkBuildWorkflow(
            repositoryFullName: repository.fullName,
            branch: targetBranch.name,
          );
    } catch (_) {
      // A confirmação pode continuar mesmo quando a inspeção de workflow está
      // temporariamente indisponível; a etapa pós-upload fará a validação real.
      return null;
    }
  }

  Future<_ConfirmZipResult?> _confirmZip(
    ZipProjectPreview project,
    GitHubRepository repository,
    RepositoryProjectInfo repositoryInfo,
    RepositoryBranch targetBranch,
    bool? branchHasApkWorkflow,
    ProjectSyncPreview? syncPreview,
    GitHubRateLimitSnapshot? rateLimit,
  ) {
    final check = ProjectSafetyCheck.compare(
      project: project,
      repository: repository,
      repositoryInfo: repositoryInfo,
    );

    var buildPolicy = branchHasApkWorkflow == false
        ? ManagedUploadBuildPolicy.skipNoWorkflow
        : ManagedUploadBuildPolicy.automatic;

    return showDialog<_ConfirmZipResult>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        titlePadding: const EdgeInsets.fromLTRB(16, 15, 16, 4),
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        actionsPadding: const EdgeInsets.fromLTRB(10, 2, 10, 10),
        title: Text(check.blocked ? 'Risco alto detectado' : 'Conferir envio'),
        content: AdaptiveDialogBody(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProjectVersionBanner(versionLabel: project.displayVersionLabel),
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
                  value: project.displayVersionLabel ?? 'Não identificada',
                  icon: Icons.new_releases_outlined,
                ),
                _BuildSafetyRow(
                  label: 'Repositório aberto',
                  value: repositoryInfo.projectName,
                  icon: Icons.cloud_outlined,
                ),
                _BuildSafetyRow(
                  label: 'Branch de destino',
                  value: targetBranch.isProtected
                      ? '${targetBranch.name} • protegida'
                      : targetBranch.name,
                  icon: targetBranch.isProtected
                      ? Icons.lock_outline_rounded
                      : Icons.account_tree_outlined,
                  actionLabel: 'Alterar',
                  onAction: () => Navigator.pop(
                    dialogContext,
                    const _ConfirmZipResult.changeBranch(),
                  ),
                ),
                _BuildSafetyRow(
                  label: 'Versão no GitHub',
                  value: repositoryInfo.displayVersionLabel ?? 'Não identificada',
                  icon: Icons.history_rounded,
                ),
                _BuildSafetyRow(
                  label: 'Prévia da sincronização',
                  value: syncPreview == null
                      ? 'Não disponível nesta tentativa'
                      : '${syncPreview.createdCount} novos • ${syncPreview.modifiedCount} alterados • ${syncPreview.deletedCount} removidos',
                  icon: Icons.difference_outlined,
                  actionLabel: syncPreview == null ? null : 'Ver arquivos',
                  onAction: syncPreview == null
                      ? null
                      : () => _showSyncPreview(dialogContext, syncPreview),
                ),
                if (rateLimit != null)
                  _BuildSafetyRow(
                    label: 'API GitHub',
                    value: rateLimit.label,
                    icon: Icons.speed_rounded,
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
                    borderRadius: BorderRadius.circular(4),
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
                      if (check.warning || check.blocked)
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Entender e corrigir este aviso',
                          onPressed: () => _showBuildSafetyHelp(
                            dialogContext,
                            project,
                            repositoryInfo,
                            check,
                          ),
                          icon: const Icon(Icons.help_outline_rounded),
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
                  'Destino: ${repository.fullName} → ${targetBranch.name}',
                ),
                const SizedBox(height: 10),
                Builder(
                  builder: (context) {
                    final message = project.hasWorkflowFiles
                        ? 'O ZIP contém workflow do GitHub Actions. Depois do envio, o GitHub Manager verificará se existe uma build de APK compatível. Workflows existentes que não vierem no ZIP continuam protegidos contra remoção acidental.'
                        : branchHasApkWorkflow == false
                            ? 'Este projeto não possui workflow de build de APK nesta branch. Isso é normal para projetos que não precisam ser compilados pelo GitHub Actions: os arquivos serão atualizados e o envio terminará como sucesso, sem falso erro de build.'
                            : branchHasApkWorkflow == true
                                ? 'Foi detectado um workflow de build de APK nesta branch. Depois do envio, o GitHub Manager verificará ou iniciará a build normalmente.'
                                : 'O envio sincroniza os arquivos do projeto com o ZIP. Se esta branch não tiver workflow de build compatível, o envio será concluído normalmente sem tratar isso como erro.';
                    return Text(message);
                  },
                ),
                const SizedBox(height: 8),
                if (branchHasApkWorkflow == false)
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: Icon(Icons.code_rounded),
                    title: Text('Build não utilizada neste projeto'),
                    subtitle: Text(
                      'O GitHub Manager enviará os arquivos sem tentar executar GitHub Actions.',
                    ),
                  )
                else
                  StatefulBuilder(
                    builder: (context, setBuildState) => CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: buildPolicy == ManagedUploadBuildPolicy.automatic,
                      onChanged: (value) {
                        setBuildState(() {
                          buildPolicy = value == true
                              ? ManagedUploadBuildPolicy.automatic
                              : ManagedUploadBuildPolicy.skipByUser;
                        });
                      },
                      title: const Text('Iniciar build após o envio'),
                      subtitle: Text(
                        branchHasApkWorkflow == true
                            ? 'Workflow de APK detectado nesta branch.'
                            : 'Se houver um workflow de APK compatível após o envio, o GitHub Manager tentará executá-lo.',
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: check.blocked
                ? () async {
                    final forced = await showDialog<bool>(
                      context: dialogContext,
                      builder: (confirmContext) => AlertDialog(
                        insetPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 16,
                        ),
                        titlePadding:
                            const EdgeInsets.fromLTRB(16, 15, 16, 4),
                        contentPadding:
                            const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        actionsPadding:
                            const EdgeInsets.fromLTRB(10, 2, 10, 10),
                        title: const Text('Forçar envio para este repositório?'),
                        content: Text(
                          'Foram encontrados identificadores fortes divergentes. '
                          'O ZIP será sincronizado em ${repository.fullName} → ${targetBranch.name} '
                          'e poderá substituir ou remover arquivos atuais. Continue somente se este destino estiver correto.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(confirmContext, false),
                            child: const Text('Voltar'),
                          ),
                          FilledButton.icon(
                            onPressed: () => Navigator.pop(confirmContext, true),
                            icon: const Icon(Icons.warning_amber_rounded),
                            label: const Text('Forçar envio'),
                          ),
                        ],
                      ),
                    );
                    if (forced == true && dialogContext.mounted) {
                      Navigator.pop(
                        dialogContext,
                        _ConfirmZipResult.submit(buildPolicy),
                      );
                    }
                  }
                : () => Navigator.pop(
                      dialogContext,
                      _ConfirmZipResult.submit(buildPolicy),
                    ),
            icon: Icon(
              check.blocked || check.warning
                  ? Icons.warning_amber_rounded
                  : Icons.cloud_upload_outlined,
            ),
            label: Text(
              check.blocked
                  ? 'Revisar e enviar'
                  : check.warning
                      ? 'Enviar mesmo assim'
                      : 'Enviar versão',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showSyncPreview(
    BuildContext parentContext,
    ProjectSyncPreview preview,
  ) async {
    Widget section(String title, List<String> paths, IconData icon) {
      if (paths.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18),
                const SizedBox(width: 7),
                Text('$title (${paths.length})',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 5),
            ...paths.take(80).map(
                  (path) => Padding(
                    padding: const EdgeInsets.only(left: 25, bottom: 3),
                    child: Text(path),
                  ),
                ),
            if (paths.length > 80)
              Padding(
                padding: const EdgeInsets.only(left: 25),
                child: Text('… e mais ${paths.length - 80} arquivo(s)'),
              ),
          ],
        ),
      );
    }

    await showDialog<void>(
      context: parentContext,
      builder: (context) => AlertDialog(
        title: const Text('Prévia das alterações'),
        content: AdaptiveDialogBody(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${preview.createdCount} novos • ${preview.modifiedCount} alterados • ${preview.deletedCount} removidos • ${preview.unchangedCount} sem alteração',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                section('Novos', preview.createdPaths, Icons.add_circle_outline_rounded),
                section('Alterados', preview.modifiedPaths, Icons.edit_outlined),
                section('Removidos', preview.deletedPaths, Icons.delete_outline_rounded),
                if (!preview.hasChanges)
                  const Text('O ZIP já corresponde ao conteúdo desta branch.'),
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Future<void> _showBuildSafetyHelp(
    BuildContext parentContext,
    ZipProjectPreview project,
    RepositoryProjectInfo repositoryInfo,
    ProjectSafetyCheck check,
  ) async {
    final zipVersion = project.displayVersionLabel ?? 'não identificada';
    final githubVersion = repositoryInfo.displayVersionLabel ?? 'não identificada';

    await showDialog<void>(
      context: parentContext,
      builder: (helpContext) => AlertDialog(
        title: const Text('Como corrigir este aviso?'),
        content: AdaptiveDialogBody(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  check.versionComparison == ProjectVersionComparison.unknown
                      ? 'A identidade do projeto tem sinais compatíveis, mas pelo menos uma das versões não foi encontrada em uma fonte confiável.'
                      : 'O GitHub Manager encontrou uma diferença que merece conferência antes do envio.',
                ),
                const SizedBox(height: 12),
                _BuildSafetyRow(
                  label: 'Versão no ZIP',
                  value: zipVersion,
                  icon: Icons.folder_zip_outlined,
                ),
                _BuildSafetyRow(
                  label: 'Versão no GitHub',
                  value: githubVersion,
                  icon: Icons.cloud_outlined,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Para a comparação funcionar com segurança, mantenha a versão em um arquivo do próprio projeto:',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text('• Node/JavaScript: campo "version" do package.json.'),
                const Text('• Flutter: campo "version" do pubspec.yaml.'),
                const Text('• Android/Kotlin: versionName e versionCode no app/build.gradle(.kts).'),
                const Text('• Godot: config/version no project.godot.'),
                const Text('• Python: campo version no pyproject.toml.'),
                const Text('• Rust: campo version no Cargo.toml.'),
                const Text('• Projetos compatíveis: github-manager.json, app_identity.json, MANIFEST.json, arquivo VERSION ou VERSION= em manager.sh.'),
                const SizedBox(height: 10),
                const Text(
                  'Se não houver metadado interno, o GitHub Manager pode mostrar uma versão inferida do nome do ZIP apenas como pista. Para comparação segura, prefira uma das fontes internas acima.',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(helpContext),
            child: const Text('Entendi'),
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
    final favoriteIds = await ref.read(favoriteRepositoryIdsProvider.future);
    if (!mounted) return;
    final isFavorite = favoriteIds.contains(repository.id);
    final action = await showRepositoryActionsSheet(
      context,
      repository,
      isFavorite: isFavorite,
    );
    if (action == null || !mounted) return;

    if (action == RepositoryAction.toggleFavorite) {
      try {
        await ref.read(repositoryServiceProvider).setRepositoryFavorite(
              repository,
              favorite: !isFavorite,
            );
        ref.invalidate(favoriteRepositoryIdsProvider);
        if (mounted) {
          showCenteredNotice(
            context,
            isFavorite
                ? '${repository.name} não ficará mais fixado no topo.'
                : '${repository.name} fixado no topo.',
            kind: CenteredNoticeKind.success,
          );
        }
      } catch (error) {
        if (mounted) _showError(error);
      }
    } else if (action == RepositoryAction.edit) {
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
        if (!mounted) return;
        if (updated.fullName != widget.repositoryFullName) {
          context.go('/repositories/${updated.fullName}');
          return;
        }
        ref.invalidate(repositoryProjectInfoProvider(updated));
        showCenteredNotice(
          context,
          'Repositório ${updated.name} atualizado com sucesso.',
          kind: CenteredNoticeKind.success,
        );
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
        ref.invalidate(favoriteRepositoryIdsProvider);
        if (!mounted) return;
        showCenteredNotice(
          context,
          'Repositório renomeado para ${renamed.name}.',
          kind: CenteredNoticeKind.success,
        );
        context.go('/repositories/${renamed.fullName}');
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
        ref.invalidate(favoriteRepositoryIdsProvider);
        if (mounted) context.go('/');
      } catch (error) {
        if (mounted) _showError(error);
      }
    }
  }

  void _showError(Object error) {
    final message = error is TimeoutException
        ? 'O GitHub demorou para responder. Tente novamente.'
        : error is AppException
            ? error.message
            : 'Não foi possível concluir a operação.';
    showCenteredNotice(context, message);
  }

}

class _UploadPreparation {
  const _UploadPreparation({
    required this.permissionDecision,
    this.repositoryInfo,
    this.syncPreview,
    this.rateLimit,
    this.branchHasApkWorkflow,
  });

  final RepositoryPermissionPreflightDecision permissionDecision;
  final RepositoryProjectInfo? repositoryInfo;
  final ProjectSyncPreview? syncPreview;
  final GitHubRateLimitSnapshot? rateLimit;
  final bool? branchHasApkWorkflow;
}

class _ConfirmZipResult {
  const _ConfirmZipResult.submit(this.buildPolicy) : changeBranch = false;

  const _ConfirmZipResult.changeBranch()
      : buildPolicy = null,
        changeBranch = true;

  final ManagedUploadBuildPolicy? buildPolicy;
  final bool changeBranch;
}
