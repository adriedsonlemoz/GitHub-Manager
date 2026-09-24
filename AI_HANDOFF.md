# GitHub Manager — handoff

Estado atual: `2.0.79+200093`. Dados remotos do GitHub não usam mais cache persistente: repositórios, descrições, perfil e permissões são consultados diretamente; Acompanhados salva apenas os nomes escolhidos e reconsulta a API; snapshots legados são apagados no startup. Providers remotos usam autoDispose.

## Arquitetura

Flutter/Dart Android local-first, sem backend obrigatório. GitHub é acessado diretamente pelo aparelho.

## Identidade definitiva

- repositório oficial: `adriedsonlemoz/GitHub-Manager`;
- applicationId: `br.com.githubmanager.app`
- assinatura própria e permanente com alias `github_manager_release`;
- Secrets: `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`;
- certificado público pinado em `android/release-signing.properties`;
- Android APK e Android Release usam a mesma assinatura.

## Recursos principais

- notificações de conclusão/falha de builds em segundo plano;
- repositórios acompanhados em modo somente leitura, com Releases/APKs públicos e seleção de repositório ao colar URL de perfil;
- lista e CRUD de repositórios;
- projetos fixados localmente, filtro de fixados e ordenação por data/nome/tamanho;
- cards usam resumo leve de nome/versão; análise completa permanece nas telas internas;
- metadados de projeto, versão e tecnologias;
- navegação/edição/upload de arquivos;
- ZIP com sincronização completa e remoção de arquivos obsoletos, preservando `.github/workflows/**` quando o pacote apenas omite esses arquivos;
- recuperação inteligente de envio: retry transitório, fallback incremental → árvore completa, proteção por SHA da branch e fallback manual seguro por Contents API;
- Actions: executar, acompanhar, cancelar, reexecutar, jobs/etapas/logs, atualização automática adaptativa e diagnóstico de falhas com contexto extraído do log;
- Builds agrupadas por commit/envio, com horário até segundos e número da tentativa;
- Enviar build sincroniza o ZIP e garante o disparo do Android APK sem duplicar runs; commit publicado com build não iniciada vira estado **Build pendente** e pode ser rechecado sem reenviar o ZIP;
- Central de Envios permite minimizar a sincronização, navegar no app, acompanhar fila/histórico e repetir interrupções;
- relatório de envio separa resumo, arquivos alterados, GitHub/build e linha do tempo, evitando logs repetitivos por arquivo;
- falhas de envio preservam operação exata, progresso, HTTP, endpoint e resposta detalhada da API, com interpretação/ação sugerida e impacto seguro no repositório;
- upload reutiliza blobs cujo SHA Git já corresponde ao conteúdo do ZIP e serializa envios para reduzir chamadas mutativas concorrentes;
- artifacts/APK com Releases exibidas diretamente em cards, identificação explícita Release/Artifact, busca e filtros;
- Commits;
- Bugs via GitHub Issues sem reformulação adicional;
- GitHub Secrets com sealed box, PAT fine-grained/clássico, validação 48 KB/100, importação TXT/ENV/JSON/XML e diagnóstico por Secret;
- diagnóstico não destrutivo do token por repositório, com leitura real, escopos clássicos, `X-Accepted-GitHub-Permissions` e permissões necessárias para escrita;
- configurações, edição de perfil GitHub por popup responsivo, Groq/API opcional e tema;
- Central de Downloads com serviço Android em primeiro plano, retomada parcial por HTTP Range e publicação na pasta pública Downloads;
- download do projeto em ZIP;
- instalação de APK iniciada pelo usuário via FileProvider/instalador Android.






## Refatoração e ciclo de vida de APKs/builds 2.0.70

