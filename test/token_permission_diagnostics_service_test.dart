import 'package:flutter_test/flutter_test.dart';
import 'package:github_manager/features/permissions/data/token_permission_diagnostics_service.dart';
import 'package:github_manager/features/permissions/domain/repository_permission_report.dart';

void main() {
  group('TokenPermissionDiagnosticsService', () {
    test('PAT clássico com escopos e papel admin confirma capacidades por inferência', () async {
      final gateway = _FakeGateway(
        token: 'ghp_teste',
        oauthScopes: 'repo, workflow, delete_repo',
        admin: true,
      );
      final report = await TokenPermissionDiagnosticsService.withGateway(gateway)
          .diagnose('owner/repo');

      expect(report.tokenKind, GitHubTokenKind.classic);
      expect(report.repositoryRole, 'Administrador');
      expect(_area(report, RepositoryPermissionArea.contents).read!.verdict,
          PermissionVerdict.allowed);
      expect(_area(report, RepositoryPermissionArea.contents).write!.verdict,
          PermissionVerdict.inferred);
      expect(_area(report, RepositoryPermissionArea.actions).write!.verdict,
          PermissionVerdict.inferred);
      expect(_area(report, RepositoryPermissionArea.secrets).write!.verdict,
          PermissionVerdict.inferred);
      expect(_area(report, RepositoryPermissionArea.deletion).write!.verdict,
          PermissionVerdict.inferred);
    });

    test('PAT clássico informa escopos ausentes', () async {
      final gateway = _FakeGateway(
        token: 'ghp_teste',
        oauthScopes: 'read:user',
        admin: true,
      );
      final report = await TokenPermissionDiagnosticsService.withGateway(gateway)
          .diagnose('owner/repo');

      final contents = _area(report, RepositoryPermissionArea.contents).write!;
      final deletion = _area(report, RepositoryPermissionArea.deletion).write!;
      expect(contents.verdict, PermissionVerdict.denied);
      expect(contents.requiredPermission, 'repo + workflow');
      expect(deletion.verdict, PermissionVerdict.denied);
      expect(deletion.requiredPermission, 'delete_repo');
    });

    test('PAT fine-grained confirma leitura sem executar mutações de escrita', () async {
      final gateway = _FakeGateway(
        token: 'github_pat_teste',
        admin: true,
      );
      final report = await TokenPermissionDiagnosticsService.withGateway(gateway)
          .diagnose('owner/repo');

      expect(report.tokenKind, GitHubTokenKind.fineGrained);
      expect(_area(report, RepositoryPermissionArea.actions).read!.verdict,
          PermissionVerdict.allowed);
      final write = _area(report, RepositoryPermissionArea.actions).write!;
      expect(write.verdict, PermissionVerdict.unknown);
      expect(write.requiredPermission, 'Actions: write');
      expect(report.safeMode, isTrue);
    });

    test('usa X-Accepted-GitHub-Permissions para explicar leitura negada', () async {
      final gateway = _FakeGateway(
        token: 'github_pat_teste',
        admin: true,
        overrides: {
          '/repos/owner/repo/actions/secrets': const PermissionProbe(
            statusCode: 403,
            data: {'message': 'Resource not accessible by personal access token'},
            acceptedPermissions: 'secrets=read',
          ),
        },
      );
      final report = await TokenPermissionDiagnosticsService.withGateway(gateway)
          .diagnose('owner/repo');

      final secrets = _area(report, RepositoryPermissionArea.secrets);
      expect(secrets.read!.verdict, PermissionVerdict.denied);
      expect(secrets.read!.requiredPermission, 'secrets=read');
      expect(secrets.write!.verdict, PermissionVerdict.denied);
      expect(report.diagnosticText(), contains('X-Accepted-GitHub-Permissions'));
      expect(report.diagnosticText(), isNot(contains('github_pat_teste')));
    });


    test('não confunde rate limit com permissão ausente', () async {
      final gateway = _FakeGateway(
        token: 'github_pat_teste',
        admin: true,
        overrides: {
          '/repos/owner/repo/actions/workflows': const PermissionProbe(
            statusCode: 403,
            data: {'message': 'API rate limit exceeded'},
            rateLimitRemaining: '0',
          ),
        },
      );

      expect(
        () => TokenPermissionDiagnosticsService.withGateway(gateway)
            .diagnose('owner/repo'),
        throwsA(isA<Exception>()),
      );
    });

    test('papel sem administração bloqueia administração e exclusão', () async {
      final gateway = _FakeGateway(
        token: 'ghp_teste',
        oauthScopes: 'repo, delete_repo',
        admin: false,
        push: true,
        overrides: {
          '/repos/owner/repo/actions/permissions': const PermissionProbe(
            statusCode: 403,
            data: {'message': 'Forbidden'},
            acceptedPermissions: 'administration=read',
          ),
        },
      );
      final report = await TokenPermissionDiagnosticsService.withGateway(gateway)
          .diagnose('owner/repo');

      expect(
        _area(report, RepositoryPermissionArea.administration).write!.verdict,
        PermissionVerdict.denied,
      );
      expect(
        _area(report, RepositoryPermissionArea.deletion).write!.verdict,
        PermissionVerdict.denied,
      );
    });
  });
}

RepositoryPermissionCapability _area(
  RepositoryPermissionReport report,
  RepositoryPermissionArea area,
) => report.capabilities.firstWhere((item) => item.area == area);

class _FakeGateway implements TokenPermissionDiagnosticsGateway {
  _FakeGateway({
    required this.token,
    this.oauthScopes,
    this.admin = false,
    this.push = true,
    this.overrides = const {},
  });

  final String token;
  final String? oauthScopes;
  final bool admin;
  final bool push;
  final Map<String, PermissionProbe> overrides;

  @override
  Future<String?> readToken() async => token;

  @override
  Future<PermissionProbe> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final override = overrides[path];
    if (override != null) return override;

    if (path == '/user') {
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
