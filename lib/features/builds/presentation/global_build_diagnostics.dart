import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:github_manager/features/builds/domain/global_build_entry.dart';
import 'package:github_manager/features/repositories/domain/repository_git_models.dart';
import 'package:github_manager/features/repositories/presentation/repository_providers.dart';

/// Diagnóstico sob demanda: não baixa jobs/annotations/logs no polling global.
class GlobalBuildDiagnosisDialog extends ConsumerStatefulWidget {
  const GlobalBuildDiagnosisDialog({
    required this.entry,
    required this.onOpenDetails,
    super.key,
  });

  final GlobalBuildEntry entry;
  final VoidCallback onOpenDetails;

  @override
  ConsumerState<GlobalBuildDiagnosisDialog> createState() =>
      _GlobalBuildDiagnosisDialogState();
}

class _GlobalBuildDiagnosisDialogState
    extends ConsumerState<GlobalBuildDiagnosisDialog> {
  late final Future<_BuildDiagnosis> _future = _diagnose();

  Future<_BuildDiagnosis> _diagnose() async {
    final service = ref.read(repositoryGitServiceProvider);
    final jobs = await service.listWorkflowRunJobs(
      repositoryFullName: widget.entry.repository.fullName,
      runId: widget.entry.run.id,
    );
    final failed = jobs.where((job) => job.failed).toList(growable: false);
    final diagnoses = <RepositoryWorkflowFailure>[];
    for (final job in failed.take(2)) {
      try {
        final diagnosis = await service.loadWorkflowFailure(
          repositoryFullName: widget.entry.repository.fullName,
          runId: widget.entry.run.id,
          job: job,
        );
        if (diagnosis != null) diagnoses.add(diagnosis);
      } catch (_) {
        // Mostra ao menos os jobs/etapas já obtidos da API.
      }
    }
    return _BuildDiagnosis(jobs: jobs, diagnoses: diagnoses);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Diagnóstico • #${widget.entry.run.runNumber}'),
      content: SizedBox(
        width: 440,
        child: FutureBuilder<_BuildDiagnosis>(
          future: _future,
          builder: (context, state) {
            if (state.connectionState != ConnectionState.done) {
              return const Column(
                mainAxisSize: MainAxisSize.min,
                children: [CircularProgressIndicator(), SizedBox(height: 12),
                  Text('Consultando jobs, etapas e erros no GitHub…')],
              );
            }
            if (state.hasError) {
              return const Text(
                'Não foi possível consultar o diagnóstico agora. '
                'Abra os detalhes da execução para tentar novamente.',
              );
            }
            final data = state.data!;
            final steps = data.jobs.expand((job) => job.steps).toList();
            final completed = steps.where((step) => step.conclusion != null).length;
            final successful = steps.where((step) => step.conclusion == 'success').length;
            final failed = steps.where((step) => step.failed).toList();
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${data.jobs.length} jobs • $completed/${steps.length} etapas com resultado • $successful sucesso${failed.isEmpty ? '' : ' • ${failed.length} falha(s)'}'),
                  if (steps.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('O GitHub ainda não forneceu as etapas.'),
                    ),
                  for (final item in data.diagnoses) ...[
                    const SizedBox(height: 12),
                    Text('${item.jobName} / ${item.stepName}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    SelectableText(item.message),
                    if (item.logContext.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      ExpansionTile(
                        title: const Text('Trecho do log'),
                        children: [SelectableText(item.logContext.take(8).join('\n'))],
                      ),
                    ],
                  ],
                  if (data.diagnoses.isEmpty && failed.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Etapas com falha: ${failed.map((step) => step.name).join(', ')}'),
                  ],
                  if (data.diagnoses.isEmpty && failed.isEmpty) ...[
                    const SizedBox(height: 8),
                    const Text('Nenhuma causa detalhada foi encontrada nos jobs consultados.'),
                  ],
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fechar'),
        ),
        FilledButton(
          onPressed: widget.onOpenDetails,
          child: const Text('Ver detalhes'),
        ),
      ],
    );
  }
}

class _BuildDiagnosis {
  const _BuildDiagnosis({required this.jobs, required this.diagnoses});
  final List<RepositoryWorkflowJob> jobs;
  final List<RepositoryWorkflowFailure> diagnoses;
}
