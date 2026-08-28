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
    final appIdDiffers = appIdsComparable && zipAppId != repoAppId;

    final zipPackage = _canonicalProjectName(
      project.packageName,
      stripVersionSuffix: true,
    );
    final repoPackage = _canonicalProjectName(
      repositoryInfo.packageName,
      stripVersionSuffix: true,
    );
    final packagesComparable = zipPackage.isNotEmpty && repoPackage.isNotEmpty;
    final packageDiffers = packagesComparable && zipPackage != repoPackage;

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
    final explicitNameMatches = explicitZipName.isNotEmpty &&
        (explicitZipName == repoProjectName || explicitZipName == repositoryName);

    final weakZipName = _canonicalProjectName(
      project.name.replaceFirst(RegExp(r'\.zip$', caseSensitive: false), ''),
      stripVersionSuffix: true,
    );
    final weakNameMatches = weakZipName.isNotEmpty &&
        (weakZipName == repoProjectName || weakZipName == repositoryName);

    final versionComparison = compareVersions(
      project.version,
      project.versionCode,
      repositoryInfo.version,
      repositoryInfo.versionCode,
    );

    if (appIdDiffers && packageDiffers) {
      return ProjectSafetyCheck(
        blocked: true,
        warning: true,
        identitySource: 'applicationId + pacote divergentes',
        versionComparison: versionComparison,
        message:
            'Dois identificadores fortes apontam para outro projeto: applicationId e pacote são diferentes. O envio ainda pode ser forçado com confirmação extra.',
      );
    }

    final identitySource = appIdsComparable && !appIdDiffers
        ? 'applicationId'
        : packagesComparable && !packageDiffers
            ? 'pacote do projeto'
            : explicitNameMatches
                ? 'metadados do projeto'
                : weakNameMatches
                    ? 'nome do ZIP (pista)'
                    : 'não confirmada';

    if (appIdDiffers) {
      return ProjectSafetyCheck(
        blocked: false,
        warning: true,
        identitySource: 'applicationId divergente',
        versionComparison: versionComparison,
        message:
            'O applicationId mudou em relação ao repositório. Isso pode ser intencional após migração ou renomeação; confira antes de enviar.',
      );
    }

    if (packageDiffers) {
      return ProjectSafetyCheck(
        blocked: false,
        warning: true,
        identitySource: 'pacote divergente',
        versionComparison: versionComparison,
        message:
            'O pacote do projeto mudou em relação ao repositório. O envio continua disponível, mas confirme se a mudança é intencional.',
      );
    }

    if (versionComparison == ProjectVersionComparison.older) {
      return ProjectSafetyCheck(
        blocked: false,
        warning: true,
        identitySource: identitySource,
        versionComparison: versionComparison,
        message:
            'O ZIP contém uma versão anterior à atual do GitHub. Regressão é permitida; confirme se deseja substituir o conteúdo atual.',
      );
    }

    if (!explicitNameMatches &&
        explicitZipName.isNotEmpty &&
        !appIdsComparable &&
        !packagesComparable) {
      return ProjectSafetyCheck(
        blocked: false,
        warning: true,
        identitySource: 'nome/metadados (pista)',
        versionComparison: versionComparison,
        message:
            'O nome do projeto no ZIP difere do nome do repositório. Como nomes podem mudar, isso é apenas um aviso e não bloqueia o envio.',
      );
    }

    if (versionComparison == ProjectVersionComparison.same) {
      return ProjectSafetyCheck(
        blocked: false,
        warning: true,
        identitySource: identitySource,
        versionComparison: versionComparison,
        message:
            'A mesma versão já está no GitHub. O reenvio é permitido; confira se deseja substituir o conteúdo atual.',
      );
    }

    final hasIdentityEvidence =
        (appIdsComparable && !appIdDiffers) ||
        (packagesComparable && !packageDiffers) ||
        explicitNameMatches ||
        weakNameMatches;

    if (versionComparison == ProjectVersionComparison.unknown) {
      return ProjectSafetyCheck(
        blocked: false,
        warning: true,
        identitySource: identitySource,
        versionComparison: versionComparison,
        message: hasIdentityEvidence
            ? 'A identidade parece compatível, mas não foi possível comparar as versões com segurança.'
            : 'Não foi possível confirmar totalmente a identidade nem a versão. Confira o destino antes de enviar.',
      );
    }

    if (!hasIdentityEvidence) {
      return ProjectSafetyCheck(
        blocked: false,
        warning: true,
        identitySource: identitySource,
        versionComparison: versionComparison,
        message:
            'A identidade não pôde ser confirmada por um identificador forte. Nome e versão não são usados como bloqueio.',
      );
    }

    return ProjectSafetyCheck(
      blocked: false,
      warning: false,
      identitySource: identitySource,
      versionComparison: versionComparison,
      message: 'Projeto compatível. Os identificadores disponíveis foram conferidos.',
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

  static String _normalize(String? value) {
    var normalized = (value ?? '').trim().toLowerCase();
    const folds = <String, String>{
      'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
      'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
      'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
      'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
      'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
      'ç': 'c', 'ñ': 'n',
    };
    folds.forEach((accented, plain) {
      normalized = normalized.replaceAll(accented, plain);
    });
    return normalized.replaceAll(RegExp(r'[^a-z0-9]'), '');
  }
}
