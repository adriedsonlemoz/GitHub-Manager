import 'package:github_manager/core/errors/app_exception.dart';
import 'package:github_manager/core/network/github_api_client.dart';
import 'package:github_manager/core/security/secure_storage_service.dart';
import 'package:github_manager/features/permissions/domain/repository_permission_report.dart';

class PermissionProbe {
  const PermissionProbe({
    required this.statusCode,
    required this.data,
    this.acceptedPermissions,
    this.oauthScopes,
    this.rateLimitRemaining,
  });

  final int? statusCode;
  final Object? data;
  final String? acceptedPermissions;
  final String? oauthScopes;
  final String? rateLimitRemaining;

  bool get isSuccess =>
      statusCode != null && statusCode! >= 200 && statusCode! < 300;
}

abstract interface class TokenPermissionDiagnosticsGateway {
  Future<String?> readToken();

  Future<PermissionProbe> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  });
}

class GitHubTokenPermissionDiagnosticsGateway
    implements TokenPermissionDiagnosticsGateway {
  GitHubTokenPermissionDiagnosticsGateway(this._client, this._secureStorage);

  final GitHubApiClient _client;
  final SecureStorageService _secureStorage;

  @override
  Future<String?> readToken() => _secureStorage.readGitHubToken();

  @override
  Future<PermissionProbe> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final response = await _client.probeGet(
      path,
      queryParameters: queryParameters,
    );
    return PermissionProbe(
      statusCode: response.statusCode,
      data: response.data,
      acceptedPermissions: response.header('x-accepted-github-permissions'),
      oauthScopes: response.header('x-oauth-scopes'),
      rateLimitRemaining: response.header('x-ratelimit-remaining'),
    );
  }
}

class TokenPermissionDiagnosticsService {
  TokenPermissionDiagnosticsService(
    GitHubApiClient client,
    SecureStorageService secureStorage,
  ) : this.withGateway(
          GitHubTokenPermissionDiagnosticsGateway(client, secureStorage),
        );

  TokenPermissionDiagnosticsService.withGateway(this._gateway);

  final TokenPermissionDiagnosticsGateway _gateway;

