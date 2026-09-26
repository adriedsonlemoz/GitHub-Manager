import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:github_manager/core/widgets/adaptive_dialog.dart';
import 'package:github_manager/features/uploads/data/upload_manager_service.dart';
import 'package:github_manager/features/uploads/domain/managed_upload.dart';
import 'package:github_manager/features/uploads/presentation/upload_providers.dart';
import 'package:go_router/go_router.dart';

class UploadProgressDialog extends ConsumerWidget {
  const UploadProgressDialog({required this.uploadId, super.key});

  final String uploadId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manager = ref.watch(uploadManagerProvider);
    return StreamBuilder<List<ManagedUpload>>(
      stream: manager.stream,
      initialData: manager.items,
      builder: (context, _) {
        final item = manager.find(uploadId);
        if (item == null) {
          return AlertDialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
            titlePadding: const EdgeInsets.fromLTRB(16, 15, 16, 4),
            contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            actionsPadding: const EdgeInsets.fromLTRB(10, 2, 10, 10),
            title: const Text('Envio'),
            content: const Text('Este envio não está mais disponível.'),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fechar'),
              ),
            ],
          );
        }

        final progress = item.progress;
        final percent = progress == null ? null : (progress * 100).round();
        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
          titlePadding: const EdgeInsets.fromLTRB(16, 15, 16, 4),
          contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          actionsPadding: const EdgeInsets.fromLTRB(10, 2, 10, 10),
          title: Text(_title(item)),
          content: AdaptiveDialogBody(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Text(
                  item.phase,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                if (item.isBuildPending && item.total > 0)
                  Text(
                    'Envio concluído • ${item.total} arquivos${item.commitSha?.isNotEmpty == true ? ' • commit ${_shortSha(item.commitSha!)}' : ''}',
                  )
                else if (item.total > 0 &&
                    item.status != ManagedUploadStatus.startingBuild)
                  Text(
                    '${item.current.clamp(0, item.total)} de ${item.total} arquivos${percent == null ? '' : ' • $percent%'}',
                  ),
                if (item.status == ManagedUploadStatus.startingBuild)
                  const Text('Arquivos sincronizados. Conferindo o GitHub Actions.'),
                if (item.currentFile?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.currentFile!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                if (item.isActive) ...[
                  const SizedBox(height: 10),
                  LinearProgressIndicator(value: progress),
                  if (item.analyzedFiles > 0) ...[
                    const SizedBox(height: 6),
                    Text(
                      item.syncSummaryLabel,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
                if (item.isActive) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Etapas recentes',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 5),
                        ...item.timelineLines.reversed
                            .take(6)
                            .toList()
                            .reversed
                            .map(
                              (line) => Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Text(
                                  '• $line',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                if (item.isActive)
                  Text(
                    'Você pode minimizar ou sair para outro aplicativo. Uma notificação mantém o envio em primeiro plano. Se o Android encerrar o processo, o GitHub Manager retoma automaticamente do checkpoint ao abrir novamente.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                if (item.isActive && item.hasCheckpoint) ...[
                  const SizedBox(height: 6),
                  Text(
                    item.checkpointLabel,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
                if (item.errorMessage?.isNotEmpty == true) ...[
                  const SizedBox(height: 10),
                  _FailureDiagnostic(item: item),
                ],
                if (item.status == ManagedUploadStatus.noChanges)
                  const Text(
                    'O ZIP é idêntico ao repositório. Você pode iniciar a build do commit atual mesmo assim.',
                  ),
                ],
              ),
            ),
          ),
          actions: _actions(context, manager, item),
        );
      },
    );
  }

  List<Widget> _actions(
    BuildContext context,
    UploadManagerService manager,
    ManagedUpload item,
  ) {
    final router = GoRouter.of(context);
    if (item.isActive) {
      return [
        TextButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.minimize_rounded),
          label: const Text('Minimizar'),
        ),
        FilledButton.tonalIcon(
          onPressed: () {
            Navigator.pop(context);
            router.push('/uploads');
          },
          icon: const Icon(Icons.cloud_upload_outlined),
          label: const Text('Centro de envios'),
        ),
      ];
    }

    if (item.status == ManagedUploadStatus.noChanges) {
      return [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fechar'),
        ),
        FilledButton.icon(
          onPressed: () => manager.runBuildAnyway(item.id),
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Executar build'),
        ),
      ];
    }

    if (item.status == ManagedUploadStatus.buildPending) {
      return [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fechar'),
        ),
        OutlinedButton.icon(
          onPressed: () {
            Navigator.pop(context);
            router.push(
              '/repositories/${item.repositoryFullName}/builds?branch=${Uri.encodeQueryComponent(item.branch)}',
            );
          },
          icon: const Icon(Icons.play_circle_outline_rounded),
          label: const Text('Abrir Builds'),
        ),
        FilledButton.icon(
          onPressed: () => manager.retry(item.id),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Verificar build'),
        ),
      ];
    }

    if (item.status == ManagedUploadStatus.failed ||
        item.status == ManagedUploadStatus.interrupted) {
      return [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fechar'),
        ),
        if (item.canRetry && item.hasAlternativeRecoveryMethod)
          OutlinedButton.icon(
            onPressed: () => manager.retrySameMethod(item.id),
            icon: const Icon(Icons.replay_rounded),
            label: const Text('Repetir método atual'),
          ),
        if (item.canRetry && item.hasAlternativeRecoveryMethod)
          FilledButton.icon(
            onPressed: () => manager.retryAlternative(item.id),
            icon: const Icon(Icons.alt_route_rounded),
            label: const Text('Tentar método alternativo'),
          )
        else if (item.canRetry && item.shouldRetrySameMethod)
          FilledButton.icon(
            onPressed: () => manager.retrySameMethod(item.id),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Repetir método atual'),
          )
        else if (item.canRetry)
          FilledButton.icon(
            onPressed: () => manager.retry(item.id),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Tentar novamente'),
          ),
      ];
    }

    return [
      TextButton.icon(
        onPressed: () {
          Navigator.pop(context);
          router.push('/uploads');
        },
        icon: const Icon(Icons.cloud_upload_outlined),
        label: const Text('Centro de envios'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Fechar'),
      ),
    ];
  }

  static String _title(ManagedUpload item) => switch (item.status) {
        ManagedUploadStatus.completed => 'Envio concluído',
        ManagedUploadStatus.noChanges => 'Projeto já está atualizado',
        ManagedUploadStatus.buildPending => 'Projeto enviado',
        ManagedUploadStatus.failed => 'Envio com falha',
        ManagedUploadStatus.interrupted => 'Envio interrompido',
        _ => 'Enviando build',
      };
}


