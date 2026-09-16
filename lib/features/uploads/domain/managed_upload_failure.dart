part of 'managed_upload.dart';

class _ManagedUploadFailureDiagnostics {
  const _ManagedUploadFailureDiagnostics(this.item);

  final ManagedUpload item;

  String? get failureOperation => item.failureOperation;
  String? get failureStage => item.failureStage;
  int? get errorHttpStatus => item.errorHttpStatus;
  String? get errorApiMessage => item.errorApiMessage;
  int get changedFiles => item.changedFiles;
  int get resumedFiles => item.resumedFiles;
  int get removedFiles => item.removedFiles;
  String? get errorCode => item.errorCode;
  String? get errorEndpoint => item.errorEndpoint;
  ProjectUploadMethod get uploadMethod => item.uploadMethod;
  String? get commitSha => item.commitSha;
  int get current => item.current;
  int get total => item.total;
  int get fallbackCommitCount => item.fallbackCommitCount;
  String? get errorMessage => item.errorMessage;
  String get branch => item.branch;
  String? get failedFilePath => item.failedFilePath;
  List<String> get recoveryEvents => item.recoveryEvents;

  String get failureOperationLabel {
    final value = failureOperation?.trim();
    if (value != null && value.isNotEmpty) return value;
    if (failureStage == 'build') return 'Inicialização da build';
    return 'Sincronização com o repositório';
  }

  String get githubFailureResponse {
    final parts = <String>[
      if (errorHttpStatus != null) 'HTTP $errorHttpStatus',
      if (errorApiMessage?.trim().isNotEmpty == true) errorApiMessage!.trim(),
    ];
    if (parts.isEmpty) return 'O GitHub não retornou detalhes adicionais.';
    return parts.join(' • ');
  }

  int get recoveryOperationEstimate =>
      changedFiles + resumedFiles + removedFiles;

  bool get canSuggestContentsRecovery =>
      recoveryOperationEstimate == 0 || recoveryOperationEstimate <= 12;

  ProjectUploadMethod? get recommendedRecoveryMethod {
    if (failureStage != 'upload') return null;
    final code = errorCode ?? '';
    final endpoint = (errorEndpoint ?? '').toLowerCase();

    if (code == 'NETWORK_REQUIRED' ||
        code == 'GITHUB_RATE_LIMIT' ||
        (code.startsWith('GITHUB_HTTP_') &&
            errorHttpStatus != null &&
            errorHttpStatus! >= 500)) {
      return uploadMethod;
    }
    if (code == 'UPLOAD_BRANCH_CHANGED' || code == 'GITHUB_CONFLICT') {
      return ProjectUploadMethod.incremental;
    }
    if (endpoint.contains('/git/trees') && code == 'GITHUB_VALIDATION') {
      return switch (uploadMethod) {
        ProjectUploadMethod.incremental => ProjectUploadMethod.fullTree,
        ProjectUploadMethod.fullTree => canSuggestContentsRecovery
            ? ProjectUploadMethod.contentsApi
            : null,
        ProjectUploadMethod.contentsApi => null,
      };
    }
    if (code == 'UPLOAD_CONTENTS_FALLBACK_UNAVAILABLE' ||
        code == 'UPLOAD_CONTENTS_FALLBACK_TOO_LARGE' ||
        code == 'UPLOAD_CONTENTS_FALLBACK_EXECUTABLE') {
      return ProjectUploadMethod.fullTree;
    }
    return null;
  }

  bool get hasAlternativeRecoveryMethod {
    final method = recommendedRecoveryMethod;
    return method != null && method != uploadMethod;
  }

  bool get shouldRetrySameMethod => recommendedRecoveryMethod == uploadMethod;

  String get recoveryRecommendationLabel {
    if (failureStage == 'build' && commitSha?.isNotEmpty == true) {
      return 'Verifique a build novamente usando o commit já enviado. O ZIP não precisa ser reenviado.';
    }
    final method = recommendedRecoveryMethod;
    if (method == null) return 'Nenhum método alternativo foi identificado com segurança.';
    if (method == uploadMethod) {
      return 'A falha parece temporária. A recomendação é repetir ${uploadMethod.label.toLowerCase()}.';
    }
    return 'Próxima tentativa recomendada: ${method.label}.';
  }

  String get failureProgressExplanation {
    if (total <= 0) {
      return 'O envio parou durante “$failureOperationLabel”.';
    }
    final done = current.clamp(0, total);
    if (done >= total) {
      return 'Os $total arquivos do ZIP já tinham sido analisados. A falha aconteceu depois dessa análise, durante “$failureOperationLabel”.';
    }
    return 'O processo chegou a $done de $total arquivos antes de parar durante “$failureOperationLabel”.';
  }

