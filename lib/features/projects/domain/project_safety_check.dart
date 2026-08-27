import 'package:github_manager/features/projects/domain/zip_project.dart';
import 'package:github_manager/features/repositories/domain/github_repository.dart';
import 'package:github_manager/features/repositories/domain/repository_project_info.dart';

enum ProjectVersionComparison { older, same, newer, unknown }

class ProjectSafetyCheck {
  const ProjectSafetyCheck({
    required this.blocked,
    required this.warning,
    required this.message,
    required this.identitySource,
    required this.versionComparison,
  });

  final bool blocked;
  final bool warning;
  final String message;
  final String identitySource;
  final ProjectVersionComparison versionComparison;

  static ProjectSafetyCheck compare({
    required ZipProjectPreview project,
    required GitHubRepository repository,
    required RepositoryProjectInfo repositoryInfo,
  }) {
    final zipAppId = _normalize(project.applicationId);
    final repoAppId = _normalize(repositoryInfo.applicationId);
    final appIdsComparable = zipAppId.isNotEmpty && repoAppId.isNotEmpty;
    if (appIdsComparable && zipAppId != repoAppId) {
      return ProjectSafetyCheck(
        blocked: true,
        warning: false,
        identitySource: 'applicationId',
        versionComparison: ProjectVersionComparison.unknown,
        message:
            'Este ZIP pertence a outro aplicativo. applicationId diferente: ${project.applicationId} ≠ ${repositoryInfo.applicationId}.',
      );
    }

    final zipPackage = _canonicalProjectName(
      project.packageName,
      stripVersionSuffix: true,
    );
    final repoPackage = _canonicalProjectName(
      repositoryInfo.packageName,
      stripVersionSuffix: true,
    );
    final packagesComparable = zipPackage.isNotEmpty && repoPackage.isNotEmpty;
    if (!appIdsComparable && packagesComparable && zipPackage != repoPackage) {
      return ProjectSafetyCheck(
        blocked: true,
        warning: false,
        identitySource: 'pacote do projeto',
        versionComparison: ProjectVersionComparison.unknown,
        message:
            'Este ZIP parece ser de outro projeto. Pacote detectado: ${project.packageName}; esperado: ${repositoryInfo.packageName}.',
      );
    }

    final explicitZipName = _canonicalProjectName(
      project.projectName,
      stripVersionSuffix: true,
    );
    final repoProjectName = _canonicalProjectName(
      repositoryInfo.projectName,
      stripVersionSuffix: true,
    );
    final repositoryName = _canonicalProjectName(
      repository.name,
      stripVersionSuffix: true,
    );
    final hasStrongerIdentity = appIdsComparable || packagesComparable;

    if (!hasStrongerIdentity && explicitZipName.isNotEmpty) {
      final explicitNameMatches = explicitZipName == repoProjectName ||
          explicitZipName == repositoryName;
      if (!explicitNameMatches) {
        return ProjectSafetyCheck(
          blocked: true,
          warning: false,
          identitySource: 'metadados do projeto',
          versionComparison: ProjectVersionComparison.unknown,
          message:
              'O projeto identificado nos metadados do ZIP (${project.projectName}) não corresponde ao repositório aberto (${repositoryInfo.projectName}).',
        );
      }
    }

    final weakZipName = _canonicalProjectName(
      project.name.replaceFirst(RegExp(r'\.zip$', caseSensitive: false), ''),
      stripVersionSuffix: true,
    );
    final weakNameMatches = weakZipName.isNotEmpty &&
        (weakZipName == repoProjectName || weakZipName == repositoryName);

    final identitySource = appIdsComparable
        ? 'applicationId'
        : packagesComparable
            ? 'pacote do projeto'
            : explicitZipName.isNotEmpty &&
                    (explicitZipName == repoProjectName ||
                        explicitZipName == repositoryName)
                ? 'metadados do projeto'
                : weakNameMatches
                    ? 'nome do arquivo ZIP (pista)'
                    : 'não confirmada';

    final versionComparison = compareVersions(
      project.version,
      project.versionCode,
      repositoryInfo.version,
      repositoryInfo.versionCode,
    );

    if (versionComparison == ProjectVersionComparison.older) {
      return ProjectSafetyCheck(
        blocked: true,
        warning: false,
        identitySource: identitySource,
        versionComparison: versionComparison,
        message:
            'A versão do ZIP é anterior à versão atual do GitHub. O envio foi bloqueado para evitar substituir o projeto por uma versão antiga.',
      );
    }

    if (versionComparison == ProjectVersionComparison.same) {
      return ProjectSafetyCheck(
        blocked: false,
        warning: true,
        identitySource: identitySource,
        versionComparison: versionComparison,
        message:
            'É o mesmo projeto e a mesma versão. Confira se você realmente quer reenviar esta build.',
      );
    }

    final hasIdentityEvidence = hasStrongerIdentity ||
        (explicitZipName.isNotEmpty &&
            (explicitZipName == repoProjectName || explicitZipName == repositoryName)) ||
        weakNameMatches;

    if (versionComparison == ProjectVersionComparison.unknown) {
      return ProjectSafetyCheck(
        blocked: false,
        warning: true,
        identitySource: identitySource,
        versionComparison: versionComparison,
        message: hasIdentityEvidence
            ? 'O projeto é compatível, mas não foi possível comparar as versões com segurança.'
            : 'Não foi possível confirmar totalmente a identidade nem comparar a versão deste ZIP. Confira os dados antes de enviar.',
      );
    }

    if (!hasIdentityEvidence) {
      return ProjectSafetyCheck(
        blocked: false,
        warning: true,
        identitySource: identitySource,
        versionComparison: versionComparison,
        message:
            'A versão é válida, mas a identidade do ZIP não pôde ser confirmada totalmente. Confira o projeto antes de enviar.',
      );
    }

    return ProjectSafetyCheck(
      blocked: false,
      warning: false,
      identitySource: identitySource,
      versionComparison: versionComparison,
      message: 'Projeto compatível. A identidade e a versão foram conferidas.',
    );
  }

