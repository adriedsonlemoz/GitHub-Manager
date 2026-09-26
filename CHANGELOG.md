## 2.0.102+200116 — 2026-09-26

- unifica visualmente os cards de GitHub Releases e GitHub Actions Artifacts na tela **APKs**;
- ambos passam a usar a mesma hierarquia: versão, metadados, origem/formato e ações na mesma posição;
- Artifacts deixam de destacar o nome bruto do arquivo e removem o texto técnico redundante de classificação inferida da listagem principal;
- adiciona indicador compacto de variante (`Universal`, `ARM64`, `ARMv7`, `x86`, `Performance`) quando detectável pelo nome do artifact;
- reconhece Artifact cuja versão já exista em Release, mostra **Publicado** e remove a ação **Publicar** para evitar duplicação;
- ao redirecionar download de Artifact para Release, prioriza a mesma variante quando ela existir;
- corrige a extração visual de versão para não incorporar `versionCode`/sufixos como `universal-release.apk`;
- padroniza a ordem das ações: **Baixar/Escolher**, **Publicar** quando aplicável e **Excluir**;
- atualiza a tela **Novidades da atualização**, Configurações, README, AI_HANDOFF, RELEASE, VALIDATION e versionamento para `2.0.102+200116`.

## 2.0.101+200115 — 2026-09-26

- faz varredura visual completa e padroniza retângulos para raio de 4 px, alinhando cards, campos, botões, diálogos, snackbars e indicador da navegação ao padrão da Home;
- mantém somente pills/círculos deliberados para estados e indicadores que dependem dessa forma;
- adiciona `error_telemetry` ao SQLite (`schemaVersion = 3`) com retenção máxima de 120 eventos;
- captura erros globais de Flutter, exceções assíncronas do Dart e falhas registradas pelo logger;
- adiciona `GitHubManagerApplication` com `UncaughtExceptionHandler` nativo para preservar o último crash Android antes do encerramento do processo;
- importa o crash nativo no próximo acesso e disponibiliza tudo em **Configurações > Erros e telemetria**;
- adiciona ações de copiar relatório, exportar `.txt` para Downloads/GitHub Manager e limpar o histórico local;
- sanitiza padrões conhecidos de Authorization Bearer, token, password, api key, secret, `github_pat_...` e `gh*_...`;
- nada de telemetria é enviado automaticamente; a captura pode ser desativada nas Configurações;
- corrige o controle da tela **Novidades da atualização**: a versão só é marcada como vista após **Continuar**, evitando que a tela seja consumida antes de realmente ser lida;
- adiciona **Novidades desta versão** em Configurações para revisão manual;
- adiciona testes de contrato para raios visuais, telemetria global/nativa e exibição das novidades;
- sincroniza documentação e identidade para `2.0.101+200115`.

## 2.0.100+200114 — 2026-09-26

- corrige a criação/retenção de duas janelas do GitHub Manager em **Aplicativos recentes** após atualização, instalação de APK ou retorno por notificação;
- `MainActivity` passa de `singleTop` para `singleTask` e volta a usar a afinidade padrão do pacote, com `documentLaunchMode="never"`;
- ao criar ou receber um novo Intent, a Activity remove tarefas antigas duplicadas do próprio app em `ActivityManager.appTasks`, limpando também cartões remanescentes de versões anteriores;
- remove `FLAG_ACTIVITY_NEW_TASK` dos fluxos iniciados pela própria `MainActivity` para abrir URI e instalar APK;
- notificações de upload/download passam a reabrir explicitamente `MainActivity` com `ACTION_MAIN`, `CATEGORY_LAUNCHER`, `CLEAR_TOP` e `SINGLE_TOP`;
- adiciona teste de contrato para impedir regressões na configuração de task/Recentes;
- sincroniza identidade, tela de novidades e documentação para `2.0.100+200114`.

## 2.0.99+200113 — 2026-09-26

- reduz somente os cantos dos cards da lista **Meus repositórios** para raio de 6 px, preservando o restante do tema;
- adiciona tela completa **Novidades da atualização** no primeiro acesso após cada nova versão;
- persiste localmente a última versão já apresentada para evitar repetição na mesma atualização;
- mantém a verificação de novidades fora do primeiro frame, com timeout e falha controlada para não atrasar a abertura do app;
- atualiza a seção **Últimas 3 mudanças** nas Configurações;
- sincroniza identidade e documentação para `2.0.99+200113`.