  Future<RepositoryPermissionReport> diagnose(
    String repositoryFullName,
  ) async {
    final token = (await _gateway.readToken())?.trim();
    if (token == null || token.isEmpty) {
      throw const AuthenticationRequiredException();
    }

    final tokenKind = _tokenKind(token);
    final userProbe = await _gateway.get('/user');
    _throwIfRateLimited(userProbe, '/user');
    if (userProbe.statusCode == 401) {
      throw const AuthenticationRequiredException(httpStatus: 401, endpoint: '/user');
    }

    final repoPath = '/repos/$repositoryFullName';
    final repositoryProbe = await _gateway.get(repoPath);
    _throwIfRateLimited(repositoryProbe, repoPath);
    if (!repositoryProbe.isSuccess) {
      if (repositoryProbe.statusCode == 401) {
        throw AuthenticationRequiredException(
          httpStatus: 401,
          endpoint: repoPath,
        );
      }
      if (repositoryProbe.statusCode == 403) {
        throw GitHubPermissionException(
          httpStatus: 403,
          endpoint: repoPath,
          apiMessage: 'O token não consegue acessar os metadados deste repositório.',
        );
      }
      if (repositoryProbe.statusCode == 404) {
        throw GitHubNotFoundException(
          httpStatus: 404,
          endpoint: repoPath,
          apiMessage: 'Repositório não encontrado ou fora do acesso do token.',
        );
      }
      throw UnexpectedAppException(
        'PERMISSION_DIAGNOSTIC_REPOSITORY_${repositoryProbe.statusCode ?? 'UNKNOWN'}',
      );
    }

    final repository = _map(repositoryProbe.data);
    final permissions = _map(repository['permissions']);
    final canAdmin = permissions['admin'] == true;
    final canMaintain = permissions['maintain'] == true;
    final canPush = permissions['push'] == true || canMaintain || canAdmin;
    final canPull = permissions['pull'] == true || canPush;
    final role = _repositoryRole(
      canAdmin: canAdmin,
      canMaintain: canMaintain,
      canPush: canPush,
      canPull: canPull,
    );
    final defaultBranch = repository['default_branch']?.toString() ?? 'main';
    final repositorySize = _int(repository['size']);
    final classicScopes = _classicScopes(
      userProbe.oauthScopes ?? repositoryProbe.oauthScopes,
    );

    final results = await Future.wait<PermissionProbe>([
      _gateway.get(
        '$repoPath/contents',
        queryParameters: {'ref': defaultBranch},
      ),
      _gateway.get('$repoPath/actions/workflows', queryParameters: {'per_page': 1}),
      _gateway.get('$repoPath/actions/secrets', queryParameters: {'per_page': 1}),
      _gateway.get('$repoPath/actions/permissions'),
      _gateway.get(
        '$repoPath/branches/${Uri.encodeComponent(defaultBranch)}',
      ),
    ]);

    final contentsProbe = results[0];
    final actionsProbe = results[1];
    final secretsProbe = results[2];
    final administrationProbe = results[3];
    final branchProbe = results[4];
    final branchProtected =
        branchProbe.isSuccess && _map(branchProbe.data)['protected'] == true;
    _throwIfRateLimited(contentsProbe, '$repoPath/contents');
    _throwIfRateLimited(actionsProbe, '$repoPath/actions/workflows');
    _throwIfRateLimited(secretsProbe, '$repoPath/actions/secrets');
    _throwIfRateLimited(administrationProbe, '$repoPath/actions/permissions');
    _throwIfRateLimited(
      branchProbe,
      '$repoPath/branches/${Uri.encodeComponent(defaultBranch)}',
    );

    final capabilities = <RepositoryPermissionCapability>[
      RepositoryPermissionCapability(
        area: RepositoryPermissionArea.contents,
        title: 'Contents',
        summary: 'Ler, criar, editar e excluir arquivos do repositório.',
        read: _readResult(
          probe: contentsProbe,
          required: 'Contents: read',
          endpoint: '$repoPath/contents',
          emptyRepository: repositorySize == 0,
        ),
        write: _contentsWriteResult(
          tokenKind: tokenKind,
          classicScopes: classicScopes,
          roleAllows: canPush,
          readProbe: contentsProbe,
          emptyRepository: repositorySize == 0,
          branchProtected: branchProtected,
        ),
      ),
      RepositoryPermissionCapability(
        area: RepositoryPermissionArea.actions,
        title: 'Actions',
        summary: 'Consultar e controlar workflows e builds.',
        read: _readResult(
          probe: actionsProbe,
          required: 'Actions: read',
          endpoint: '$repoPath/actions/workflows',
        ),
        write: _writeResult(
          tokenKind: tokenKind,
          classicScopes: classicScopes,
          roleAllows: canPush,
          roleFailure: 'Sua conta não possui acesso de escrita para controlar builds.',
          classicRequired: 'repo',
          fineGrainedRequired: 'Actions: write',
          readProbe: actionsProbe,
          detail:
              'Necessário para workflow_dispatch, cancelar, reexecutar e controlar builds.',
        ),
      ),
      RepositoryPermissionCapability(
        area: RepositoryPermissionArea.secrets,
        title: 'Secrets',
        summary: 'Listar, criar, substituir e excluir GitHub Actions Secrets.',
        read: _readResult(
          probe: secretsProbe,
          required: 'Secrets: read',
          endpoint: '$repoPath/actions/secrets',
        ),
        write: _writeResult(
          tokenKind: tokenKind,
          classicScopes: classicScopes,
          roleAllows: canPush,
          roleFailure: 'Sua conta não possui acesso suficiente para gerenciar Secrets.',
          classicRequired: 'repo',
          fineGrainedRequired: 'Secrets: write',
          readProbe: secretsProbe,
          detail: 'Necessário para criar, substituir e excluir Secrets do repositório.',
        ),
      ),
      RepositoryPermissionCapability(
        area: RepositoryPermissionArea.administration,
        title: 'Administração',
        summary: 'Alterar configurações administrativas do repositório.',
        read: _readResult(
          probe: administrationProbe,
          required: 'Administration: read',
          endpoint: '$repoPath/actions/permissions',
        ),
        write: _writeResult(
          tokenKind: tokenKind,
          classicScopes: classicScopes,
          roleAllows: canAdmin,
          roleFailure: 'Sua conta não possui papel de administrador neste repositório.',
          classicRequired: 'repo',
          fineGrainedRequired: 'Administration: write',
          readProbe: administrationProbe,
          detail: 'Necessário para alterar configurações administrativas do repositório.',
        ),
      ),
      RepositoryPermissionCapability(
        area: RepositoryPermissionArea.deletion,
        title: 'Exclusão permanente',
        summary: 'Excluir definitivamente o repositório.',
        write: _deleteResult(
          tokenKind: tokenKind,
          classicScopes: classicScopes,
          canAdmin: canAdmin,
        ),
      ),
    ];

    return RepositoryPermissionReport(
      repositoryFullName: repositoryFullName,
      tokenKind: tokenKind,
      repositoryRole: role,
      classicScopes: classicScopes,
      capabilities: capabilities,
      checkedAt: DateTime.now(),
      safeMode: true,
    );
  }