  static ProjectVersionComparison compareVersions(
    String? zipVersion,
    int? zipCode,
    String? repoVersion,
    int? repoCode,
  ) {
    if (zipCode != null && repoCode != null && zipCode != repoCode) {
      return zipCode < repoCode
          ? ProjectVersionComparison.older
          : ProjectVersionComparison.newer;
    }

    final a = _versionParts(zipVersion);
    final b = _versionParts(repoVersion);
    if (a == null || b == null) {
      return ProjectVersionComparison.unknown;
    }

    final max = a.length > b.length ? a.length : b.length;
    for (var i = 0; i < max; i++) {
      final av = i < a.length ? a[i] : 0;
      final bv = i < b.length ? b[i] : 0;
      if (av != bv) {
        return av < bv
            ? ProjectVersionComparison.older
            : ProjectVersionComparison.newer;
      }
    }
    return ProjectVersionComparison.same;
  }

  static List<int>? _versionParts(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    final matches = RegExp(r'\d+').allMatches(trimmed).toList(growable: false);
    if (matches.isEmpty) return null;
    return matches
        .map((match) => int.parse(match.group(0)!))
        .toList(growable: false);
  }

  static String _canonicalProjectName(
    String? value, {
    bool stripVersionSuffix = false,
  }) {
    var resolved = (value ?? '').trim();
    if (stripVersionSuffix && resolved.isNotEmpty) {
      final versionSuffix = RegExp(
        r'(?:[-_.\s]+v?\d+(?:\.\d+){1,3}(?:[-+._a-z0-9].*)?)$',
        caseSensitive: false,
      );
      resolved = resolved.replaceFirst(versionSuffix, '');
    }
    return _normalize(resolved);
  }

  static String _normalize(String? value) => (value ?? '')
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]'), '');
}