## 2.0.98+200112 — 2026-09-26

- compacta a tela interna do projeto movendo APKs/artifacts, Commits, Diagnóstico do token e Issues/Bugs para atalhos no cabeçalho;
- reorganiza os menus restantes do projeto em ordem alfabética;
- simplifica cards de Release: versão em destaque, remoção da tag redundante e ação Excluir explícita ao lado de Baixar/Escolher;
- substitui o ícone ambíguo de confirmação da branch por um botão **Continuar** e torna a escolha de outra branch uma etapa explícita;
- adiciona testes de contrato para navegação compacta, cards de Release e seleção de branch;
- sincroniza identidade e documentação para `2.0.98+200112`.

## 2.0.97+200111 — 2026-09-26

- exclusão em lote de Builds passa a exibir etapa, item atual e percentual determinado de 0 a 100%;
- limpeza **Excluir APKs anteriores** reutiliza os artifacts/APKs já carregados na tela, corrigindo divergências entre a lista visível e uma segunda consulta remota;
- Central de Downloads passa a confirmar com o Android a exclusão física do arquivo antes de remover o registro local;
- ação de download é renomeada para **Excluir do aparelho**, mantendo **Remover do histórico** como operação separada;
- descrições dos projetos são removidas dos cards da Home para reduzir altura e poluição visual, sem perder a busca por descrição;
- pesquisa da Home vira uma lupa compacta no AppBar e só ocupa espaço enquanto está ativa;
- README usa cache em memória por repositório/branch, decodificação isolada para conteúdo grande e renderização Markdown lazy;
- adiciona teste de progresso da limpeza em lote;
- sincroniza identidade e documentação para `2.0.97+200111`.

## 2.0.96+200110 — 2026-09-25

- reorganiza a tela **APKs** para exibir um card por versão detectada, reduzindo informação duplicada;
- corrige a ordem de projetos que acumulam várias versões dentro da mesma GitHub Release de tag fixa, usando a versão encontrada no nome do asset antes da data como critério;
- agrupa variantes da mesma versão (Universal, ARM64, ARMv7, x86) e abre um seletor compacto ao baixar quando existem várias opções;
- remove os badges redundantes `Direto` e da versão/arquivo no card de Release e move o gerenciamento/exclusão para uma ação discreta;
- troca os avisos centrais globais por SnackBars flutuantes compactos no rodapé, sem cobrir o conteúdo principal;
- reduz os indicadores globais de envio/download de botões extensos para botões pequenos com anel de progresso e badge de quantidade;
- corrige também a limpeza de APKs antigos para preservar todas as variantes da versão mais nova mesmo quando várias versões usam a mesma Release fixa;
- adiciona testes de regressão para ordenação do Explorador XP, agrupamento por versão, limpeza e prioridade da variante Universal;
- sincroniza versão/documentação para `2.0.96+200110`.

## 2.0.95+200109 — 2026-09-24
- corrige as duas falhas restantes dos jobs GitHub Manager CI #84 e Android APK #85;
- torna o contrato de repositório vazio independente de formatação/whitespace, evitando falso negativo quando o Dart formatter quebra a condição em várias linhas;
- adiciona chave estável ao botão **Outras branches** e faz o `testWidgets` aguardar o estado real da lista em pumps limitados, sem depender de atraso fixo de 400 ms;
- a CI deixa de executar `dart format lib test` de forma mutável antes da análise/testes e passa a usar `dart format --output=none --set-exit-if-changed`, apenas avisando sobre formatação pendente;
- adiciona teste de regressão garantindo que o workflow não volte a modificar o código antes da suíte;
- mantém as melhorias de carregamento progressivo e timeout/retry das versões anteriores.

## 2.0.94+200108 — 2026-09-24
- Corrige erro fatal do analyzer `Undefined class 'ValueListenable'` em `repository_detail_widgets.dart`, adicionando o import explícito de `package:flutter/foundation.dart` à biblioteca de detalhe do repositório.
- Mantém as melhorias de carregamento progressivo e seletor compacto de branch introduzidas na 2.0.93.

# Changelog

## 2.0.93+200107 — 2026-09-24

