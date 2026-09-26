part of 'repository_detail_screen.dart';

class _RepositoryHeader extends StatelessWidget {
  const _RepositoryHeader({
    required this.repository,
    required this.info,
    required this.runsFuture,
    required this.readOnly,
    required this.detailsLoading,
  });

  final GitHubRepository repository;
  final RepositoryProjectInfo info;
  final Future<List<RepositoryWorkflowRun>> runsFuture;
  final bool readOnly;
  final bool detailsLoading;

  Future<void> _showProjectInfo(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: Theme.of(dialogContext).colorScheme.primary,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Informações do projeto',
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
                const SizedBox(height: 12),
                _ProjectInfoLine(label: 'Projeto', value: info.projectName),
                _ProjectInfoLine(
                  label: 'Versão',
                  value: info.version?.isNotEmpty == true ? 'v${info.version}' : 'Não identificada',
                ),
                _ProjectInfoLine(label: 'Repositório', value: repository.fullName),
                _ProjectInfoLine(label: 'Branch', value: repository.defaultBranch),
                _ProjectInfoLine(
                  label: 'Acesso',
                  value: repository.isPrivate ? 'Privado' : 'Público',
                ),
                if (readOnly)
                  const _ProjectInfoLine(label: 'Modo', value: 'Somente leitura'),
                const SizedBox(height: 10),
                Text(
                  'Tecnologias',
                  style: Theme.of(dialogContext).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 7),
                if (info.technologies.isEmpty)
                  Text(
                    'Nenhuma tecnologia identificada.',
                    style: Theme.of(dialogContext).textTheme.bodyMedium,
                  )
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: info.technologies
                        .map((item) => TechnologyBadge(name: item))
                        .toList(growable: false),
                  ),
                const SizedBox(height: 12),
                FutureBuilder<List<RepositoryWorkflowRun>>(
                  future: runsFuture,
                  builder: (context, snapshot) {
                    final data = snapshot.data;
                    final latest = data != null && data.isNotEmpty ? data.first : null;
                    final value = latest == null
                        ? 'Sem builds carregadas'
                        : latest.isRunning
                            ? 'Build em execução'
                            : latest.conclusion == 'success'
                                ? 'Última build concluída com sucesso'
                                : latest.conclusion == 'failure'
                                    ? 'Última build falhou'
                                    : 'Build ${latest.status}';
                    return _ProjectInfoLine(label: 'Build', value: value);
                  },
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Fechar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .38)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 7,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      info.projectName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    if (info.version?.isNotEmpty == true)
                      Text(
                        'v${info.version}',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                  ],
                ),
              ),
              _RepositoryHeaderShortcut(
                tooltip: 'APKs e artifacts',
                icon: Icons.android_rounded,
                onPressed: () => context.push(
                  '/repositories/${repository.fullName}/artifacts?readOnly=${readOnly ? '1' : '0'}',
                ),
              ),
              _RepositoryHeaderShortcut(
                tooltip: 'Commits',
                icon: Icons.commit_rounded,
                onPressed: () => context.push(
                  '/repositories/${repository.fullName}/commits?branch=${Uri.encodeQueryComponent(repository.defaultBranch)}&readOnly=${readOnly ? '1' : '0'}',
                ),
              ),
              if (!readOnly)
                _RepositoryHeaderShortcut(
                  tooltip: 'Diagnóstico do token',
                  icon: Icons.verified_user_outlined,
                  onPressed: () => context.push(
                    '/repositories/${repository.fullName}/permissions',
                  ),
                ),
              if (!readOnly)
                _RepositoryHeaderShortcut(
                  tooltip: 'Issues / Bugs',
                  icon: Icons.bug_report_outlined,
                  onPressed: () => context.push(
                    '/repositories/${repository.fullName}/bugs',
                  ),
                ),
              _RepositoryHeaderShortcut(
                tooltip: 'Informações do projeto',
                icon: Icons.help_outline_rounded,
                onPressed: () => _showProjectInfo(context),
              ),
            ],
          ),
          Text(
            repository.fullName,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          if (repository.description?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Text(
              repository.description!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
          if (detailsLoading) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(minHeight: 2),
            const SizedBox(height: 5),
            Text(
              'Atualizando versão e tecnologias…',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RepositoryHeaderShortcut extends StatelessWidget {
  const _RepositoryHeaderShortcut({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.all(5),
        constraints: const BoxConstraints.tightFor(width: 34, height: 34),
        icon: Icon(icon, size: 20),
      );
}

class _ProjectInfoLine extends StatelessWidget {
  const _ProjectInfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 88,
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
      );
}

class _ProjectVersionBanner extends StatelessWidget {
  const _ProjectVersionBanner({required this.versionLabel});

  final String? versionLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final version = versionLabel?.trim();
    final identified = version?.isNotEmpty == true;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .55)),
      ),
      child: Row(
        children: [
          Icon(
            identified ? Icons.new_releases_outlined : Icons.help_outline_rounded,
            size: 20,
            color: identified ? scheme.primary : scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VERSÃO DO PROJETO A ENVIAR',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .35,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  identified ? version! : 'Não identificada',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BuildSafetyRow extends StatelessWidget {
  const _BuildSafetyRow({
    required this.label,
    required this.value,
    required this.icon,
    this.actionLabel,
    this.onAction,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

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
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(width: 6),
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      );
}

class _CompactQuickAction extends StatelessWidget {
  const _CompactQuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool filled;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final callback = enabled ? onTap : null;
    final child = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ],
    );
    return SizedBox(
      height: 48,
      child: filled
          ? FilledButton(
              onPressed: callback,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              child: child,
            )
          : OutlinedButton(
              onPressed: callback,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                visualDensity: VisualDensity.compact,
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .48),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
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
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .34),
          ),
        ),
        child: ListTile(
          onTap: onTap,
          dense: true,
          visualDensity: const VisualDensity(vertical: -1),
          contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(4),
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

class _RepositoryOperationOverlay extends StatelessWidget {
  const _RepositoryOperationOverlay({
    required this.status,
    required this.branch,
  });

  final ValueListenable<String> status;
  final String? branch;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.black.withValues(alpha: .18),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 28),
            elevation: 6,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.6),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Preparando envio',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        if (branch?.isNotEmpty == true) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Branch: $branch',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                        const SizedBox(height: 7),
                        ValueListenableBuilder<String>(
                          valueListenable: status,
                          builder: (_, value, __) => Text(value),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RepositoryLoadingView extends StatelessWidget {
  const _RepositoryLoadingView({required this.repositoryFullName});

  final String repositoryFullName;

  @override
  Widget build(BuildContext context) {
    final name = repositoryFullName.split('/').last;
    final scheme = Theme.of(context).colorScheme;
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverAppBar(
          pinned: true,
          title: Text(name.isEmpty ? 'Projeto' : name),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
          sliver: SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: .38),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isEmpty ? 'Carregando projeto' : name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    repositoryFullName,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 14),
                  const LinearProgressIndicator(minHeight: 3),
                  const SizedBox(height: 8),
                  Text(
                    'Carregando dados do GitHub… A tela será preenchida por partes.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 18)),
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
            children: const [
              _RepositoryLoadingTile(
                icon: Icons.menu_book_outlined,
                title: 'README',
              ),
              SizedBox(height: 7),
              _RepositoryLoadingTile(
                icon: Icons.folder_open_rounded,
                title: 'Arquivos',
              ),
              SizedBox(height: 7),
              _RepositoryLoadingTile(
                icon: Icons.play_circle_outline_rounded,
                title: 'Builds',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RepositoryLoadingTile extends StatelessWidget {
  const _RepositoryLoadingTile({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: const Text('Carregando…'),
          trailing: const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
}

class _RepositoryErrorView extends StatelessWidget {
  const _RepositoryErrorView({
    required this.repositoryFullName,
    required this.message,
    required this.onRetry,
  });

  final String repositoryFullName;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final name = repositoryFullName.split('/').last;
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverAppBar(title: Text(name.isEmpty ? 'Projeto' : name)),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.cloud_off_outlined, size: 30),
                    const SizedBox(height: 12),
                    Text(
                      'Não foi possível concluir o carregamento',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(message),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
