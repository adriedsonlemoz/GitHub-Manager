part of 'repository_permission_diagnostics_screen.dart';

class _ReportView extends StatelessWidget {
  const _ReportView({required this.report});

  final RepositoryPermissionReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 88),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 9),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.verified_user_outlined,
                    size: 20,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      report.repositoryFullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (report.deniedCount > 0)
                    _InfoChip(
                      icon: Icons.warning_amber_rounded,
                      text: '${report.deniedCount} bloqueio(s)',
                    ),
                ],
              ),
              const SizedBox(height: 7),
              Wrap(
                spacing: 6,
                runSpacing: 5,
                children: [
                  _InfoChip(
                    icon: Icons.key_rounded,
                    text: report.tokenKindLabel,
                  ),
                  _InfoChip(
                    icon: Icons.admin_panel_settings_outlined,
                    text: report.repositoryRole,
                  ),
                  const _InfoChip(
                    icon: Icons.shield_outlined,
                    text: 'Somente teste',
                  ),
                ],
              ),
              if (report.classicScopes.isNotEmpty) ...[
                const SizedBox(height: 7),
                Text(
                  'Escopos: ${report.classicScopes.join(', ')}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        ...report.capabilities.map(
          (capability) => Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: _CapabilityCard(capability: capability),
          ),
        ),
        const SizedBox(height: 5),
        SizedBox(
          height: 42,
          child: FilledButton.tonalIcon(
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: report.diagnosticText()),
              );
              if (context.mounted) {
                showCenteredNotice(context, 'Diagnóstico copiado.');
              }
            },
            icon: const Icon(Icons.copy_all_rounded, size: 18),
            label: const Text('Copiar diagnóstico'),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          '“Verifique no token” indica uma permissão que não pode ser testada '
          'sem executar uma alteração real no repositório.',
          textAlign: TextAlign.center,
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _CapabilityCard extends StatelessWidget {
  const _CapabilityCard({required this.capability});

  final RepositoryPermissionCapability capability;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(11),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 11),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        leading: Icon(_iconFor(capability.area), size: 20),
        title: Text(
          capability.title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          capability.summary,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: _AreaIndicator(capability: capability),
        children: [
          if (capability.read != null)
            _ResultRow(label: 'Leitura', result: capability.read!),
          if (capability.read != null && capability.write != null)
            const Divider(height: 18),
          if (capability.write != null)
            _ResultRow(label: 'Escrita', result: capability.write!),
          if (capability.area == RepositoryPermissionArea.contents) ...[
            const SizedBox(height: 12),
            Text(
              'Observação: alterar arquivos dentro de .github/workflows exige '
              'Workflows: write além de Contents: write em PAT fine-grained; '
              'PAT clássico precisa do escopo workflow além de repo.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static IconData _iconFor(RepositoryPermissionArea area) => switch (area) {
        RepositoryPermissionArea.contents => Icons.folder_open_rounded,
        RepositoryPermissionArea.actions => Icons.play_circle_outline_rounded,
        RepositoryPermissionArea.secrets => Icons.key_rounded,
        RepositoryPermissionArea.administration =>
          Icons.admin_panel_settings_outlined,
        RepositoryPermissionArea.deletion => Icons.delete_forever_outlined,
      };
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.label, required this.result});

  final String label;
  final PermissionAccessResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _colorFor(theme, result.verdict);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(_iconFor(result.verdict), color: color, size: 21),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '$label • ',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Flexible(
                    child: Text(
                      result.label,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(result.detail),
              if (result.requiredPermission != null) ...[
                const SizedBox(height: 7),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    'Necessário: ${result.requiredPermission}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
              if (result.httpStatus != null) ...[
                const SizedBox(height: 6),
                Text(
                  'HTTP ${result.httpStatus}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static IconData _iconFor(PermissionVerdict verdict) => switch (verdict) {
        PermissionVerdict.allowed => Icons.check_circle_rounded,
        PermissionVerdict.inferred => Icons.verified_rounded,
        PermissionVerdict.denied => Icons.cancel_rounded,
        PermissionVerdict.unknown => Icons.help_rounded,
      };

  static Color _colorFor(ThemeData theme, PermissionVerdict verdict) =>
      switch (verdict) {
        PermissionVerdict.allowed => Colors.green.shade700,
        PermissionVerdict.inferred => Colors.green.shade700,
        PermissionVerdict.denied => theme.colorScheme.error,
        PermissionVerdict.unknown => Colors.orange.shade800,
      };
}

class _AreaIndicator extends StatelessWidget {
  const _AreaIndicator({required this.capability});

  final RepositoryPermissionCapability capability;

  @override
  Widget build(BuildContext context) {
    final verdicts = [
      if (capability.read != null) capability.read!.verdict,
      if (capability.write != null) capability.write!.verdict,
    ];
    final PermissionVerdict verdict;
    if (verdicts.contains(PermissionVerdict.denied)) {
      verdict = PermissionVerdict.denied;
    } else if (verdicts.contains(PermissionVerdict.unknown)) {
      verdict = PermissionVerdict.unknown;
    } else if (verdicts.contains(PermissionVerdict.inferred)) {
      verdict = PermissionVerdict.inferred;
    } else {
      verdict = PermissionVerdict.allowed;
    }
    final theme = Theme.of(context);
    final color = _ResultRow._colorFor(theme, verdict);
    return Icon(_ResultRow._iconFor(verdict), color: color);
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 6),
            Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: const [
          SizedBox(height: 80),
          Center(child: CircularProgressIndicator()),
          SizedBox(height: 20),
          Center(child: Text('Verificando permissões sem alterar o repositório…')),
        ],
      );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final message = error is AppException
        ? (error as AppException).message
        : 'Não foi possível concluir o diagnóstico do token.';
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 50),
        Icon(
          Icons.error_outline_rounded,
          size: 48,
          color: Theme.of(context).colorScheme.error,
        ),
        const SizedBox(height: 14),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Tentar novamente'),
        ),
      ],
    );
  }
}
