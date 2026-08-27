import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:github_manager/core/errors/app_exception.dart';
import 'package:github_manager/core/widgets/centered_notice.dart';
import 'package:github_manager/features/permissions/domain/repository_permission_report.dart';
import 'package:github_manager/features/permissions/presentation/token_permission_providers.dart';

class RepositoryPermissionDiagnosticsScreen extends ConsumerWidget {
  const RepositoryPermissionDiagnosticsScreen({
    required this.repositoryFullName,
    super.key,
  });

  final String repositoryFullName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(
      repositoryPermissionReportProvider(repositoryFullName),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnóstico do token'),
        actions: [
          IconButton(
            tooltip: 'Testar novamente',
            onPressed: () => ref.invalidate(
              repositoryPermissionReportProvider(repositoryFullName),
            ),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(repositoryPermissionReportProvider(repositoryFullName));
          await ref.read(
            repositoryPermissionReportProvider(repositoryFullName).future,
          );
        },
        child: report.when(
          loading: () => const _LoadingView(),
          error: (error, _) => _ErrorView(
            error: error,
            onRetry: () => ref.invalidate(
              repositoryPermissionReportProvider(repositoryFullName),
            ),
          ),
          data: (data) => _ReportView(report: data),
        ),
      ),
    );
  }
}

class _ReportView extends StatelessWidget {
  const _ReportView({required this.report});

  final RepositoryPermissionReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        report.repositoryFullName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
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
                      text: 'Modo seguro',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Nenhuma alteração é feita durante este teste. O app consulta '
                  'endpoints de leitura e usa os escopos disponíveis para explicar '
                  'o que está confirmado e o que ainda precisa ser conferido no token.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (report.classicScopes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Escopos do PAT clássico',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    report.classicScopes.join(', '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (report.deniedCount > 0)
          Card(
            color: theme.colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${report.deniedCount} área(s) possuem bloqueio confirmado. '
                      'Abra os cartões abaixo para ver a permissão ou o papel que falta.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (report.deniedCount > 0) const SizedBox(height: 12),
        ...report.capabilities.map(
          (capability) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _CapabilityCard(capability: capability),
          ),
        ),
        const SizedBox(height: 4),
        FilledButton.icon(
          onPressed: () async {
            await Clipboard.setData(
              ClipboardData(text: report.diagnosticText()),
            );
            if (context.mounted) {
              showCenteredNotice(context, 'Diagnóstico copiado.');
            }
          },
          icon: const Icon(Icons.copy_all_rounded),
          label: const Text('Copiar diagnóstico'),
        ),
        const SizedBox(height: 10),
        Text(
          'Para PAT fine-grained, permissões de escrita não são testadas com '
          'operações destrutivas. Quando aparecer “Verifique no token”, a permissão '
          'necessária é exibida no próprio cartão.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
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
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: Icon(_iconFor(capability.area)),
        title: Text(
          capability.title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(capability.summary),
        trailing: _AreaIndicator(capability: capability),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
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