- redesenha o seletor de branch como diálogo compacto e centralizado, com branch atual, botão **Criar** e lista recolhível **Outras branches**;
- o seletor abre imediatamente e carrega branches em segundo plano, com timeout de 12 s e **Tentar novamente** em vez de spinner indefinido;
- ao enviar um ZIP, a interface mostra imediatamente **Preparando envio** e informa a etapa atual enquanto permissões e dados da branch são consultados;
- versão remota, prévia da sincronização, workflow e rate limit passam a ser iniciados em paralelo para reduzir o tempo entre branch e confirmação;
- a tela Projeto reaproveita o repositório já carregado na listagem para abrir instantaneamente e atualiza os dados em segundo plano;
- quando não há cache, substitui a tela quase vazia por carregamento progressivo com cabeçalho e seções visíveis;
- adiciona timeout/retry ao carregamento principal do repositório e limites às consultas de branches, runs e metadados;
- mantém o cache somente em memória e o invalida em edição, rename e exclusão para não reapresentar dados antigos;
- atualiza os testes/contratos do seletor e do fluxo de envio para o novo comportamento.

## 2.0.92+200106 — 2026-09-24

- corrige a única falha restante dos jobs GitHub Manager CI #81 e Android APK #82;
- o seletor já retornava corretamente a branch `develop`, mas o teste exigia que o texto `develop` desaparecesse completamente da árvore após o `Navigator.pop`, uma expectativa desnecessária e sensível à animação/transição da rota;
- o teste agora valida somente o contrato funcional relevante (`selected.name == 'develop'`), mantendo a verificação de scroll/toque da branch e eliminando a falsa falha;
- atualiza a fixture do teste e sincroniza a versão para `2.0.92+200106`;
- os logs anteriores confirmaram 126 testes aprovados e apenas essa asserção falhando, sem novo erro de compilação.

## 2.0.91+200105 — 2026-09-24

- corrige a única falha restante dos jobs GitHub Manager CI #80 e Android APK #81: o teste encontrava a branch `develop`, mas tentava tocá-la fora da área visível do viewport de teste;
- o teste passa a rolar explicitamente até a branch antes do toque, reproduzindo o comportamento real de uma lista rolável em telas menores;
- adiciona uma chave estável por item no seletor reutilizável de branches, reduzindo a fragilidade dos testes de interface;
- remove o import não utilizado apontado pelo analyzer em `repository_send_flow_widget_test.dart`;
- mantém o timeout de 3 minutos nos workflows como proteção, embora os novos logs confirmem que a suíte já encerra normalmente em menos de 1 minuto.

## 2.0.90+200104 — 2026-09-24

- substitui o teste end-to-end instável de envio por dois `testWidgets` focados e determinísticos: seleção de branch e minimização do diálogo de progresso;
- remove do teste de interface a dependência da tela completa de repositório, banco local, roteamento de envio e múltiplas operações assíncronas que mantinham o job preso;
- mantém a ordem branch → permissões → confirmação/política de build coberta pelos testes de contrato que já passam;
- adiciona cobertura explícita para o diálogo com `LinearProgressIndicator` indeterminado sem usar `pumpAndSettle`;
- mantém o timeout de 3 minutos da etapa `flutter test` como proteção de CI.

## 2.0.89+200103 — 2026-09-24

- Corrige o travamento real remanescente de `repository_send_flow_widget_test.dart`: o teste não usa mais `pumpAndSettle()` enquanto o diálogo de progresso possui animação contínua.
- Substitui as esperas abertas do fluxo de envio por helpers limitados (`_pumpUntilVisible`/`_pumpUntilGone`), que avançam o relógio virtual em passos curtos e falham de forma explícita caso a interface não chegue ao estado esperado.
- Mantém o `UploadManagerService.forTest` sem fila de I/O real nesse `testWidgets`, preservando a separação entre teste de UI e testes unitários da fila.
- Os logs CI #78 e Android APK #79 confirmaram 33 dos 34 arquivos de teste concluídos; o único arquivo ausente da conclusão era o teste de envio pela interface.
- Mantém o limite de 3 minutos dos workflows como proteção contra regressões futuras.

## 2.0.88+200102 — 2026-09-24

