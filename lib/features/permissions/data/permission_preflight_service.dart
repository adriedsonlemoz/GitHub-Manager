import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:github_manager/core/errors/app_exception.dart';
import 'package:github_manager/core/security/secure_storage_service.dart';
import 'package:github_manager/features/permissions/data/token_permission_diagnostics_service.dart';
import 'package:github_manager/features/permissions/domain/repository_permission_preflight.dart';
import 'package:github_manager/features/permissions/domain/repository_permission_report.dart';

class PermissionPreflightService {
  PermissionPreflightService(
    this._diagnostics,
    SecureStorageService secureStorage, {
    Duration cacheTtl = const Duration(minutes: 3),
    DateTime Function()? clock,
  })  : _readToken = secureStorage.readGitHubToken,
        _cacheTtl = cacheTtl,
        _clock = clock ?? DateTime.now;

  PermissionPreflightService.withTokenReader(
    this._diagnostics,
    Future<String?> Function() tokenReader, {
    Duration cacheTtl = const Duration(minutes: 3),
    DateTime Function()? clock,
  })  : _readToken = tokenReader,
        _cacheTtl = cacheTtl,
        _clock = clock ?? DateTime.now;

  final TokenPermissionDiagnosticsService _diagnostics;
  final Future<String?> Function() _readToken;
  final Duration _cacheTtl;
  final DateTime Function() _clock;
  final Map<String, _CachedPermissionReport> _cache = {};

  Future<RepositoryPermissionReport> getReport(
    String repositoryFullName, {
    bool forceRefresh = false,
  }) async {
    final token = (await _readToken())?.trim();
    if (token == null || token.isEmpty) {
      throw const AuthenticationRequiredException();
    }

    final key = _cacheKey(repositoryFullName, token);
    final now = _clock();
    final cached = _cache[key];
    if (!forceRefresh &&
        cached != null &&
        now.difference(cached.storedAt) <= _cacheTtl) {
      return cached.report;
    }

    final report = await _diagnostics.diagnose(repositoryFullName);
    _removeRepositoryEntries(repositoryFullName, exceptKey: key);
    _cache[key] = _CachedPermissionReport(report: report, storedAt: now);
    return report;
  }

  Future<RepositoryPermissionPreflightDecision> check(
    String repositoryFullName,
    RepositoryCriticalAction action, {
    bool forceRefresh = false,
  }) async {
    try {
      final report = await getReport(
        repositoryFullName,
        forceRefresh: forceRefresh,
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

  void invalidateRepository(String repositoryFullName) {
    _removeRepositoryEntries(repositoryFullName);
  }

  void clear() => _cache.clear();

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
      case RepositoryCriticalAction.sendBuild:
        add(RepositoryPermissionArea.contents);
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

  String _cacheKey(String repositoryFullName, String token) {
    final fingerprint = sha256.convert(utf8.encode(token)).toString();
    return '${repositoryFullName.toLowerCase()}|$fingerprint';
  }

  void _removeRepositoryEntries(
    String repositoryFullName, {
    String? exceptKey,
  }) {
    final prefix = '${repositoryFullName.toLowerCase()}|';
    _cache.removeWhere(
      (key, _) => key.startsWith(prefix) && key != exceptKey,
    );
  }
}

class _CachedPermissionReport {
  const _CachedPermissionReport({
    required this.report,
    required this.storedAt,
  });

  final RepositoryPermissionReport report;
  final DateTime storedAt;
}