  PermissionAccessResult _readResult({
    required PermissionProbe probe,
    required String required,
    required String endpoint,
    bool emptyRepository = false,
  }) {
    if (probe.isSuccess || (emptyRepository && probe.statusCode == 404)) {
      return PermissionAccessResult(
        verdict: PermissionVerdict.allowed,
        label: 'Confirmada',
        detail: emptyRepository && probe.statusCode == 404
            ? 'Repositório vazio; acesso aos metadados foi confirmado sem alterar dados.'
            : 'A API respondeu com sucesso usando o token atual.',
        requiredPermission: required,
        httpStatus: probe.statusCode,
        endpoint: endpoint,
        acceptedPermissions: probe.acceptedPermissions,
      );
    }
    if (probe.statusCode == 401 || probe.statusCode == 403 || probe.statusCode == 404) {
      return PermissionAccessResult(
        verdict: PermissionVerdict.denied,
        label: 'Sem acesso',
        detail: 'O GitHub não permitiu esta consulta com o token atual.',
        requiredPermission: _acceptedOrFallback(probe, required),
        httpStatus: probe.statusCode,
        endpoint: endpoint,
        acceptedPermissions: probe.acceptedPermissions,
      );
    }
    return PermissionAccessResult(
      verdict: PermissionVerdict.unknown,
      label: 'Não confirmado',
      detail: 'A API não respondeu de forma conclusiva para esta verificação.',
      requiredPermission: required,
      httpStatus: probe.statusCode,
      endpoint: endpoint,
      acceptedPermissions: probe.acceptedPermissions,
    );
  }