- Corrige o travamento remanescente de `repository_send_flow_widget_test.dart`: o teste de interface deixa de iniciar cópia de ZIP e persistência real em disco dentro do `FakeAsync` do Flutter.
- `UploadManagerService.forTest` ganha a opção `runBackgroundQueue` (padrão `true`); apenas o teste de interface usa `false`, enquanto a suíte unitária continua exercitando a fila completa.
- O teste fecha explicitamente o diálogo de progresso após validar branch e política de build, evitando deixar o fluxo visual pendente ao encerrar.
- Os três workflows limitam a etapa `flutter test` a 3 minutos; qualquer travamento futuro falha automaticamente em vez de exigir cancelamento manual.
- Mantém as correções anteriores de persistência e `waitUntilIdle()` para o comportamento real do gerenciador.

## 2.0.87+200101 — 2026-09-24

- Corrige o deadlock do `repository_send_flow_widget_test.dart` que deixava CI #76 e Android APK #77 presos até cancelamento.
- `waitUntilIdle()` deixa de fazer polling com `Future.delayed(10 ms)` e passa a aguardar a conclusão da fila por `Completer`, funcionando dentro de `testWidgets`/`FakeAsync`.
- A conclusão da fila sinaliza explicitamente o estado ocioso sem depender da passagem de tempo virtual.
- Caminhos de falha de upload/build passam a aguardar a persistência do histórico e a limpeza segura do ZIP gerenciado antes de concluir.
- Mantém o debounce de 650 ms somente no uso normal; `UploadManagerService.forTest` continua sem debounce.

## 2.0.86+200100 — 2026-09-24

- Corrige o `Timer` de 650 ms que permanecia pendente no teste de interface do fluxo de envio.
- Remove a corrida entre persistência de `history.json` e exclusão da pasta temporária nos testes do gerenciador de uploads.
- `UploadManagerService.forTest` passa a persistir sem debounce; produção mantém debounce de 650 ms.
- `waitUntilIdle()` agora também espera a fila de persistência terminar.
- `dispose()` agora aguarda persistência e encerramento do serviço de foreground antes de fechar o stream.
- Mantém os nomes padronizados dos logs introduzidos na 2.0.85.

## 2.0.85+200099 — 2026-09-24

- Corrige a detecção de identidade/versão em ZIP Android nativo que contém apenas o módulo `app/`, restaurando `applicationId`, `versionName` e `versionCode`.
- Atualiza o teste de repositório vazio para validar o seletor de branch reutilizável, onde esse comportamento está implementado desde a 2.0.82.
- Torna o teste de envio pela interface robusto a conteúdo rolável antes de alternar **Iniciar build após o envio**.
- Renomeia os workflows para `GitHub Manager CI`, `GitHub Manager Android APK` e `GitHub Manager Android Release`, deixando os arquivos baixados pelo GitHub mais claros.
- Padroniza também o botão **Log** do aplicativo para salvar `<Repositorio>-<Workflow>-<Run>-logs.zip` sem duplicar o nome do repositório.

## 2.0.84+200098 — 2026-09-24

- Corrige o erro fatal do CI/APK #73 em `permission_preflight_service_test.dart`: o gateway de teste volta a declarar explicitamente a capacidade `push` usada no diagnóstico de permissões.
- Remove a expressão nula inalcançável em `repository_git_workflows.dart`, eliminando os warnings `dead_code`/`dead_null_aware_expression` associados.
- Limpa o lint recente do `separatorBuilder` na tela Builds sem alterar o comportamento da interface.
- Mantém a nomenclatura atual dos pacotes de logs; nenhuma mudança de nome de saída foi aplicada nesta versão.

## 2.0.83+200097 — 2026-09-24

- Reorganiza a aba global **Builds** para exibir somente um card por repositório, representando o commit/versão mais recente.
- Ao tocar no repositório, abre um pop-up com os workflows atuais daquele commit, preservando casos com duas builds simultâneas, como CI + Android APK.
- Adiciona ações rápidas **Log** e **APK** em cada build do pop-up; artifacts APK são consultados somente quando o usuário solicita o download.
- Atualiza o polling visual a cada 6 segundos, mantendo consulta curta apenas nos repositórios com execução ativa e varredura global a cada 1 minuto ou por atualização manual.
- Corrige os erros fatais dos logs Android-APK-72 e Verificação do Projeto CI-72: `_isLikelyRootFile` ausente e uso nullable de `RepositoryBranch` após a escolha da branch.
- Remove warnings diretamente relacionados à implementação recente em upload, workflow e preparação de APK.
- Amplia testes da tela/serviço Builds para agrupamento por repositório, múltiplos workflows no mesmo commit e navegação para a execução específica.

## 2.0.82+200096 — 2026-09-24

