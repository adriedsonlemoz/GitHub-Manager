import 'package:flutter/material.dart';
import 'package:github_manager/core/platform/platform_actions.dart';
import 'package:github_manager/features/repositories/data/play_readiness_service.dart';
import 'package:github_manager/features/repositories/domain/github_repository.dart';
import 'package:github_manager/features/repositories/domain/play_readiness_report.dart';

Future<void> showPlayReadinessDialog({
  required BuildContext context,
  required GitHubRepository repository,
  required PlayReadinessService service,
}) async {
  await showDialog<void>(
    context: context,
    builder: (context) => _PlayReadinessDialog(
      repository: repository,
      service: service,
    ),
  );
}

class _PlayReadinessDialog extends StatefulWidget {
  const _PlayReadinessDialog({required this.repository, required this.service});

  final GitHubRepository repository;
  final PlayReadinessService service;

  @override
  State<_PlayReadinessDialog> createState() => _PlayReadinessDialogState();
}

class _PlayReadinessDialogState extends State<_PlayReadinessDialog> {
  late Future<PlayReadinessReport> _future;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    _future = widget.service.inspect(widget.repository);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 540,
          maxHeight: MediaQuery.sizeOf(context).height * .85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 5, 5),
              child: Row(
                children: [
                  Icon(Icons.storefront_outlined, color: scheme.primary),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Preparação para Google Play',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            )),
                        Text(widget.repository.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Reavaliar',
                    onPressed: () => setState(_refresh),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                  IconButton(
                    tooltip: 'Fechar',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: FutureBuilder<PlayReadinessReport>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 12),
                          Text('Verificando arquivos do repositório…'),
                        ],
                      ),
                    );
                  }
                  if (snapshot.hasError || !snapshot.hasData) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Não foi possível consultar o código do projeto.'),
                          const SizedBox(height: 5),
                          const Text('Verifique rede, permissões, branch e limites da API. Nenhum resultado foi presumido.'),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () => setState(_refresh),
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Tentar novamente'),
                          ),
                        ],
                      ),
                    );
                  }
                  final report = snapshot.data!;
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Branch: ${report.branch}', style: theme.textTheme.bodySmall),
                        const SizedBox(height: 7),
                        if (!report.androidProject) ...[
                          _AuditMessage(report.note ?? 'Tipo do projeto não reconhecido.'),
                        ] else ...[
                          Text('Código: ${report.verified} indícios positivos • ${report.attention} pontos de atenção • ${report.unknown} não confirmados',
                              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 10),
                          const _AuditMessage('Avaliação parcial do código-fonte. Não confirma aprovação nem publicação na Play Console.'),
                          if (report.note != null) ...[
                            const SizedBox(height: 8),
                            _AuditMessage(report.note!),
                          ],
                          const SizedBox(height: 14),
                          Text('Verificações técnicas', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 7),
                          for (final check in report.automatic) _PlayCheckTile(check: check),
                          const SizedBox(height: 12),
                          Text('Confirmar na Play Console', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 7),
                          for (final check in report.manual) _PlayCheckTile(check: check),
                        ],
                        const SizedBox(height: 10),
                        TextButton.icon(
                          onPressed: () => PlatformActions.openUri(
                            'https://support.google.com/googleplay/android-developer/answer/11926878?hl=pt-BR',
                          ),
                          icon: const Icon(Icons.open_in_new_rounded, size: 17),
                          label: const Text('Requisitos oficiais de API'),
                        ),
                        TextButton.icon(
                          onPressed: () => PlatformActions.openUri(
                            'https://play.google.com/console/',
                          ),
                          icon: const Icon(Icons.open_in_new_rounded, size: 17),
                          label: const Text('Abrir Play Console'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
              child: Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Fechar'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuditMessage extends StatelessWidget {
  const _AuditMessage(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Text(
        message,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
}

class _PlayCheckTile extends StatelessWidget {
  const _PlayCheckTile({required this.check});
  final PlayCheck check;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final icon = switch (check.state) {
      PlayCheckState.verified => Icons.check_circle_outline_rounded,
      PlayCheckState.attention => Icons.warning_amber_rounded,
      PlayCheckState.unknown => Icons.help_outline_rounded,
    };
    final color = switch (check.state) {
      PlayCheckState.verified => scheme.primary,
      PlayCheckState.attention => scheme.error,
      PlayCheckState.unknown => scheme.onSurfaceVariant,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: scheme.outlineVariant.withValues(alpha: .6)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 19, color: color),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(check.title, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(check.detail, style: Theme.of(context).textTheme.bodySmall),
                  if (check.evidence != null)
                    Text('Fonte: ${check.evidence}', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