class _FailureDiagnostic extends StatelessWidget {
  const _FailureDiagnostic({required this.item});

  final ManagedUpload item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pending = item.isBuildPending;
    final accent = pending ? scheme.tertiary : scheme.error;
    final container =
        pending ? scheme.tertiaryContainer : scheme.errorContainer;
    final foreground =
        pending ? scheme.onTertiaryContainer : scheme.onErrorContainer;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: container,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                pending
                    ? Icons.warning_amber_rounded
                    : Icons.error_outline_rounded,
                color: accent,
                size: 23,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pending
                          ? 'Build não iniciada'
                          : 'Falha em “${item.failureOperationLabel}”',
                      style: TextStyle(
                        color: foreground,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (pending && item.commitSha?.isNotEmpty == true) ...[
                      const SizedBox(height: 2),
                      Text(
                        'O projeto já foi publicado no commit ${_shortSha(item.commitSha!)}. Não é necessário reenviar o ZIP.',
                        style: TextStyle(color: foreground),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            item.errorMessage!,
            style: TextStyle(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          _DiagnosticBlock(
            title: 'Como corrigir',
            text: item.failureSuggestedAction,
            color: foreground,
          ),
          if (item.canShowBuildTriggerFix) ...[
            const SizedBox(height: 6),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 4),
              dense: true,
              visualDensity: VisualDensity.compact,
              iconColor: foreground,
              collapsedIconColor: foreground,
              title: Text(
                'Exemplo de gatilho para o workflow',
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w800,
                ),
              ),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: scheme.surface.withValues(alpha: .45),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: SelectableText(
                    item.buildTriggerFixSnippet,
                    style: TextStyle(
                      color: foreground,
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: item.buildTriggerFixSnippet),
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Exemplo copiado')),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy_rounded, size: 17),
                    label: const Text('Copiar exemplo'),
                  ),
                ),
              ],
            ),
          ],
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            dense: true,
            visualDensity: VisualDensity.compact,
            iconColor: foreground,
            collapsedIconColor: foreground,
            title: Text(
              'Ver diagnóstico completo',
              style: TextStyle(color: foreground, fontWeight: FontWeight.w800),
            ),
            children: [
              _DiagnosticBlock(
                title: 'O que aconteceu',
                text: item.failureMeaning,
                color: foreground,
              ),
              const SizedBox(height: 8),
              _DiagnosticBlock(
                title: 'Até onde chegou',
                text: item.failureProgressExplanation,
                color: foreground,
              ),
              if (item.failureRepositoryImpact != null) ...[
                const SizedBox(height: 8),
                _DiagnosticBlock(
                  title: 'Impacto no repositório',
                  text: item.failureRepositoryImpact!,
                  color: foreground,
                ),
              ],
              const SizedBox(height: 8),
              _DiagnosticBlock(
                title: 'Resposta do GitHub',
                text: item.githubFailureResponse,
                color: foreground,
              ),
              if (item.recoveryEvents.isNotEmpty) ...[
                const SizedBox(height: 8),
                _DiagnosticBlock(
                  title: 'Histórico de recuperação',
                  text: item.recoveryEvents
                    .map((event) => '• $event')
                    .join('\n'),
                  color: foreground,
                ),
              ],
              if (item.timelineLines.isNotEmpty) ...[
                const SizedBox(height: 8),
                _DiagnosticBlock(
                  title: 'Etapas recentes',
                  text: item.timelineLines.reversed
                    .take(6)
                    .toList()
                    .reversed
                    .map((line) => '• $line')
                    .join('\n'),
                  color: foreground,
                ),
              ],
              if (item.errorCode?.isNotEmpty == true ||
                  item.errorEndpoint?.isNotEmpty == true ||
                  item.failedFilePath?.isNotEmpty == true) ...[
                const SizedBox(height: 8),
                if (item.errorCode?.isNotEmpty == true)
                  _TechnicalLine(
                    label: 'Código',
                    value: item.errorCode!,
                    color: foreground,
                  ),
                if (item.errorHttpStatus != null)
                  _TechnicalLine(
                    label: 'HTTP',
                    value: '${item.errorHttpStatus}',
                    color: foreground,
                  ),
                if (item.errorEndpoint?.isNotEmpty == true)
                  _TechnicalLine(
                    label: 'Endpoint',
                    value: item.errorEndpoint!,
                    color: foreground,
                  ),
                if (item.failedFilePath?.isNotEmpty == true)
                  _TechnicalLine(
                    label: 'Arquivo',
                    value: item.failedFilePath!,
                    color: foreground,
                  ),
              ],
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: item.failureDiagnosticText),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Diagnóstico copiado')),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy_all_rounded, size: 18),
                  label: const Text('Copiar diagnóstico'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _shortSha(String sha) => sha.length > 7 ? sha.substring(0, 7) : sha;

class _DiagnosticBlock extends StatelessWidget {
  const _DiagnosticBlock({
    required this.title,
    required this.text,
    required this.color,
  });

  final String title;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(text, style: TextStyle(color: color)),
        ],
      );
}

class _TechnicalLine extends StatelessWidget {
  const _TechnicalLine({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 72,
              child: Text(
                label,
                style: TextStyle(color: color, fontWeight: FontWeight.w800),
              ),
            ),
            Expanded(
              child: SelectableText(value, style: TextStyle(color: color)),
            ),
          ],
        ),
      );
}