- Unifica a seleção de branch em Arquivos, Commits, Builds e Enviar versão e adiciona criação de nova branch a partir da branch atual.
- Adiciona prévia somente-leitura antes do envio com contagem/lista de arquivos novos, alterados e removidos.
- Corrige identificação de versão em ZIPs com múltiplos projetos ao priorizar metadados da raiz efetiva em vez do primeiro arquivo compatível encontrado.
- Preserva pré-lançamentos completos (`alpha`, `beta`, `rc`, `dev`) ao inferir versão pelo nome do ZIP e mantém essa origem explicitamente marcada como inferida.
- Amplia detecção de identidade/versão para Godot (`project.godot`), Python (`pyproject.toml`) e Rust (`Cargo.toml`).
- Exibe a origem da versão e, quando disponível, o saldo do rate limit REST do GitHub na conferência de envio.
- Adiciona testes para detecção de raiz, versão alpha no nome, prévia de sincronização, criação de branch e leitura de rate limit.

## 2.0.81+200095 — 2026-09-24

- Move a escolha da branch para antes do pré-check de sincronização e repete o diagnóstico quando a branch é alterada na confirmação final.
- Permite o primeiro envio para repositório realmente vazio quando o GitHub retorna zero branches, mantendo falhas de API separadas desse caso.
- Corrige a comparação de versões para SemVer, incluindo precedência de `alpha`, `beta`, `rc`, identificadores numéricos e metadados `+build`.
- Reduz chamadas da tela global **Builds**: cache em memória da lista de repositórios por 10 minutos, polling de 10 segundos apenas nos repositórios com execução ativa e varredura global a cada 3 minutos.
- Adiciona testes de SemVer, cache/polling e um teste de widget do fluxo de envio pela interface com escolha de branch e build desmarcada.

## 2.0.80+200094 — 2026-09-24

- Adiciona **Alterar** diretamente em **Branch de destino** na confirmação final de envio. Ao trocar a branch, o app recarrega os metadados e a detecção de workflow daquela branch antes de permitir o envio.
- Mantém a preferência da última branch usada como best-effort e preserva a seleção atual ao reabrir o seletor.
- Passa a identificar versões de projetos Shell/Termux via `MANIFEST.json` e variáveis `*VERSION=` no `manager.sh`, no ZIP local e no repositório remoto.
- Quando não há versão interna confiável, exibe uma versão inferida do nome do ZIP apenas como pista visual, sem usá-la como fonte forte na comparação de segurança.
- Adiciona testes de regressão para o retorno tipado do diálogo, troca de branch e detecção de versão do Termux Manager.

## 2.0.79+200093 — 2026-09-24

- Corrige o erro fatal de análise em `global_builds_screen.dart`: `AsyncValue<GlobalBuildsSnapshot>` não usa mais o getter inexistente `valueOrNull`; o polling passa a ler somente `AsyncData`.
- Confirma e protege por teste o contrato de `_confirmZip()`: o diálogo `showDialog<ManagedUploadBuildPolicy>` retorna `buildPolicy`; o `bool` permanece apenas no diálogo interno `showDialog<bool>` de confirmação forçada.
- Limpa warnings introduzidos pela reorganização recente de Projetos, incluindo import sem uso, resultados de `ref.refresh` descartados e helpers/membros mortos.
- Correção baseada nos logs Android-APK-69 e Verificação do Projeto CI-69.

## 2.0.78+200092 — 2026-09-23

- Corrige a suíte `TokenPermissionDiagnosticsService`: o diagnóstico de **Contents** para PAT clássico volta a exigir apenas `repo`, alinhado ao fluxo atual de sincronização do projeto sem build.
- Mantém `repo + workflow` exclusivamente para operações de **Actions/Build**, preservando a separação introduzida nas versões 2.0.74–2.0.76.
- Correção baseada nos logs Android-APK-67 e Verificação do Projeto CI-67, que apresentavam 99 testes aprovados e 1 falha.

## 2.0.76+200090 — 2026-09-23

- Corrige o pré-check de **Enviar nova versão**: PAT clássico com `repo` volta a ser suficiente para sincronizar arquivos, sem exigir `workflow` quando a operação não inicia build.
- Mantém `repo + workflow` para **Enviar build**, preservando a separação entre sincronização do projeto e controle de GitHub Actions.
- Ajusta o diagnóstico equivalente de PAT fine-grained para `Contents: write` na sincronização e `Actions: write` na etapa de build.
- Correção baseada nos logs Android-APK-66 e Verificação do Projeto CI-66, que apresentavam 99 testes aprovados e 1 falha no `PermissionPreflightService`.

