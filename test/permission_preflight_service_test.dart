import 'package:flutter_test/flutter_test.dart';
import 'package:github_manager/features/permissions/data/permission_preflight_service.dart';
import 'package:github_manager/features/permissions/data/token_permission_diagnostics_service.dart';
import 'package:github_manager/features/permissions/domain/repository_permission_preflight.dart';

void main() {
  group('PermissionPreflightService', () {
    test('bloqueia Enviar build quando PAT clássico não tem repo', () async {
      final gateway = _CountingGateway(
        token: 'ghp_teste',
        oauthScopes: 'read:user',
        admin: true,
      );
      final service = _service(gateway);

      final decision = await service.check(
        'owner/repo',
        RepositoryCriticalAction.sendBuild,
      );

      expect(decision.blocked, isTrue);
      expect(decision.requiredPermissions, contains('repo'));
      expect(decision.requiredPermissions, isNot(contains('workflow')));
    });

    test('Enviar nova versão exige Contents, mas não Actions', () async {
      final gateway = _CountingGateway(
        token: 'ghp_teste',
        oauthScopes: 'repo',
        admin: true,
      );
      final service = _service(gateway);

      final decision = await service.check(
        'owner/repo',
        RepositoryCriticalAction.syncProject,
      );

      expect(decision.blocked, isFalse);
      expect(decision.requiredPermissions, isEmpty);
    });

    test('PAT clássico com repo pode disparar build sem escopo workflow', () async {
      final gateway = _CountingGateway(
        token: 'ghp_teste',
        oauthScopes: 'repo',
        admin: true,
      );
      final service = _service(gateway);

      final decision = await service.check(
        'owner/repo',
        RepositoryCriticalAction.sendBuild,
      );

      expect(decision.blocked, isFalse);
    });

    test('alterar arquivo de workflow exige workflow no PAT clássico', () async {
      final gateway = _CountingGateway(
        token: 'ghp_teste',
        oauthScopes: 'repo',
        admin: true,
      );
      final service = _service(gateway);

      final decision = await service.check(
        'owner/repo',
        RepositoryCriticalAction.syncProjectWorkflowFiles,
      );

      expect(decision.blocked, isTrue);
      expect(decision.requiredPermissions, contains('workflow'));
    });

    test('PAT clássico com repo e workflow pode alterar workflow', () async {
      final gateway = _CountingGateway(
        token: 'ghp_teste',
        oauthScopes: 'repo, workflow',
        admin: true,
      );
      final service = _service(gateway);

      final decision = await service.check(
        'owner/repo',
        RepositoryCriticalAction.syncProjectWorkflowFiles,
      );

      expect(decision.blocked, isFalse);
      expect(decision.denied, isEmpty);
    });

    test('PAT fine-grained inconclusivo não é bloqueado preventivamente', () async {
      final gateway = _CountingGateway(
        token: 'github_pat_teste',
        admin: true,
      );
      final service = _service(gateway);

      final decision = await service.check(
        'owner/repo',
        RepositoryCriticalAction.sendBuild,
      );

      expect(decision.blocked, isFalse);
      expect(decision.unknown.length, 1);
    });

    test('pré-check usa a branch selecionada no diagnóstico', () async {
      final gateway = _CountingGateway(
        token: 'ghp_teste',
        oauthScopes: 'repo',
        admin: true,
      );
      final service = _service(gateway);

      final decision = await service.check(
        'owner/repo',
        RepositoryCriticalAction.syncProject,
        branch: 'release/2.0',
      );

      expect(decision.blocked, isFalse);
      expect(gateway.lastContentsRef, 'release/2.0');
      expect(
        gateway.requestedPaths,
        contains('/repos/owner/repo/branches/release%2F2.0'),
      );
    });

    test('workflow alterado em PAT fine-grained sinaliza Workflows write', () async {
      final gateway = _CountingGateway(
        token: 'github_pat_teste',
        admin: true,
      );
      final service = _service(gateway);

      final decision = await service.check(
        'owner/repo',
        RepositoryCriticalAction.syncProjectWorkflowFiles,
      );

      expect(decision.blocked, isFalse);
      expect(
        decision.unknown.map((item) => item.requiredPermission),
        contains('Workflows: write'),
      );
    });

    test('bloqueia Secrets quando leitura já foi negada pelo GitHub', () async {
      final gateway = _CountingGateway(
        token: 'github_pat_teste',
        admin: true,
        overrides: {
          '/repos/owner/repo/actions/secrets': const PermissionProbe(
            statusCode: 403,
            data: {'message': 'Forbidden'},
            acceptedPermissions: 'secrets=read',
          ),
        },
      );
      final service = _service(gateway);

      final decision = await service.check(
        'owner/repo',
        RepositoryCriticalAction.manageSecrets,
      );

      expect(decision.blocked, isTrue);
      expect(decision.requiredPermissions, contains('Secrets: write'));
    });

    test('bloqueia exclusão quando PAT clássico não possui delete_repo', () async {
      final gateway = _CountingGateway(
        token: 'ghp_teste',
        oauthScopes: 'repo, workflow',
        admin: true,
      );
      final service = _service(gateway);

      final decision = await service.check(
        'owner/repo',
        RepositoryCriticalAction.deleteRepository,
      );

      expect(decision.blocked, isTrue);
      expect(decision.requiredPermissions, contains('delete_repo'));
    });

    test('consulta o GitHub novamente em cada diagnóstico', () async {
      var currentToken = 'ghp_primeiro';
      final gateway = _CountingGateway(
        token: currentToken,
        oauthScopes: 'repo, workflow, delete_repo',
        admin: true,
      );
      final diagnostics = TokenPermissionDiagnosticsService.withGateway(gateway);
      final service = PermissionPreflightService.withTokenReader(
        diagnostics,
        () async => currentToken,
      );

      await service.check('owner/repo', RepositoryCriticalAction.sendBuild);
      await service.check('owner/repo', RepositoryCriticalAction.manageSecrets);
      expect(gateway.userCalls, 2);

      currentToken = 'ghp_segundo';
      gateway.token = currentToken;
      await service.check('owner/repo', RepositoryCriticalAction.sendBuild);
      expect(gateway.userCalls, 3);
    });
  });
}