  String? get failureRepositoryImpact {
    if (failureStage == 'build' && commitSha?.isNotEmpty == true) {
      return 'O projeto já foi publicado no repositório no commit ${commitSha!.length > 7 ? commitSha!.substring(0, 7) : commitSha}. Apenas a build ficou pendente; repetir a verificação não reenvia os arquivos.';
    }
    if (errorCode == 'UPLOAD_BRANCH_CHANGED') {
      final operation = (failureOperation ?? '').toLowerCase();
      if (operation.contains('publicar o commit')) {
        return 'O novo commit já pode ter sido criado como objeto Git, mas o GitHub Manager não moveu a branch porque detectou uma alteração concorrente. O conteúdo visível da branch foi preservado.';
      }
      return 'O GitHub Manager detectou que a branch mudou e interrompeu a tentativa antes de publicar sobre o novo estado. Uma nova tentativa refará toda a comparação.';
    }
    if (fallbackCommitCount > 0) {
      return 'O método de arquivos individuais já publicou $fallbackCommitCount commit(s) antes da falha. A branch pode estar parcialmente atualizada; a próxima tentativa deve refazer a comparação antes de continuar.';
    }
    if (uploadMethod == ProjectUploadMethod.contentsApi) {
      return 'O método de arquivos individuais cria um commit por operação. Se a conexão caiu depois de o GitHub aceitar a última chamada, a branch pode ter mudado mesmo sem resposta no aplicativo. A próxima tentativa reconsulta a branch antes de continuar.';
    }
    final endpoint = (errorEndpoint ?? '').toLowerCase();
    if (endpoint.contains('/git/trees')) {
      return 'A nova árvore não foi aceita; nenhum commit novo desta tentativa foi criado e a branch não foi alterada.';
    }
    if (endpoint.contains('/git/commits')) {
      return 'A branch não foi atualizada por esta tentativa, porque a criação do commit falhou.';
    }
    if (endpoint.contains('/git/refs/heads/')) {
      return 'O commit pode ter sido criado, mas a branch não foi movida para ele; os arquivos visíveis na branch permanecem no commit anterior.';
    }
    if (endpoint.contains('/git/blobs')) {
      return 'A falha ocorreu antes da criação do commit; a branch não foi atualizada por esta tentativa.';
    }
    return null;
  }