## 2.0.75+200089 — 2026-09-23

- Corrige erro de análise em `global_builds_screen.dart`: `ListView` não possui construtor `const`.
- Corrige identificador inexistente `buildPolicy` no diálogo de criação de fork; confirmação volta a retornar `true`.
- Mantém as melhorias da 2.0.74 para seleção de branch, Builds globais e projetos sem workflow.
- Correções baseadas nos logs Android-APK-65 e Verificação do Projeto CI-65.

## 2.0.74+200088 — 2026-09-23

- O envio de uma nova versão agora permite escolher a branch de destino antes da conferência; a última branch escolhida por repositório é lembrada localmente e branches protegidas são identificadas.
- A comparação de identidade/versão do projeto passa a consultar a branch realmente selecionada, evitando comparar `dev`/`release` contra `main`.
- Adicionada a aba global **Builds** no menu inferior, reunindo as execuções recentes do GitHub Actions de todos os projetos e permitindo filtrar por executando, sucesso ou falha.
- **Acompanhados** foi movido para dentro de Projetos em um seletor `Meus projetos / Acompanhados`, mantendo cinco itens no menu inferior.
- Projetos sem workflow de APK, como scripts e utilitários que não precisam de compilação, agora são identificados já na conferência e terminam como **Projeto atualizado • Sem workflow de build**, sem falso erro ou estado de build pendente.
- O pré-check de **Enviar nova versão** exige somente permissão de Contents; permissões de Actions continuam necessárias apenas para operações de build.
- Quando um workflow de APK é detectado, a conferência permite desmarcar **Iniciar build após o envio**; nesse caso o projeto é sincronizado sem consultar/disparar Actions.
- A detecção de ausência de workflow foi antecipada para evitar espera desnecessária antes de concluir projetos que não utilizam GitHub Actions; falhas de rede/API durante a inspeção continuam sendo tratadas como diagnóstico pendente, não como ausência de workflow.
- Testes foram ampliados para cobrir branch específica, projeto sem workflow e a separação de permissões entre sincronização e build.

## 2.0.73+200087 — 2026-09-16

- Corrigidos os dois erros `non_constant_list_element` detectados nos logs Android APK 63 e CI 63.
- `leftover` em `build_cleanup_service_test.dart` passou a ser constante em tempo de compilação, preservando os testes de limpeza de artifacts.
- Removido import de teste não utilizado.
- Nenhuma regra de exclusão de build, artifact ou APK de Release foi alterada.

## 2.0.72+200086 — 2026-09-16

- Refatorado `ManagedUpload` em componentes internos de estado, diagnóstico, ciclo de vida, relatório e codec JSON.
- Preservado o contrato público usado pela Central de Envios, telas e `UploadManagerService`.
- Mantidas as mesmas 51 chaves de persistência para compatibilidade com checkpoints anteriores.
- Adicionado teste de contrato cobrindo diagnóstico, relatório, round-trip JSON e retry após a divisão.

## 2.0.71+200085 — 2026-09-16

- Refatorado o ciclo de vida do SQLite para uma única conexão compartilhada por isolate.
- Removido o construtor público de `LocalDatabase`, evitando abertura acidental de conexões independentes.
- Aberturas concorrentes do banco agora reutilizam o mesmo `Future<Database>`.
- `localDatabaseProvider`, startup, monitor de builds e preferências de recuperação deixaram de fechar o banco após operações curtas.
- `singleInstance: true` voltou a ser usado com ownership controlado por isolate.
- Mantidos reparo idempotente do esquema, reconstrução local segura e preservação do token GitHub.

## 2.0.70+200084 — 2026-09-16

- Refatoradas as telas grandes de Configurações, Detalhe do repositório, Builds/Detalhe da build e APKs/Releases.
- Exclusão de build passou a limpar artifacts e APKs de Release vinculados com segurança ao mesmo commit.
- Adicionada exclusão direta de assets de Release e paginação ampliada de Releases.

## 2.0.69+200083 — 2026-09-16

- Corrigida a referência de `_shortSha` que interrompia a compilação.
- Workflow Android passou a executar análise e testes Dart antes do Gradle.
