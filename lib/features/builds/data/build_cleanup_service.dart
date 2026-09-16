import 'package:github_manager/core/errors/app_exception.dart';
import 'package:github_manager/core/network/github_api_client.dart';
import 'package:github_manager/features/builds/data/artifact_service.dart';
import 'package:github_manager/features/builds/domain/action_artifact.dart';
import 'package:github_manager/features/builds/domain/release_asset.dart';
import 'package:github_manager/features/repositories/domain/repository_git_models.dart';

class BuildCleanupResult {
  const BuildCleanupResult({
    required this.runId,
    required this.artifactsRemoved,
    required this.releaseApksRemoved,
    required this.warnings,
  });

  final int runId;
  final int artifactsRemoved;
  final int releaseApksRemoved;
  final List<String> warnings;

  int get relatedFilesRemoved => artifactsRemoved + releaseApksRemoved;
  bool get hasWarnings => warnings.isNotEmpty;
}

class BuildBulkCleanupResult {
  const BuildBulkCleanupResult({
    required this.deletedRunIds,
    required this.failedRunIds,
    required this.failureMessages,
    required this.artifactsRemoved,
    required this.releaseApksRemoved,
    required this.warnings,
  });

  final List<int> deletedRunIds;
  final List<int> failedRunIds;
  final Map<int, String> failureMessages;
  final int artifactsRemoved;
  final int releaseApksRemoved;
  final List<String> warnings;

  int get deletedCount => deletedRunIds.length;
  int get failedCount => failedRunIds.length;
  int get relatedFilesRemoved => artifactsRemoved + releaseApksRemoved;
  bool get hasFailures => failedRunIds.isNotEmpty;
  bool get hasWarnings => warnings.isNotEmpty;
}

/// Coordena a exclusão de uma build e das saídas que pertencem a ela.
///
/// O GitHub documenta que excluir um workflow run remove os artifacts ligados
/// à execução. Mesmo assim, o serviço verifica a lista depois da exclusão e
/// remove explicitamente qualquer artifact que ainda apareça. Releases são
/// independentes do workflow run, então APKs de Release só são removidos quando
/// conseguimos provar que a tag/target_commitish aponta para o mesmo commit.
class BuildCleanupService {
  BuildCleanupService(this._client, this._artifacts);

  final GitHubApiClient _client;
  final ArtifactService _artifacts;

  Future<BuildCleanupResult> deleteBuild({
    required String repositoryFullName,
    required RepositoryWorkflowRun run,
  }) async {
    final warnings = <String>[];
    List<ActionArtifact> linkedArtifacts = const <ActionArtifact>[];
    List<ReleaseAsset> linkedReleaseApks = const <ReleaseAsset>[];

    // Descobrimos os vínculos antes de apagar a execução, pois o endpoint
    // específico do run deixa de existir após a exclusão.
    try {
      linkedArtifacts = await _artifacts.listArtifactsForRun(
        repositoryFullName: repositoryFullName,
        runId: run.id,
      );
    } catch (error) {
      warnings.add(
        'Não foi possível conferir previamente os artifacts da build: ${_message(error)}',
      );
    }

    try {
      linkedReleaseApks = await _artifacts.findReleaseApksForBuild(
        repositoryFullName: repositoryFullName,
        run: run,
      );
    } catch (error) {
      warnings.add(
        'Não foi possível conferir previamente APKs publicados em Release: ${_message(error)}',
      );
    }

    // Primeiro removemos a execução. Se isso falhar, nenhuma Release é tocada.
    await _client.delete<void>(
      '/repos/$repositoryFullName/actions/runs/${run.id}',
    );

    final knownArtifactIds = linkedArtifacts.map((item) => item.id).toSet();
    final unresolvedArtifactIds = <int>{};
    var extraArtifactsRemoved = 0;
    var removedReleaseApks = 0;

    // O GitHub deve remover os artifacts junto com o run. Fazemos uma
    // verificação adicional na coleção do repositório para cobrir atraso de
    // consistência ou comportamento inesperado da API.
    try {
      final remaining = (await _artifacts.listArtifacts(repositoryFullName))
          .where((artifact) => artifact.workflowRunId == run.id)
          .toList(growable: false);
      for (final artifact in remaining) {
        try {
          await _artifacts.deleteArtifact(
            repositoryFullName: repositoryFullName,
            artifactId: artifact.id,
          );
          if (!knownArtifactIds.contains(artifact.id)) {
            extraArtifactsRemoved++;
          }
        } catch (error) {
          if (!_isNotFound(error)) {
            unresolvedArtifactIds.add(artifact.id);
            warnings.add(
              'O artifact ${artifact.name} ainda aparece no GitHub e não pôde ser removido: ${_message(error)}',
            );
          }
        }
      }
    } catch (error) {
      warnings.add(
        'A build foi excluída, mas não foi possível confirmar a limpeza dos artifacts: ${_message(error)}',
      );
    }

    final removedArtifacts = knownArtifactIds
            .where((id) => !unresolvedArtifactIds.contains(id))
            .length +
        extraArtifactsRemoved;

    // Release assets não são apagados pelo GitHub quando o workflow run some.
    // Removemos apenas APKs cuja Release foi ligada com segurança ao mesmo SHA.
    for (final asset in linkedReleaseApks) {
      try {
        await _artifacts.deleteReleaseAsset(
          repositoryFullName: repositoryFullName,
          assetId: asset.id,
        );
        removedReleaseApks++;
      } catch (error) {
        if (!_isNotFound(error)) {
          warnings.add(
            'A build foi excluída, mas o APK ${asset.name} da Release ${asset.tagName} não pôde ser removido: ${_message(error)}',
          );
        }
      }
    }

    return BuildCleanupResult(
      runId: run.id,
      artifactsRemoved: removedArtifacts,
      releaseApksRemoved: removedReleaseApks,
      warnings: List<String>.unmodifiable(warnings),
    );
  }

  Future<BuildBulkCleanupResult> deleteBuilds({
    required String repositoryFullName,
    required Iterable<RepositoryWorkflowRun> runs,
  }) async {
    final deletedIds = <int>[];
    final failedIds = <int>[];
    final failures = <int, String>{};
    final warnings = <String>[];
    var artifactsRemoved = 0;
    var releaseApksRemoved = 0;

    final uniqueRuns = <int, RepositoryWorkflowRun>{
      for (final run in runs) run.id: run,
    }.values;

    for (final run in uniqueRuns) {
      try {
        final result = await deleteBuild(
          repositoryFullName: repositoryFullName,
          run: run,
        );
        deletedIds.add(run.id);
        artifactsRemoved += result.artifactsRemoved;
        releaseApksRemoved += result.releaseApksRemoved;
        warnings.addAll(result.warnings);
      } catch (error) {
        failedIds.add(run.id);
        failures[run.id] = _message(error);
      }
    }

    return BuildBulkCleanupResult(
      deletedRunIds: List<int>.unmodifiable(deletedIds),
      failedRunIds: List<int>.unmodifiable(failedIds),
      failureMessages: Map<int, String>.unmodifiable(failures),
      artifactsRemoved: artifactsRemoved,
      releaseApksRemoved: releaseApksRemoved,
      warnings: List<String>.unmodifiable(warnings),
    );
  }

  static bool _isNotFound(Object error) =>
      error is AppException && error.httpStatus == 404;

  static String _message(Object error) =>
      error is AppException ? error.message : 'Não foi possível concluir a limpeza.';
}