  String get failureMeaning {
    final code = errorCode ?? '';
    final endpoint = (errorEndpoint ?? '').toLowerCase();

    if (code == 'APK_WORKFLOW_NOT_FOUND') {
      return 'Os arquivos do projeto já chegaram ao repositório, mas não existe um workflow de GitHub Actions que gere APK. O problema está apenas na etapa de build.';
    }
    if (code == 'APK_WORKFLOW_TRIGGER_MISSING') {
      return 'Existe um workflow que parece gerar APK, porém ele não aceita execução por push nem execução manual por workflow_dispatch. O projeto já foi enviado; falta apenas um gatilho válido para a build.';
    }
    if (code == 'APK_WORKFLOW_PUSH_NOT_STARTED') {
      return 'O workflow de APK existe e aceita push, mas nenhuma execução apareceu para este commit dentro da janela de espera. Isso pode acontecer por atraso do GitHub Actions ou por filtros de branch/paths no workflow.';
    }
    if (code == 'APK_WORKFLOW_DISPATCH_UNAVAILABLE') {
      return 'O projeto já foi enviado, mas não foi possível iniciar manualmente um workflow de APK. O repositório não foi perdido e o envio dos arquivos não precisa ser repetido.';
    }
    if (code == 'UPLOAD_BRANCH_CHANGED') {
      return 'A branch mudou enquanto o GitHub Manager preparava ou recuperava o envio. O aplicativo interrompeu a operação para não publicar sobre um estado diferente do que foi comparado.';
    }
    if (code == 'UPLOAD_CONTENTS_FALLBACK_UNAVAILABLE' ||
        code == 'UPLOAD_CONTENTS_FALLBACK_TOO_LARGE' ||
        code == 'UPLOAD_CONTENTS_FALLBACK_EXECUTABLE') {
      return errorMessage ?? 'O método de arquivos individuais não é seguro para este conjunto de alterações.';
    }
    if (code == 'AUTH_REQUIRED' || code == 'GITHUB_TOKEN_INVALID') {
      return 'A autenticação deixou de ser aceita pelo GitHub. O token pode ter expirado, sido revogado ou não estar mais disponível.';
    }
    if (code == 'GITHUB_RATE_LIMIT') {
      return 'O GitHub bloqueou temporariamente novas chamadas porque o limite da API foi atingido.';
    }
    if (code == 'GITHUB_PERMISSION') {
      return 'O GitHub recebeu a solicitação, mas o token não tem permissão suficiente para concluir esta operação.';
    }
    if (code == 'GITHUB_NOT_FOUND') {
      return 'O recurso usado nesta etapa não foi encontrado ou não está visível para o token atual.';
    }
    if (code == 'GITHUB_CONFLICT') {
      return 'O estado do repositório mudou durante o envio e o GitHub recusou continuar com dados que já não correspondem ao estado atual.';
    }
    if (code == 'GITHUB_VALIDATION') {
      if (endpoint.contains('/git/trees')) {
        return 'O GitHub recusou a árvore Git que reunia os arquivos do ZIP e as remoções detectadas. A falha ocorreu ao montar a nova estrutura do repositório, antes de criar o commit.';
      }
      if (endpoint.contains('/git/commits')) {
        return 'O GitHub recusou a criação do novo commit. A árvore já havia sido preparada, mas os dados do commit não passaram pela validação da API.';
      }
      if (endpoint.contains('/git/refs/heads/')) {
        return 'O commit foi preparado, mas o GitHub recusou atualizar a branch para apontar para ele. Proteções, rulesets ou uma mudança concorrente na branch podem causar esse tipo de rejeição.';
      }
      if (endpoint.contains('/git/blobs')) {
        return 'O GitHub recusou um dos conteúdos de arquivo enviados antes da criação da árvore do commit.';
      }
      if (endpoint.contains('/contents')) {
        return 'O GitHub recusou uma alteração de arquivo feita pela API de conteúdo do repositório.';
      }
      return 'O GitHub recebeu os dados, mas recusou a operação porque eles não passaram pelas regras de validação da API.';
    }
    if (code == 'NETWORK_REQUIRED') {
      return 'A comunicação com o GitHub foi interrompida ou não pôde ser estabelecida nesta etapa.';
    }
    if (code.startsWith('GITHUB_HTTP_')) {
      return 'O GitHub respondeu com um status HTTP que o aplicativo não classificou como um dos casos comuns. A resposta e o endpoint abaixo mostram exatamente qual chamada falhou.';
    }
    if (code.startsWith('UPLOAD_')) {
      return errorMessage ?? 'O GitHub Manager não conseguiu concluir esta etapa do envio.';
    }
    return 'O envio parou nesta etapa antes de ser concluído. Os detalhes técnicos abaixo ajudam a identificar a origem exata.';
  }