- telas grandes foram divididas conservadoramente em arquivos de apresentação e actions/controllers: Configurações, Detalhe do repositório, Builds/Detalhe da build e APKs/Releases;
- exclusão de build usa `BuildCleanupService`: apaga o workflow run, verifica artifacts remanescentes pelo `workflowRunId` e limpa APKs de Release somente quando o mesmo commit pode ser comprovado;
- `ActionArtifact` preserva `workflow_run.id` e `workflow_run.head_sha`; `ReleaseAsset` preserva release/tag/`target_commitish` para correlação segura;
- `ArtifactService.listArtifactsForRun` consulta os artifacts do run antes da exclusão; `listReleaseAssets` pagina até 5 páginas de 100 Releases;
- Release asset é recurso independente: a tela APKs/Releases agora permite excluí-lo diretamente sem remover Release/tag;
- `Excluir APKs anteriores` trata separadamente Actions artifacts e Release assets, preservando o APK mais recente de cada origem;
- ao publicar Release a partir de artifact, usar `artifact.workflowRunHeadSha` como `target_commitish` quando disponível; a branch é apenas fallback para artifacts antigos;
- providers de artifacts/Releases são `autoDispose` e são invalidados após operações destrutivas;
- testes relevantes: `build_cleanup_service_test.dart`, `build_artifact_linkage_test.dart`, `build_release_linkage_test.dart` e `older_apk_cleanup_test.dart`.

## Correção do build 2.0.69

- `UploadProgressDialog` e `_FailureDiagnostic` passam a usar um helper privado de arquivo para abreviar SHA;
- corrige o erro de compilação `The method '_shortSha' isn't defined for the type 'UploadProgressDialog'`;
- nenhum comportamento do fluxo de upload/build pendente foi removido;
- Android APK agora roda `flutter analyze` e `flutter test` antes do Gradle para falhar cedo em erros Dart.

## Proteção de workflows e build pendente 2.0.68

- `.github/workflows/**` é infraestrutura protegida durante a sincronização: ausência no ZIP não gera remoção; inclusão do mesmo caminho continua permitindo atualização intencional;
- a confirmação do ZIP avisa explicitamente que workflows existentes serão preservados;
- `ensureBuildForCommit` inspeciona estruturalmente YAMLs e diferencia `APK_WORKFLOW_NOT_FOUND`, `APK_WORKFLOW_TRIGGER_MISSING` e `APK_WORKFLOW_PUSH_NOT_STARTED`;
- workflow de APK com `push` recebe uma janela adicional de polling para absorver atraso de indexação do Actions;
- após commit válido, falha de descoberta/disparo da build usa `ManagedUploadStatus.buildPending`, preserva o SHA e retry executa somente `_runBuild`;
- o diálogo de progresso é rolável, resume o problema e recolhe diagnóstico técnico; build pendente oferece **Abrir Builds**, **Verificar build**, exemplo de gatilho copiável e deixa claro que o ZIP já foi enviado;
- nunca voltar a classificar falha de Actions como falha de upload quando `commitSha` válido já foi publicado.

## Persistência e recuperação 2.0.67

- SQLite usa `schemaVersion = 2`, com `CREATE TABLE/INDEX IF NOT EXISTS` em criação, upgrade e abertura;
- instalações antigas com banco incompleto são migradas sem exigir limpar dados do Android;
- cada `LocalDatabase` abre conexão própria (`singleInstance: false`), evitando que serviços auxiliares fechem a conexão usada pela UI;
- reconciliação de projetos fixados é auxiliar e não pode derrubar a lista remota de repositórios;
- JSON local inválido é removido somente na chave afetada;
- Configurações > Diagnóstico de dados locais pode reparar o esquema ou reconstruir apenas o SQLite, preservando o PAT no `flutter_secure_storage`.

## Conferência, ajuda e token 2.0.66

- build 57 corrigido: o detalhe do repositório resolve o estado de fixado antes de abrir o menu e passa `isFavorite`;
- análise local de ZIP Node/JavaScript lê versão/nome do `package.json` da raiz ou da única pasta-raiz;
- `Conferir build` mostra a versão do projeto a enviar, não a versão instalada do GitHub Manager;
- avisos de identidade/versão têm ajuda contextual com fontes aceitas e passos para corrigir;
- Configurações possui central de ajuda geral e acesso direto para exibir/copiar o token GitHub atual;
- token continua apenas em `flutter_secure_storage` e nunca deve aparecer em logs/diagnósticos.

