# GitHub Manager 2.0.1 (200015)

## Escopo

Esta versão concentra as alterações em GitHub Actions, builds, artifacts/APKs e Central de Downloads. A aba Bugs não foi alterada.

## Correções principais

### GitHub Actions / Builds

- A fonte principal de execuções passou a ser `GET /repos/{owner}/{repo}/actions/runs`.
- Cada run preserva `workflow_id`, `path`, branch, SHA, commit, número, tentativa, datas, status e conclusão.
- Ao selecionar um workflow, a filtragem é feita localmente por `workflow_id` e, como segurança adicional, pelo path normalizado.
- Se a fonte geral tiver runs mas o filtro não encontrar correspondência, o app tenta o endpoint específico do workflow por ID e por nome de arquivo como fallback de diagnóstico.
- A interface distingue API realmente vazia, filtro sem correspondência, erro e resposta inesperada.
- Foi adicionada uma visão de diagnóstico sem token/Authorization.
- Execuções em andamento atualizam automaticamente.
- Jobs e steps recebem descrições simples; falhas destacam job, step e a primeira annotation de falha disponível.

### Downloads

- APK, ZIP do projeto, logs e artifacts usam a mesma Central de Downloads.
- O progresso mostra bytes, total, porcentagem, velocidade estimada e tempo restante.
- Downloads podem ser cancelados e tentados novamente.
- O histórico separa Baixando, Concluídos e Falharam.
- Remover do histórico não apaga o arquivo; Excluir arquivo remove também o arquivo publicado em Downloads.
- Erros mantêm código interno, endpoint seguro, HTTP, etapa, bytes e mensagem sanitizada.
- Token, Secrets, API Keys, senhas, Authorization e URLs temporárias assinadas não são persistidos no log.
- APK concluído pode abrir diretamente o instalador oficial do Android.
- Foi adicionado compartilhamento de arquivos pelo Android.

### Artifacts/APKs

Foi corrigido um erro real do formato atual do GitHub Actions. Com `actions/upload-artifact@v7` e `archive: false`, um APK pode ser entregue diretamente pelo download do artifact. O código anterior tratava sempre o conteúdo recebido como um ZIP externo e procurava outro `.apk` dentro dele.

O novo fluxo reconhece:

1. artifact ZIP que contém um ou mais APKs; e
2. APK direto (arquivo ZIP no formato Android, contendo `AndroidManifest.xml`, `classes.dex`/`resources.arsc`).

Artifacts expirados permanecem visíveis no histórico com indicação de expiração, em vez de simplesmente desaparecerem da listagem.

### Workflows e identidade

- Novos APKs usam `GitHub-Manager-<versionName>-<versionCode>-universal-release.apk`.
- O workflow Android Release renomeia o APK real antes do upload, importante porque `archive: false` usa o nome do arquivo enviado.
- O workflow também valida a existência de `apkanalyzer` e `apksigner` antes da verificação final.
- Identidade atual: `github_manager` / `br.com.githubmanager.app` / GitHub Manager.

### Importação de ZIP

A sincronização completa existente foi preservada. O serviço continua comparando a árvore atual do GitHub com os caminhos presentes no ZIP e inclui entradas com `sha: null` para remover arquivos obsoletos no mesmo commit de sincronização.

## Validação realizada nesta entrega

- YAML dos três workflows: parse estrutural aprovado.
- `github-manager.json`: JSON válido.
- `AndroidManifest.xml`: XML válido.
- scripts shell de versão/bootstrap: sintaxe aprovada.
- sincronização de versão: `2.0.1+200015` aprovada.
- namespace/applicationId: `br.com.githubmanager.app`.
- busca por identidade antiga no projeto atual: nenhuma ocorrência encontrada.
- busca por arquivos de chave/keystore e tokens literais no código: nenhuma credencial incluída.
- artifact real disponível no repositório: estrutura confirmada como APK direto, sem APK aninhado.

## Limitações de validação

O ambiente usado para preparar este ZIP não possui Flutter/Dart instalados. Por isso `flutter analyze`, `flutter test` e uma nova compilação do código desta versão não puderam ser executados localmente e **não são declarados como aprovados** nesta entrega.

Correção documental posterior: a validação remota usada durante a preparação desta versão foi feita no repositório anterior e não deve ser tratada como validação do repositório oficial `adriedsonlemoz/GitHub-Manager`. No repositório oficial, o primeiro commit de importação contendo os workflows não gerou check-runs. A versão 2.0.2 passou a verificar o disparo pelo SHA do commit e usar `workflow_dispatch` como fallback.

Também não existe atualmente um artifact expirado no repositório para reproduzir de forma real a resposta de expiração. O tratamento de 404/410 e do campo `expired` foi implementado, mas essa condição específica não foi marcada como teste real concluído.

A opção pausar/continuar download não foi adicionada nesta versão para evitar introduzir estado parcial/range requests e complexidade desnecessária. Cancelar e tentar novamente estão disponíveis.
