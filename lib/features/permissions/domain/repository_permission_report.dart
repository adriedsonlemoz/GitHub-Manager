enum GitHubTokenKind {
  fineGrained,
  classic,
  unknown,
}

enum PermissionVerdict {
  allowed,
  inferred,
  denied,
  unknown,
}

enum RepositoryPermissionArea {
  contents,
  actions,
  secrets,
  administration,
  deletion,
}

class PermissionAccessResult {
  const PermissionAccessResult({
    required this.verdict,
    required this.label,
    required this.detail,
    this.requiredPermission,
    this.httpStatus,
    this.endpoint,
    this.acceptedPermissions,
  });

  final PermissionVerdict verdict;
  final String label;
  final String detail;
  final String? requiredPermission;
  final int? httpStatus;
  final String? endpoint;
  final String? acceptedPermissions;

  bool get isProblem => verdict == PermissionVerdict.denied;
}

class RepositoryPermissionCapability {
  const RepositoryPermissionCapability({
    required this.area,
    required this.title,
    required this.summary,
    this.read,
    this.write,
  });

  final RepositoryPermissionArea area;
  final String title;
  final String summary;
  final PermissionAccessResult? read;
  final PermissionAccessResult? write;

  bool get hasProblem => read?.isProblem == true || write?.isProblem == true;
}

class RepositoryPermissionReport {
  const RepositoryPermissionReport({
    required this.repositoryFullName,
    required this.tokenKind,
    required this.repositoryRole,
    required this.classicScopes,
    required this.capabilities,
    required this.checkedAt,
    required this.safeMode,
  });

  final String repositoryFullName;
  final GitHubTokenKind tokenKind;
  final String repositoryRole;
  final List<String> classicScopes;
  final List<RepositoryPermissionCapability> capabilities;
  final DateTime checkedAt;
  final bool safeMode;

  int get deniedCount => capabilities.where((item) => item.hasProblem).length;

  String get tokenKindLabel => switch (tokenKind) {
        GitHubTokenKind.fineGrained => 'PAT fine-grained',
        GitHubTokenKind.classic => 'PAT clássico',
        GitHubTokenKind.unknown => 'Token GitHub',
      };

  String diagnosticText() {
    final buffer = StringBuffer()
      ..writeln('GitHub Manager — diagnóstico de permissões')
      ..writeln('Repositório: $repositoryFullName')
      ..writeln('Token: $tokenKindLabel')
      ..writeln('Papel no repositório: $repositoryRole')
      ..writeln('Modo seguro: ${safeMode ? 'sim — somente leitura' : 'não'}')
      ..writeln('Verificado em: ${checkedAt.toIso8601String()}');
    if (classicScopes.isNotEmpty) {
      buffer.writeln('Escopos clássicos: ${classicScopes.join(', ')}');
    }
    buffer.writeln();

    for (final capability in capabilities) {
      buffer.writeln(capability.title);
      if (capability.read != null) {
        _writeResult(buffer, 'Leitura', capability.read!);
      }
      if (capability.write != null) {
        _writeResult(buffer, 'Escrita', capability.write!);
      }
      buffer.writeln();
    }
    buffer.writeln(
      'Observação: permissões de escrita de PAT fine-grained não são testadas '
      'com mutações para evitar alterar o repositório durante o diagnóstico.',
    );
    return buffer.toString().trimRight();
  }

  static void _writeResult(
    StringBuffer buffer,
    String prefix,
    PermissionAccessResult result,
  ) {
    buffer.writeln('- $prefix: ${result.label}');
    buffer.writeln('  ${result.detail}');
    if (result.requiredPermission != null) {
      buffer.writeln('  Permissão: ${result.requiredPermission}');
    }
    if (result.httpStatus != null) {
      buffer.writeln('  HTTP: ${result.httpStatus}');
    }
    if (result.acceptedPermissions != null &&
        result.acceptedPermissions!.isNotEmpty) {
      buffer.writeln(
        '  X-Accepted-GitHub-Permissions: ${result.acceptedPermissions}',
      );
    }
  }
}