  String get failureSuggestedAction {
    final code = errorCode ?? '';
    final endpoint = (errorEndpoint ?? '').toLowerCase();

    if (code == 'APK_WORKFLOW_NOT_FOUND') {
      return 'Crie ou restaure um arquivo em .github/workflows que realmente gere APK. Depois use “Verificar build” — não é necessário reenviar o ZIP.';
    }
    if (code == 'APK_WORKFLOW_TRIGGER_MISSING') {
      return 'No workflow de APK, adicione push e/ou workflow_dispatch dentro de on:. Depois toque em “Verificar build” para tentar novamente sem reenviar o projeto.';
    }
    if (code == 'APK_WORKFLOW_PUSH_NOT_STARTED') {
      return 'Toque em “Verificar build” novamente. Se continuar sem execução, abra Builds e confira se o workflow aceita a branch $branch e se existem filtros paths/paths-ignore impedindo este commit.';
    }
    if (code == 'APK_WORKFLOW_DISPATCH_UNAVAILABLE') {
      return 'Adicione workflow_dispatch ao workflow de APK ou habilite um gatilho push compatível com a branch $branch. Depois verifique a build novamente.';
    }
    if (code == 'UPLOAD_BRANCH_CHANGED') {
      return 'Tente novamente pelo método incremental. O projeto será comparado de novo com o SHA atual da branch antes de qualquer publicação.';
    }
    if (code == 'UPLOAD_CONTENTS_FALLBACK_UNAVAILABLE' ||
        code == 'UPLOAD_CONTENTS_FALLBACK_TOO_LARGE' ||
        code == 'UPLOAD_CONTENTS_FALLBACK_EXECUTABLE') {
      return 'Use a reconstrução da árvore ou corrija a causa indicada. O GitHub Manager não fará atualização individual quando houver risco de perder modo executável, exceder o limite seguro ou gerar alterações demais.';
    }
    if (code == 'AUTH_REQUIRED' || code == 'GITHUB_TOKEN_INVALID') {
      return 'Reconecte a conta ou gere um token válido e tente novamente.';
    }
    if (code == 'GITHUB_RATE_LIMIT') {
      return 'Aguarde o limite da API liberar e tente novamente depois.';
    }
    if (code == 'GITHUB_PERMISSION') {
      return 'Abra o Diagnóstico do token e confirme principalmente a permissão Contents: write para este repositório.';
    }
    if (code == 'GITHUB_NOT_FOUND') {
      return 'Confirme o repositório, a branch e se o token possui acesso a esse repositório.';
    }
    if (code == 'GITHUB_CONFLICT') {
      return 'Atualize os dados do repositório e tente novamente para refazer a sincronização sobre o estado atual.';
    }
    if (code == 'GITHUB_VALIDATION') {
      if (endpoint.contains('/git/refs/heads/')) {
        return 'Confira as regras/proteções da branch e tente novamente. Se a branch mudou durante o envio, uma nova tentativa refaz a comparação.';
      }
      if (endpoint.contains('/git/trees')) {
        if (uploadMethod == ProjectUploadMethod.incremental) {
          return 'O método incremental foi recusado. Use “Tentar método alternativo” para reconstruir a árvore final do projeto sem reaproveitar a árvore anterior.';
        }
        if (uploadMethod == ProjectUploadMethod.fullTree) {
          if (!canSuggestContentsRecovery) {
            return 'A reconstrução completa também foi recusada. O método individual não é recomendado porque foram detectadas cerca de $recoveryOperationEstimate alterações, acima do limite seguro de 12 operações. Copie o diagnóstico para investigar a validação retornada pelo GitHub.';
          }
          return 'A reconstrução completa também foi recusada. O conjunto de mudanças é pequeno o suficiente para oferecer, manualmente, a API de arquivos individuais; o método ainda fará validações de tamanho, modo executável e tipo Git antes de alterar a branch.';
        }
        return 'O método individual também falhou. Copie o diagnóstico antes de repetir para evitar uma sequência de commits parciais.';
      }
      return 'Tente novamente uma vez. Se a rejeição se repetir, copie o diagnóstico completo para identificar a validação exata retornada pelo GitHub.';
    }
    if (code == 'NETWORK_REQUIRED') {
      return 'Verifique a conexão e tente novamente. O checkpoint evita reenviar o que já foi concluído quando possível.';
    }
    if (code.startsWith('GITHUB_HTTP_')) {
      if (errorHttpStatus != null && errorHttpStatus! >= 500) {
        return 'Tente novamente depois de alguns instantes. Se continuar, copie o diagnóstico para conferir a resposta do serviço do GitHub.';
      }
      return 'Confira a resposta do GitHub e o endpoint nos detalhes técnicos. Se repetir, copie o diagnóstico antes de tentar novamente.';
    }
    return 'Tente novamente. Se a falha persistir, use “Copiar diagnóstico” para registrar a etapa, o código e a resposta recebida.';
  }

  bool get canShowBuildTriggerFix =>
      errorCode == 'APK_WORKFLOW_NOT_FOUND' ||
      errorCode == 'APK_WORKFLOW_TRIGGER_MISSING' ||
      errorCode == 'APK_WORKFLOW_DISPATCH_UNAVAILABLE';

  String get buildTriggerFixSnippet => '''on:
  push:
    branches: [$branch]
  workflow_dispatch:''';

  String get failureDiagnosticText {
    final lines = <String>[
      'DIAGNÓSTICO DA FALHA',
      'Onde parou: $failureOperationLabel',
      'Método usado: ${uploadMethod.label}',
      'Progresso: $failureProgressExplanation',
      'Recomendação: $recoveryRecommendationLabel',
      if (failureRepositoryImpact != null) 'Impacto: $failureRepositoryImpact',
      if (failureStage?.isNotEmpty == true) 'Etapa interna: $failureStage',
      if (failedFilePath?.isNotEmpty == true) 'Arquivo: $failedFilePath',
      if (errorCode?.isNotEmpty == true) 'Código: $errorCode',
      if (errorHttpStatus != null) 'HTTP: $errorHttpStatus',
      if (errorEndpoint?.isNotEmpty == true) 'Endpoint: $errorEndpoint',
      if (errorApiMessage?.isNotEmpty == true) 'GitHub: $errorApiMessage',
      if (errorMessage?.isNotEmpty == true) 'Mensagem do app: $errorMessage',
      if (recoveryEvents.isNotEmpty) ...[
        '',
        'Tentativas de recuperação:',
        ...recoveryEvents.map((event) => '• $event'),
      ],
      '',
      'O que significa:',
      failureMeaning,
      '',
      'O que fazer:',
      failureSuggestedAction,
    ];
    return lines.join('\n');
  }
}