## APKs e segurança de envio 2.0.31

- cards de APK/artifact compactos, com três ações lado a lado e badges de formato/build/estabilidade/versão;
- classificação por nome diferencia Debug, Profile, Release, prévia e AAB/Google Play, sem afirmar certeza quando a API não fornece buildType;
- versão anterior não bloqueia mais envio: regressão fica disponível com aviso;
- nome do projeto/repositório é apenas pista e nunca bloqueia sozinho;
- uma divergência forte (`applicationId` ou pacote) vira aviso; duas divergências fortes simultâneas ativam risco alto;
- risco alto ainda pode ser forçado com uma segunda confirmação explícita mostrando o destino.

## UI e identidade de projeto 2.0.30

- novo padrão visual azul-preto/índigo aplicado no tema compartilhado, cards de repositório, busca, filtros e navegação inferior;
- componentes globais de cards, campos, botões, diálogos e navegação levam a mesma identidade às demais telas sem arquitetura paralela;
- comparação de projeto normaliza diacríticos, evitando falso bloqueio entre nomes equivalentes como `Tática Manager` e `TaticaManager`;
- identidade Android do repositório tenta ler `android/app/build.gradle.kts` e `android/app/build.gradle` quando os metadados não trazem `applicationId`;
- divergência real de `applicationId` continua sendo bloqueio forte.

## Hotfix 2.0.29

- corrigida compilação do importador de Secrets com `file_picker 12`, usando `PlatformFile.length()` em vez do getter removido `size`;
- CI normaliza a formatação no runner e avisa sobre diferenças sem interromper o pipeline somente por formatação;
- `flutter analyze` e `flutter test` continuam sendo gates reais da CI.

## Pré-checagem de permissões 2.0.28

- `Enviar build` consulta Contents/Workflows e Actions antes de abrir o seletor de ZIP;
- criar, substituir, importar e excluir Secrets consultam a capacidade de escrita de Secrets;
- exclusão permanente de repositório consulta a capacidade de exclusão antes da confirmação destrutiva;
- negação confirmada bloqueia antecipadamente e mostra a permissão faltante com atalho para o diagnóstico;
- resultado `unknown` de PAT fine-grained não bloqueia, evitando falso negativo;
- cache de 3 minutos usa fingerprint SHA-256 do token apenas em memória, portanto troca de token não reaproveita resultado antigo;
- rate limit/indisponibilidade do diagnóstico não são convertidos em falta de permissão.

## Diagnóstico do token 2.0.27

- disponível em cada repositório próprio;
- executa somente GETs e nunca altera dados para testar permissões;
- confirma leitura de Contents, Actions, Secrets e Administration;
- PAT clássico: cruza `X-OAuth-Scopes` com o papel da conta e identifica `repo`, `workflow` e `delete_repo`;
- PAT fine-grained: mostra a permissão exata necessária para escrita sem fingir que é possível introspectar o que o GitHub não expõe;
- usa `X-Accepted-GitHub-Permissions` em falhas de leitura quando disponível;
- relatório copiável não inclui token;
- testes dedicados cobrem token clássico, fine-grained, permissão ausente e papel não administrativo.

## Secrets 2.0.26

- aceita tokens fine-grained e clássicos sem restringir prefixo na validação de `/user`;
- assistente explica `Secrets: Read and write` para fine-grained e `repo` para clássico;
- parser TXT/ENV aceita `=`, `:` e `export`, detectando duplicidades após normalização;
- pré-valida 48 KB por valor e 100 Secrets finais por repositório;
- importação em lote continua após falha individual e gera relatório sanitizado copiável;
- erros HTTP preservam status, endpoint e mensagem da API sem registrar valores;
- testes dedicados cobrem parser, limites, lote parcial, criptografia e exclusão.

## Segurança

Nunca incluir keystore, `.env`, tokens ou key.properties no ZIP/repositório.

## ZIP idêntico