  PermissionAccessResult _contentsWriteResult({
    required GitHubTokenKind tokenKind,
    required List<String> classicScopes,
    required bool roleAllows,
    required PermissionProbe readProbe,
    required bool emptyRepository,
    required bool branchProtected,
  }) {
    if (!roleAllows) {
      return const PermissionAccessResult(
        verdict: PermissionVerdict.denied,
        label: 'Bloqueada pelo papel',
        detail: 'Sua conta não possui permissão de escrita neste repositório.',
        requiredPermission: 'Contents: write',
      );
    }
    if (readProbe.statusCode == 401 ||
        readProbe.statusCode == 403 ||
        (readProbe.statusCode == 404 && !emptyRepository)) {
      return PermissionAccessResult(
        verdict: PermissionVerdict.denied,
        label: 'Permissão insuficiente',
        detail: 'A leitura de Contents falhou, então a sincronização por ZIP não está disponível.',
        requiredPermission: tokenKind == GitHubTokenKind.classic
            ? 'repo + workflow'
            : 'Contents: write + Workflows: write',
      );
    }

    if (tokenKind == GitHubTokenKind.classic) {
      final hasRepo = classicScopes.contains('repo');
      final hasWorkflow = classicScopes.contains('workflow');
      final allowed = hasRepo && hasWorkflow;
      if (allowed && branchProtected) {
        return const PermissionAccessResult(
          verdict: PermissionVerdict.unknown,
          label: 'Branch protegida',
          detail:
              'Token e papel permitem escrita, mas a branch está protegida. Rulesets ou regras de proteção podem impedir push direto.',
          requiredPermission: 'repo + workflow',
        );
      }
      return PermissionAccessResult(
        verdict: allowed ? PermissionVerdict.inferred : PermissionVerdict.denied,
        label: allowed
            ? emptyRepository
                ? 'Repositório vazio • escrita disponível'
                : 'Disponível para sincronização'
            : 'Escopo ausente',
        detail: allowed
            ? emptyRepository
                ? 'O repositório ainda não possui arquivos/branch materializada, mas o acesso ao repositório, o papel de escrita e os escopos `repo` + `workflow` estão confirmados.'
                : 'O PAT clássico possui `repo` e `workflow`, necessários para sincronizar o projeto inclusive em .github/workflows.'
            : 'A sincronização completa do GitHub Manager precisa de `repo` e também `workflow` para atualizar arquivos em .github/workflows.',
        requiredPermission: 'repo + workflow',
      );
    }

    return PermissionAccessResult(
      verdict: PermissionVerdict.unknown,
      label: branchProtected ? 'Branch protegida' : 'Verifique no token',
      detail: branchProtected
          ? 'A branch está protegida. Além de Contents: write e Workflows: write, as regras da branch/ruleset precisam permitir a atualização.'
          : emptyRepository
              ? 'O repositório está vazio. A leitura 404 é normal neste estado; confirme Contents: write e Workflows: write no PAT fine-grained para o primeiro envio.'
              : 'Para sincronizar todo o ZIP, inclusive .github/workflows, confirme as duas permissões no PAT fine-grained. O diagnóstico não altera arquivos só para testar escrita.',
      requiredPermission: 'Contents: write + Workflows: write',
    );
  }

  PermissionAccessResult _writeResult({
    required GitHubTokenKind tokenKind,
    required List<String> classicScopes,
    required bool roleAllows,
    required String roleFailure,
    required String classicRequired,
    required String fineGrainedRequired,
    required PermissionProbe readProbe,
    required String detail,
  }) {
    if (!roleAllows) {
      return PermissionAccessResult(
        verdict: PermissionVerdict.denied,
        label: 'Bloqueada pelo papel',
        detail: roleFailure,
        requiredPermission: tokenKind == GitHubTokenKind.classic
            ? classicRequired
            : fineGrainedRequired,
      );
    }
    if (readProbe.statusCode == 401 ||
        readProbe.statusCode == 403 ||
        readProbe.statusCode == 404) {
      return PermissionAccessResult(
        verdict: PermissionVerdict.denied,
        label: 'Permissão insuficiente',
        detail: 'A leitura desta área já falhou, então a escrita também não está disponível.',
        requiredPermission: tokenKind == GitHubTokenKind.classic
            ? classicRequired
            : fineGrainedRequired,
      );
    }

    if (tokenKind == GitHubTokenKind.classic) {
      final hasScope = _hasClassicScope(classicScopes, classicRequired);
      return PermissionAccessResult(
        verdict: hasScope ? PermissionVerdict.inferred : PermissionVerdict.denied,
        label: hasScope ? 'Disponível' : 'Escopo ausente',
        detail: hasScope
            ? '$detail O diagnóstico confirma pelo escopo do PAT clássico e pelo seu papel no repositório.'
            : 'O PAT clássico não informa o escopo obrigatório `$classicRequired`.',
        requiredPermission: classicRequired,
      );
    }

    return PermissionAccessResult(
      verdict: PermissionVerdict.unknown,
      label: 'Verifique no token',
      detail: '$detail O GitHub não oferece introspecção segura das permissões de escrita '
          'de PAT fine-grained; o diagnóstico não faz mutações só para testar.',
      requiredPermission: fineGrainedRequired,
    );
  }

