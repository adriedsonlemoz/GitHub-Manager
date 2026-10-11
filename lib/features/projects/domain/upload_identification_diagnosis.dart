import 'package:github_manager/features/projects/domain/project_safety_check.dart';
import 'package:github_manager/features/projects/domain/zip_project.dart';
import 'package:github_manager/features/repositories/domain/github_repository.dart';
import 'package:github_manager/features/repositories/domain/repository_project_info.dart';

/// Explicações específicas e exportáveis sem dados de autenticação.
class UploadIdentificationDiagnosis {
  const UploadIdentificationDiagnosis._();

  static List<String> guidance({
    required ZipProjectPreview project,
    required RepositoryProjectInfo remote,
    required GitHubRepository repository,
    required ProjectSafetyCheck check,
  }) {
    final steps = <String>[];
    if (remote.metadataIssue != null) {
      steps.add('Consulta do GitHub: ${remote.metadataIssue} Verifique a conexão, '
          'as permissões do token e se a branch selecionada existe. Tente novamente.');
    }
    if (project.version == null) {
      steps.add('Versão do ZIP: não foi encontrada uma versão interna confiável. '
          'Declare version no pubspec.yaml ou package.json, versionName no '
          'build.gradle(.kts), ou version em app_identity.json/github-manager.json. '
          'O nome do ZIP não valida uma versão.');
    }
    if (remote.version == null && remote.metadataIssue == null) {
      steps.add('Versão do GitHub: confira a branch de destino e os arquivos '
          'já publicados nela. Se o repositório estiver vazio, não há versão '
          'anterior a comparar. Caso contrário, publique um arquivo de versão '
          'compatível, como pubspec.yaml, package.json ou app_identity.json.');
    }
    if (remote.nameSource == null) {
      steps.add('Nome do repositório: o nome exibido é uma alternativa. '
          'Informe displayName em app_identity.json/github-manager.json; '
          'no Android, confira android:label no AndroidManifest.xml e '
          'res/values/strings.xml.');
    }
    if (check.identitySource.contains('divergente') || check.blocked) {
      steps.add('Identidade divergente: confira o applicationId e o pacote '
          'de origem em ambos os projetos. Não altere o identificador só '
          'para eliminar este aviso. Confirme se está enviando para o destino correto.');
    } else if (check.identitySource.contains('pista') ||
        check.identitySource == 'não confirmada') {
      steps.add('Identidade não confirmada: nomes são pistas e podem mudar. '
          'Verifique se ${repository.fullName} é realmente o destino desejado '
          'e, quando possível, forneça metadados explícitos.');
    }
    if (check.versionComparison == ProjectVersionComparison.older) {
      steps.add('Versão anterior: o ZIP pode substituir arquivos de uma versão '
          'mais recente. Compare as alterações antes de continuar.');
    } else if (check.versionComparison == ProjectVersionComparison.same) {
      steps.add('Mesma versão: o envio repetido pode modificar os arquivos '
          'sem alterar a versão. Confira a prévia da sincronização.');
    }
    if (steps.isEmpty) {
      steps.add('Identificadores compatíveis. Confira a branch e os arquivos '
          'que serão alterados antes de confirmar.');
    }
    return steps;
  }

  static String report({
    required ZipProjectPreview project,
    required RepositoryProjectInfo remote,
    required GitHubRepository repository,
    required String branch,
    required ProjectSafetyCheck check,
  }) => <String>[
        'GitHub Manager - diagnóstico de identificação (sem credenciais)',
        'Destino: ${repository.fullName} / $branch',
        'Projeto no ZIP: ${project.identityLabel}',
        'Versão do ZIP: ${project.displayVersionLabel ?? 'não identificada'}',
        'Nome no GitHub: ${remote.projectName}',
        'Origem do nome: ${remote.nameSource ?? 'nome do repositório (alternativa)'}',
        'Versão no GitHub: ${remote.displayVersionLabel ?? 'não identificada'}',
        'Identidade usada: ${check.identitySource}',
        'Comparação: ${check.versionComparison.name}',
        'Aviso: ${check.message}',
        '',
        'Orientações:',
        ...guidance(project: project, remote: remote,
            repository: repository, check: check).map((step) => '- $step'),
      ].join('\n');
}
