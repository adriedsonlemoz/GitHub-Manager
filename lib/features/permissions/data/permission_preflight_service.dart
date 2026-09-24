import 'package:github_manager/core/errors/app_exception.dart';
import 'package:github_manager/core/security/secure_storage_service.dart';
import 'package:github_manager/features/permissions/data/token_permission_diagnostics_service.dart';
import 'package:github_manager/features/permissions/domain/repository_permission_preflight.dart';
import 'package:github_manager/features/permissions/domain/repository_permission_report.dart';

class PermissionPreflightService {
  PermissionPreflightService(
    this._diagnostics,
    SecureStorageService secureStorage,
  ) : _readToken = secureStorage.readGitHubToken;

  PermissionPreflightService.withTokenReader(
    this._diagnostics,
    Future<String?> Function() tokenReader,
  ) : _readToken = tokenReader;

  final TokenPermissionDiagnosticsService _diagnostics;
  final Future<String?> Function() _readToken;

  Future<RepositoryPermissionReport> getReport(
    String repositoryFullName, {
    bool forceRefresh = false,
    String? branch,
  }) async {
    final token = (await _readToken())?.trim();
    if (token == null || token.isEmpty) {
      throw const AuthenticationRequiredException();
    }
    return _diagnostics.diagnose(repositoryFullName, branch: branch);
  }

  Future<RepositoryPermissionPreflightDecision> check(
    String repositoryFullName,
    RepositoryCriticalAction action, {
    bool forceRefresh = false,
    String? branch,
  }) async {
    try {
      final report = await getReport(
        repositoryFullName,
        forceRefresh: forceRefresh,
        branch: branch,
      );
      final relevant = _resultsFor(report, action);
      final denied = relevant
          .where((result) => result.verdict == PermissionVerdict.denied)
          .toList(growable: false);
      final unknown = relevant
          .where((result) => result.verdict == PermissionVerdict.unknown)
          .toList(growable: false);

      return RepositoryPermissionPreflightDecision(
        action: action,
        repositoryFullName: repositoryFullName,
        blocked: denied.isNotEmpty,
        denied: denied,
        unknown: unknown,
        checkedAt: report.checkedAt,
        message: denied.isEmpty
            ? null
            : 'O diagnóstico já confirmou que o token atual não possui '
                'todas as permissões necessárias para esta ação.',
      );
    } on AuthenticationRequiredException catch (error) {
      return RepositoryPermissionPreflightDecision(
        action: action,
        repositoryFullName: repositoryFullName,
        blocked: true,
        denied: const [],
        unknown: const [],
        message: error.message,
      );
    } on GitHubPermissionException catch (error) {
      return RepositoryPermissionPreflightDecision(
        action: action,
        repositoryFullName: repositoryFullName,
        blocked: true,
        denied: const [],
        unknown: const [],
        message: error.apiMessage ?? error.message,
      );
    } on GitHubNotFoundException catch (error) {
      return RepositoryPermissionPreflightDecision(
        action: action,
        repositoryFullName: repositoryFullName,
        blocked: true,
        denied: const [],
        unknown: const [],
        message: error.apiMessage ?? error.message,
      );
    } on GitHubRateLimitException {
      return RepositoryPermissionPreflightDecision(
        action: action,
        repositoryFullName: repositoryFullName,
        blocked: false,
        denied: const [],
        unknown: const [],
        diagnosticUnavailable: true,
        message: 'O diagnóstico está temporariamente indisponível por limite da API. '
            'A operação poderá continuar e será validada pelo próprio GitHub.',
      );
    } on NetworkRequiredException {
      return RepositoryPermissionPreflightDecision(
        action: action,
        repositoryFullName: repositoryFullName,
        blocked: false,
        denied: const [],
        unknown: const [],
        diagnosticUnavailable: true,
        message: 'Não foi possível atualizar o diagnóstico agora. A operação poderá '
            'continuar e será validada pelo próprio GitHub.',
      );
    } catch (_) {
      return RepositoryPermissionPreflightDecision(
        action: action,
        repositoryFullName: repositoryFullName,
        blocked: false,
        denied: const [],
        unknown: const [],
        diagnosticUnavailable: true,
        message: 'O diagnóstico não respondeu de forma conclusiva. A operação poderá '
            'continuar e será validada pelo próprio GitHub.',
      );
    }
  }

  void invalidateRepository(String repositoryFullName) {}

  void clear() {}

  List<PermissionAccessResult> _resultsFor(
    RepositoryPermissionReport report,
    RepositoryCriticalAction action,
  ) {
    PermissionAccessResult? writeFor(RepositoryPermissionArea area) {
      for (final capability in report.capabilities) {
        if (capability.area == area) return capability.write;
      }
      return null;
    }

    final results = <PermissionAccessResult>[];
    void add(RepositoryPermissionArea area) {
      final value = writeFor(area);
      if (value != null) results.add(value);
    }

    switch (action) {
      case RepositoryCriticalAction.syncProject:
        add(RepositoryPermissionArea.contents);
        break;
      case RepositoryCriticalAction.syncProjectWorkflowFiles:
        add(RepositoryPermissionArea.contents);
        if (report.tokenKind == GitHubTokenKind.classic) {
          final hasWorkflow = report.classicScopes.contains('workflow');
          results.add(
            PermissionAccessResult(
              verdict: hasWorkflow
                  ? PermissionVerdict.inferred
                  : PermissionVerdict.denied,
              label: hasWorkflow ? 'Disponível' : 'Escopo ausente',
              detail: hasWorkflow
                  ? 'O PAT clássico possui workflow para alterar arquivos em .github/workflows.'
                  : 'Este ZIP altera arquivo(s) em .github/workflows. PAT clássico precisa do escopo workflow além de repo.',
              requiredPermission: 'workflow',
            ),
          );
        } else if (report.tokenKind == GitHubTokenKind.fineGrained) {
          results.add(
            const PermissionAccessResult(
              verdict: PermissionVerdict.unknown,
              label: 'Confirmar no token',
              detail: 'Este ZIP altera arquivo(s) em .github/workflows. Tokens fine-grained precisam de Workflows: write além de Contents: write quando o workflow for modificado.',
              requiredPermission: 'Workflows: write',
            ),
          );
        }
        break;
      case RepositoryCriticalAction.sendBuild:
        add(RepositoryPermissionArea.actions);
        break;
      case RepositoryCriticalAction.manageFiles:
        add(RepositoryPermissionArea.contents);
        break;
      case RepositoryCriticalAction.manageSecrets:
        add(RepositoryPermissionArea.secrets);
        break;
      case RepositoryCriticalAction.deleteRepository:
        add(RepositoryPermissionArea.deletion);
        break;
    }
    return results;
  }

}