  PermissionAccessResult _deleteResult({
    required GitHubTokenKind tokenKind,
    required List<String> classicScopes,
    required bool canAdmin,
  }) {
    if (!canAdmin) {
      return PermissionAccessResult(
        verdict: PermissionVerdict.denied,
        label: 'Bloqueada pelo papel',
        detail: 'Excluir um repositório exige acesso administrativo.',
        requiredPermission: tokenKind == GitHubTokenKind.classic
            ? 'delete_repo'
            : 'Administration: write',
      );
    }

    if (tokenKind == GitHubTokenKind.classic) {
      final allowed = classicScopes.contains('delete_repo');
      return PermissionAccessResult(
        verdict: allowed ? PermissionVerdict.inferred : PermissionVerdict.denied,
        label: allowed ? 'Disponível' : 'Escopo ausente',
        detail: allowed
            ? 'Seu papel é administrador e o PAT clássico possui `delete_repo`.'
            : 'O PAT clássico precisa do escopo `delete_repo` além do acesso administrativo.',
        requiredPermission: 'delete_repo',
      );
    }

    return const PermissionAccessResult(
      verdict: PermissionVerdict.unknown,
      label: 'Verifique no token',
      detail: 'A exclusão não é executada durante o diagnóstico. Para PAT fine-grained, '
          'o GitHub exige Administration: write e acesso administrativo ao repositório.',
      requiredPermission: 'Administration: write',
    );
  }

  static void _throwIfRateLimited(PermissionProbe probe, String endpoint) {
    if (probe.statusCode == 429 ||
        (probe.statusCode == 403 && probe.rateLimitRemaining == '0')) {
      throw GitHubRateLimitException(
        httpStatus: probe.statusCode,
        endpoint: endpoint,
      );
    }
  }

  static GitHubTokenKind _tokenKind(String token) {
    if (token.startsWith('github_pat_')) return GitHubTokenKind.fineGrained;
    if (token.startsWith('ghp_')) return GitHubTokenKind.classic;
    return GitHubTokenKind.unknown;
  }

  static List<String> _classicScopes(String? header) {
    if (header == null || header.trim().isEmpty) return const [];
    final scopes = header
        .split(',')
        .map((scope) => scope.trim())
        .where((scope) => scope.isNotEmpty)
        .toSet()
        .toList(growable: false)
      ..sort();
    return scopes;
  }

  static bool _hasClassicScope(List<String> scopes, String required) {
    if (required == 'repo') {
      return scopes.contains('repo');
    }
    return scopes.contains(required);
  }

  static String _acceptedOrFallback(PermissionProbe probe, String fallback) {
    final accepted = probe.acceptedPermissions?.trim();
    if (accepted == null || accepted.isEmpty) return fallback;
    return accepted;
  }

  static String _repositoryRole({
    required bool canAdmin,
    required bool canMaintain,
    required bool canPush,
    required bool canPull,
  }) {
    if (canAdmin) return 'Administrador';
    if (canMaintain) return 'Manutenção';
    if (canPush) return 'Escrita';
    if (canPull) return 'Leitura';
    return 'Sem papel confirmado';
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }

  static int _int(Object? value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
