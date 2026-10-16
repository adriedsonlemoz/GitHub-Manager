import 'dart:convert';

import 'package:github_manager/core/network/github_api_client.dart';
import 'package:github_manager/features/repositories/domain/github_repository.dart';
import 'package:github_manager/features/repositories/domain/play_readiness_report.dart';

/// Auditoria de pistas do código-fonte, não uma simulação da análise do Play Console.
/// Lê apenas arquivos públicos/restritos por nome: nunca baixa keystores ou Secrets.
class PlayReadinessService {
  const PlayReadinessService(this.client);

  final GitHubApiClient client;

  Future<PlayReadinessReport> inspect(GitHubRepository repository) async {
    final branch = repository.defaultBranch;
    final base = '/repos/${repository.fullName}';
    final treeResponse = await client.get<Map<String, dynamic>>(
      '$base/git/trees/${Uri.encodeComponent(branch)}',
      queryParameters: const {'recursive': '1'},
    );
    final body = treeResponse.data ?? const <String, dynamic>{};
    final complete = body['truncated'] != true;
    final paths = (body['tree'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .where((entry) => entry['type'] == 'blob')
        .map((entry) => (entry['path'] ?? '').toString())
        .where((path) => path.isNotEmpty)
        .toList(growable: false);
    final lower = paths.map((p) => p.toLowerCase()).toSet();
    String? choose(List<String> candidates) {
      for (final path in candidates) {
        for (final actual in paths) {
          if (actual.toLowerCase() == path.toLowerCase()) return actual;
        }
      }
      return null;
    }

    final gradleFile = choose(const [
      'android/app/build.gradle.kts',
      'android/app/build.gradle',
      'app/build.gradle.kts',
      'app/build.gradle',
    ]);
    final manifestFile = choose(const [
      'android/app/src/main/AndroidManifest.xml',
      'app/src/main/AndroidManifest.xml',
    ]);
    final pubspecFile = choose(const ['pubspec.yaml']);
    final flutterProject = pubspecFile != null && lower.any((p) => p.endsWith('lib/main.dart'));
    final androidProject = gradleFile != null || manifestFile != null || flutterProject;
    if (!androidProject) {
      return PlayReadinessReport(
        branch: branch,
        androidProject: false,
        completeTree: complete,
        automatic: const [],
        manual: const [],
        note: complete
            ? 'Nenhum aplicativo Android reconhecido. Esta auditoria se aplica a apps Android, não a sites ou bibliotecas genéricas.'
            : 'A árvore do GitHub foi truncada. Não é possível classificar este projeto com segurança.',
      );
    }

    Future<String?> read(String? path) async {
      if (path == null) return null;
      try {
        final response = await client.get<Map<String, dynamic>>(
          '$base/contents/${path.split('/').map(Uri.encodeComponent).join('/')}',
          queryParameters: {'ref': branch},
        );
        final json = response.data ?? const <String, dynamic>{};
        if (json['encoding'] != 'base64') return null;
        final encoded = (json['content'] as String? ?? '').replaceAll('\n', '');
        if (encoded.isEmpty || encoded.length > 600000) return null;
        return utf8.decode(base64.decode(encoded), allowMalformed: true);
      } catch (_) {
        return null;
      }
    }

    final gradle = await read(gradleFile);
    final manifest = await read(manifestFile);
    final pubspec = await read(pubspecFile);
    // Limita consultas adicionais a workflows; nenhuma variável/Secret é buscada.
    final workflows = <String, String>{};
    for (final path in paths.where((p) =>
        p.toLowerCase().startsWith('.github/workflows/') &&
        (p.endsWith('.yml') || p.endsWith('.yaml'))).take(4)) {
      final content = await read(path);
      if (content != null) workflows[path] = content;
    }
    final automatic = evaluateSources(
      paths: paths,
      completeTree: complete,
      gradlePath: gradleFile,
      gradle: gradle,
      manifestPath: manifestFile,
      manifest: manifest,
      pubspec: pubspec,
      workflowContents: workflows,
    );
    return PlayReadinessReport(
      branch: branch,
      androidProject: true,
      completeTree: complete,
      automatic: automatic,
      manual: manualChecks,
      note: complete ? null : 'Árvore do repositório truncada: itens ausentes podem não ter sido listados.',
    );
  }

  /// Puro e testável, sem consultas remotas. Ausência no repositório não prova
  /// ausência no artefato final; nenhum resultado é certificado pela Play.
  static List<PlayCheck> evaluateSources({
    required List<String> paths,
    required bool completeTree,
    required String? gradlePath,
    required String? gradle,
    required String? manifestPath,
    required String? manifest,
    required String? pubspec,
    Map<String, String> workflowContents = const {},
  }) {
    final lower = paths.map((p) => p.toLowerCase()).toList();
    // Ignora comentários do Gradle na análise de valores literais.
    final executableGradle = (gradle ?? '')
        .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
        .replaceAll(RegExp(r'^\s*//.*$', multiLine: true), '');
    String? match(String? source, RegExp pattern) =>
        pattern.firstMatch(source ?? '')?.group(1);
    final target = int.tryParse(match(executableGradle, RegExp(r'\btargetSdk(?:Version)?\s*(?:=\s*|\s+)(\d+)\b')) ??
        match(manifest, RegExp(r'''android:targetSdkVersion\s*=\s*["'](\d+)["']''')) ?? '');
    final compile = int.tryParse(match(executableGradle, RegExp(r'\bcompileSdk(?:Version)?\s*(?:=\s*|\s+)(\d+)\b')) ?? '');
    final code = int.tryParse(match(executableGradle, RegExp(r'\bversionCode\s*(?:=\s*|\s+)(\d+)\b')) ??
        match(pubspec, RegExp(r'^version:\s*[^\s#+]+\+(\d+)', multiLine: true)) ?? '');
    final applicationId = match(executableGradle, RegExp(r'''\bapplicationId\s*(?:=\s*|\s+)["']([^"']+)["']'''));
    final usesDebug = RegExp(r'''signingConfig\s*=\s*signingConfigs\.(?:getByName\(["']debug["']\)|debug)|signingConfig\s+signingConfigs\.debug''')
        .hasMatch(executableGradle);
    final workflowNames = lower.where((p) => p.startsWith('.github/workflows/') &&
        (p.endsWith('.yml') || p.endsWith('.yaml'))).toList();
    final hasBundle = lower.any((p) => p.endsWith('.aab'));
    String? bundleWorkflow;
    for (final entry in workflowContents.entries) {
      if (RegExp(r'flutter\s+build\s+appbundle|(?:gradlew|gradle)[^\n]*bundleRelease|\bbundleRelease\b',
              caseSensitive: false)
          .hasMatch(entry.value)) {
        bundleWorkflow = entry.key;
        break;
      }
    }
    final privacyFile = lower.any((p) => p.endsWith('privacy.md') ||
        p.endsWith('privacy-policy.md') || p.endsWith('politica-de-privacidade.md') ||
        p.endsWith('privacy_policy.md'));
    final permissionNames = RegExp(r'android\.permission\.(MANAGE_EXTERNAL_STORAGE|QUERY_ALL_PACKAGES|READ_SMS|ACCESS_BACKGROUND_LOCATION|CAMERA|RECORD_AUDIO)')
        .allMatches(manifest ?? '').map((m) => m.group(1)!).toSet().toList()..sort();
    return [
      PlayCheck(
        title: 'API de destino (Android 16 / API 36)',
        state: target == null ? PlayCheckState.unknown :
            target >= 36 ? PlayCheckState.verified : PlayCheckState.attention,
        detail: target == null
            ? 'targetSdk não resolvido no código. Valores dinâmicos como flutter.targetSdkVersion exigem build/merged manifest.'
            : target >= 36
                ? 'Código declara targetSdk $target (mínimo 36 para novos envios Android comuns em 2026).'
                : 'targetSdk $target está abaixo da API 36 exigida para novos envios e atualizações de apps Android comuns em 2026.',
        evidence: target == null ? (gradlePath ?? manifestPath) : gradlePath ?? manifestPath,
      ),
      PlayCheck(
        title: 'compileSdk (informativo)',
        state: PlayCheckState.unknown,
        detail: compile == null
            ? 'Não identificado estaticamente. compileSdk é diferente de targetSdk e não comprova conformidade.'
            : 'compileSdk $compile identificado. Isto NÃO substitui a verificação de targetSdk.',
        evidence: gradlePath,
      ),
      PlayCheck(
        title: 'Versão de publicação (versionCode)',
        state: code == null ? PlayCheckState.unknown :
            (code > 0 && code <= 2100000000 ? PlayCheckState.verified : PlayCheckState.attention),
        detail: code == null
            ? 'versionCode final não identificado. Confira no AAB gerado e compare ao último publicado.'
            : code > 0 && code <= 2100000000
                ? 'Código declarado: $code, dentro do limite da Play. É necessário que seja maior que o já publicado.'
                : 'Código $code fora do intervalo aceito pela Play Console.',
        evidence: gradlePath ?? (pubspec == null ? null : 'pubspec.yaml'),
      ),
      PlayCheck(
        title: 'Identificador do aplicativo',
        state: applicationId == null ? PlayCheckState.unknown : PlayCheckState.verified,
        detail: applicationId == null
            ? 'applicationId literal não encontrado. Confira o identificador efetivo na variante Release.'
            : '$applicationId encontrado no Gradle. Confirme se é definitivo e único na Play Console.',
        evidence: gradlePath,
      ),
      PlayCheck(
        title: 'App Bundle (.aab)',
        state: hasBundle ? PlayCheckState.verified : PlayCheckState.unknown,
        detail: hasBundle
            ? 'Há um arquivo .aab no repositório. Não foi validado nem comparado com o pacote final.'
            : bundleWorkflow != null
                ? 'Workflow prevê gerar um AAB, mas não comprova compilação, assinatura nem arquivo válido.'
                : workflowNames.isEmpty
                    ? 'Não foi encontrado AAB nem workflow para examiná-lo. Gere e valide um AAB Release.'
                    : 'Workflow(s) presente(s), mas sem geração de AAB identificada na amostra. Confira como gerar e assinar o bundle Release.',
        evidence: bundleWorkflow,
      ),
      PlayCheck(
        title: 'Assinatura de produção',
        state: usesDebug ? PlayCheckState.attention : PlayCheckState.unknown,
        detail: usesDebug
            ? 'Possível assinatura debug configurada. Verifique signingConfig da variante Release antes de publicar.'
            : 'Não é possível confirmar a chave de upload/Play App Signing a partir do código. Nenhuma chave privada foi consultada.',
        evidence: gradlePath,
      ),
      PlayCheck(
        title: 'Política de privacidade',
        state: PlayCheckState.unknown,
        detail: privacyFile
            ? 'Há um arquivo de privacidade no repositório. Verifique se existe URL pública válida e se o texto corresponde ao comportamento do app.'
            : 'Não foi localizado um arquivo de política com nome conhecido. Confira a URL pública e o conteúdo no Play Console.',
      ),
      PlayCheck(
        title: 'Permissões sensíveis (manifesto-fonte)',
        state: permissionNames.isEmpty ? PlayCheckState.unknown : PlayCheckState.attention,
        detail: permissionNames.isEmpty
            ? 'Nenhuma permissão da lista de atenção foi identificada no manifesto-fonte. Bibliotecas podem adicionar permissões no manifesto mesclado.'
            : 'Examinadas: ${permissionNames.join(', ')}. Verifique finalidade, declarações e políticas aplicáveis; a presença não significa reprovação automática.',
        evidence: manifestPath,
      ),
      PlayCheck(
        title: 'Compatibilidade 64 bits e páginas de 16 KB',
        state: PlayCheckState.unknown,
        detail: 'Não é possível validar as bibliotecas nativas e alinhamento de páginas só pelos arquivos-fonte. Inspecione o AAB/APK final e teste em dispositivos compatíveis.',
      ),
      if (!completeTree)
        const PlayCheck(
          title: 'Inventário incompleto',
          state: PlayCheckState.unknown,
          detail: 'A API retornou árvore truncada. Ausência de arquivos não é conclusiva.',
        ),
    ];
  }

  static const List<PlayCheck> manualChecks = [
    PlayCheck(
      title: 'Segurança dos dados e privacidade',
      state: PlayCheckState.unknown,
      detail: 'Preencher o formulário de coleta/compartilhamento de dados, inclusive por SDKs de terceiros; revisar política de privacidade e exclusão de conta quando aplicável.',
    ),
    PlayCheck(
      title: 'Conteúdo e ficha da loja',
      state: PlayCheckState.unknown,
      detail: 'Confirmar classificação indicativa, público-alvo, anúncios, permissões especiais, descrição, categoria, screenshots e elementos gráficos.',
    ),
    PlayCheck(
      title: 'Conta, testes e acesso à produção',
      state: PlayCheckState.unknown,
      detail: 'Na Play Console, verificar identidade/conta, acesso à produção e requisitos de teste. Certas contas pessoais novas precisam de 12 testadores durante 14 dias contínuos.',
    ),
    PlayCheck(
      title: 'Release e revisão final',
      state: PlayCheckState.unknown,
      detail: 'Compilar AAB assinado, executar testes em aparelhos, conferir crashes/ANRs, políticas aplicáveis e enviar à revisão na Play Console.',
    ),
  ];
}