PermissionPreflightService _service(_CountingGateway gateway) {
  final diagnostics = TokenPermissionDiagnosticsService.withGateway(gateway);
  return PermissionPreflightService.withTokenReader(
    diagnostics,
    () async => gateway.token,
  );
}

class _CountingGateway implements TokenPermissionDiagnosticsGateway {
  _CountingGateway({
    required this.token,
    this.oauthScopes,
    this.admin = false,
    this.push = true,
    this.overrides = const {},
  });

  String token;
  final String? oauthScopes;
  final bool admin;
  final bool push;
  final Map<String, PermissionProbe> overrides;
  int userCalls = 0;
  String? lastContentsRef;
  final List<String> requestedPaths = <String>[];

  @override
  Future<String?> readToken() async => token;

  @override
  Future<PermissionProbe> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    requestedPaths.add(path);
    if (path == '/repos/owner/repo/contents') {
      lastContentsRef = queryParameters?['ref']?.toString();
    }
    final override = overrides[path];
    if (override != null) return override;

    if (path == '/user') {
      userCalls++;
      return PermissionProbe(
        statusCode: 200,
        data: const {'login': 'tester'},
        oauthScopes: oauthScopes,
      );
    }
    if (path == '/repos/owner/repo') {
      return PermissionProbe(
        statusCode: 200,
        data: {
          'default_branch': 'main',
          'size': 10,
          'permissions': {
            'admin': admin,
            'maintain': false,
            'push': push || admin,
            'pull': true,
          },
        },
        oauthScopes: oauthScopes,
      );
    }
    return const PermissionProbe(statusCode: 200, data: {});
  }
}