Se um ZIP gerar a mesma árvore Git já publicada, não criar commit nem build automática. Informar `Projeto já está atualizado` e permitir `Executar build mesmo assim` via `workflow_dispatch`.

## UI e Sobre 2.0.25

- não existe mais banner vermelho global de versão de teste;
- a confirmação de envio do ZIP mostra um card vermelho/branco com a versão instalada;
- avatar da Home abre edição de perfil GitHub em diálogo responsivo;
- gerenciamento do repositório usa engrenagem e diálogo centralizado;
- Sobre mostra as três mudanças mais recentes em ExpansionTile, Pix, feedback, desenvolvedor e aviso de independência do GitHub;
- Groq é opcional e atualmente não é consumido automaticamente por nenhuma função principal.


## Ciclo de vida SQLite 2.0.71

- `LocalDatabase` possui construtor privado e expõe somente `LocalDatabase.shared`; não reintroduzir `LocalDatabase()` em serviços.
- `shared` é por isolate: UI e providers usam uma conexão durante toda a sessão; WorkManager possui outra instância estática no isolate de background.
- `singleInstance: true` voltou a ser seguro porque não existem mais serviços curtos fechando handles compartilhados.
- `_opening` deduplica aberturas concorrentes do mesmo isolate.
- `localDatabaseProvider` não fecha a conexão em `ref.onDispose`; startup, `BuildMonitorService` e `UploadRecoverySettings` também não fecham o banco após cada operação.
- `rebuildLocalDatabase()` é o único fluxo autorizado a fechar internamente a conexão antes de excluir e reabrir o banco.
- manter `schemaVersion = 2` enquanto não houver alteração real de schema; `_ensureSchema` continua idempotente para instalações antigas.

## Refatoração ManagedUpload 2.0.72

- `lib/features/uploads/domain/managed_upload.dart` agora é o contrato principal e caiu de 983 para cerca de 235 linhas.
- Não alterar a API pública sem revisar `UploadManagerService`, UI da Central de Envios e testes de persistência.
- `managed_upload_state.dart`: getters derivados, labels, progresso e conversão para `ZipProjectPreview`.
- `managed_upload_failure.dart`: classificação de falhas, impacto no repositório, recuperação recomendada e instruções ao usuário.
- `managed_upload_lifecycle.dart`: contadores, logs, interrupção, retomada e retry.
- `managed_upload_report.dart`: linha do tempo amigável e relatório técnico copiável.
- `managed_upload_codec.dart`: persistência JSON; manter compatibilidade retroativa das 51 chaves existentes.
- `managed_upload_refactor_contract_test.dart` é o teste de proteção da divisão e deve evoluir quando um novo campo persistido for adicionado.

## Correção dos logs 63 — 2.0.73

- Android APK 63 e Verificação CI 63 falhavam no `flutter analyze` antes dos testes/Gradle.
- causa: `leftover` era declarado como `final` apontando para um objeto `const`, mas era reutilizado dentro de listas literais `const`; a variável em si não era uma constante de tempo de compilação;
- correção: `const leftover = ActionArtifact(...)`;
- nenhuma lógica de `BuildCleanupService` foi alterada;
- manter o teste de exclusão de artifact remanescente para prevenir regressões no vínculo Build → Artifact/APK.

## Branch de envio, Builds globais e projetos sem workflow — 2.0.74

- O envio permite escolher a branch e persiste localmente a última branch usada por repositório.
- `RepositoryProjectInfoService.load(..., branch:)` compara os metadados contra a branch escolhida.
- A navegação principal agora é Projetos / Builds / Downloads / Perfil / Opções; Acompanhados fica dentro de Projetos.
- `GlobalBuildsService` reúne até cinco runs recentes por repositório em lotes, sem enriquecimento de versão para evitar chamadas extras.
- `APK_WORKFLOW_NOT_FOUND` deixa de ser falha de build na Central de Envios: o item termina como concluído sem workflow.
- O preflight `syncProject` exige Contents, enquanto `sendBuild` continua exigindo Contents + Actions para operações explicitamente ligadas ao Actions.
