# GitHub Manager 2.0.74

GitHub Manager é um aplicativo Flutter/Dart para Android que administra repositórios e GitHub Actions diretamente pela API do GitHub, sem backend intermediário.

## Branch de envio, Builds globais e projetos sem workflow 2.0.74

- **Enviar nova versão** permite escolher a branch de destino (`main`, `dev`, `release` ou outra existente) e lembra a última opção usada em cada repositório;
- a conferência de identidade e versão usa a branch escolhida, não mais obrigatoriamente a branch padrão;
- o menu inferior passa a ter **Projetos, Builds, Downloads, Perfil e Opções**; **Acompanhados** fica dentro de Projetos;
- a nova tela **Builds** reúne execuções recentes de todos os projetos, ordenadas da mais nova para a mais antiga, com filtros para executando, sucesso e falha;
- projetos sem workflow de APK são tratados como projetos válidos que apenas sincronizam arquivos: quando a ausência puder ser confirmada, isso já é explicado na conferência; o envio termina em **Projeto atualizado • Sem workflow de build** e não cria falso alerta de build;
- quando há workflow de APK, a conferência permite manter marcada ou desmarcar **Iniciar build após o envio**; a permissão de Contents é suficiente para enviar uma nova versão e Actions só é necessária quando uma build for realmente solicitada;
- a verificação de workflow é feita antes da janela de espera do Actions quando possível, reduzindo atraso em projetos que não usam CI.



## Refatoração de telas e limpeza vinculada de builds 2.0.70

- refatora **Configurações**, **Detalhe do repositório**, **Builds/Detalhe da build** e **APKs/Releases**, separando UI, estado/ações e widgets auxiliares sem reescrever os fluxos existentes;
- exclusão de uma build passa a ser coordenada: primeiro remove o workflow run, depois confirma a limpeza dos artifacts e remove explicitamente qualquer artifact remanescente ligado ao mesmo `run_id`;
- APKs publicados como **Release assets** passam a ser ligados ao commit da build; quando o vínculo com o mesmo SHA é seguro, excluir a build também exclui o APK correspondente sem apagar a Release nem a tag;
- Releases publicadas pelo próprio GitHub Manager passam a usar o `head_sha` do artifact como `target_commitish`, tornando o vínculo futuro entre build e APK determinístico;
- tela **APKs** ganha exclusão direta para arquivos de Release e a ação **Excluir APKs anteriores** agora limpa tanto artifacts APK antigos quanto APKs antigos de Releases, mantendo o mais recente de cada origem;
- listagem de Releases deixa de consultar somente as 30 primeiras e passa a paginar até 500 Releases, permitindo localizar e administrar APKs mais antigos;
- caches/providers de artifacts e Releases são invalidados depois das exclusões para evitar itens já removidos continuarem aparecendo na interface;
- adiciona testes de regressão para vínculo `workflow_run/head_sha`, limpeza coordenada da build e limpeza de APKs anteriores nas duas origens.

## Correção do build e prevenção 2.0.69

- corrige a falha de compilação em `upload_progress_dialog.dart` causada por `_shortSha(...)` estar declarado dentro de `_FailureDiagnostic`, enquanto também era chamado por `UploadProgressDialog`;
- o formatador de SHA curto agora é um helper privado de arquivo, compartilhado com segurança pelas duas classes;
- remove importação não utilizada introduzida no mesmo diálogo;
- mantém o fluxo de **Projeto enviado • Build pendente** da 2.0.68, sem alterar a lógica de upload ou reenvio;
- além da CI, o workflow **Android APK** agora executa `flutter analyze` e `flutter test` antes da etapa Gradle, evitando gastar a compilação inteira em erros Dart detectáveis previamente.

## Builds protegidas e diagnóstico acionável 2.0.68

- workflows existentes em `.github/workflows/**` passam a ser tratados como infraestrutura protegida: um ZIP pode substituir um workflow pelo mesmo caminho, mas não pode apagá-lo apenas por omissão durante a sincronização;
- o diálogo **Conferir build** informa essa proteção antes do envio, reduzindo o risco de desativar GitHub Actions sem perceber;
- depois que o commit já foi publicado, a ausência de uma execução do Actions não aparece mais como **Envio com falha**: o estado correto é **Projeto enviado • Build pendente**;
- **Verificar build** repete somente a descoberta/inicialização da build usando o commit já enviado, sem reenviar o ZIP;
- a inspeção dos YAMLs diferencia workflow de APK ausente, workflow sem gatilho e workflow com `push` que ainda não gerou run;
- workflows com `push` recebem uma janela adicional de espera para reduzir falsos negativos causados pela indexação do GitHub Actions;
- o diagnóstico principal ficou compacto e rolável, com **Como corrigir** visível e detalhes técnicos recolhidos; há atalhos para **Abrir Builds**, copiar diagnóstico e copiar um exemplo de `push` + `workflow_dispatch` quando aplicável.


## Recuperação de dados locais 2.0.67

- corrige a migração do SQLite para instalações atualizadas, elevando o esquema para a versão 2;
- cria/repara tabelas e índices ausentes de forma idempotente ao criar, atualizar e abrir o banco;
- evita o compartilhamento acidental da mesma conexão SQLite entre serviços independentes que abrem/fecham o banco;
- falhas no estado local de projetos fixados deixam de derrubar a listagem principal obtida do GitHub;
- entradas JSON locais corrompidas são descartadas individualmente, sem exigir limpeza de todos os dados do aplicativo;
- Configurações ganha **Diagnóstico de dados locais**, com reparo de estrutura e opção de reconstruir somente o banco local, preservando o token GitHub.

## Conferência de build e ajuda 2.0.66

- corrige a falha de compilação causada pela chamada do menu de repositório sem o parâmetro obrigatório de projeto fixado;
- ZIPs Node/JavaScript passam a ler `name`, `displayName` e `version` do `package.json` da raiz, inclusive quando o ZIP possui uma única pasta-raiz;
- o diálogo **Conferir build** deixa de mostrar em vermelho a versão instalada do GitHub Manager e passa a destacar a **versão do projeto a enviar**;
- avisos de identidade/versão ganham botão `?` com explicação do motivo e instruções específicas para corrigir;
- Configurações ganha uma área **Ajuda do aplicativo** com guia de identidade, envios, builds, APKs, token, Secrets e solução de problemas;
- **Chave / token GitHub atual** fica acessível diretamente em Configurações, com exibição protegida e botão de copiar;
- o antigo banner vermelho de versão do GitHub Manager foi neutralizado para não ser confundido com a versão do projeto.

## Projetos fixados e lista otimizada 2.0.65

- **Fixar no topo / Desafixar do topo** usa a tabela local de favoritos que já existia no SQLite, sem criar armazenamento paralelo.
- projetos fixados aparecem antes dos demais e recebem um indicador discreto no card;
- novo filtro **Fixados** e ordenação por **Mais recentes, Mais antigos, Nome A–Z, Maiores e Menores**;
- a preferência de fixação permanece local e acompanha renomeações pelo `repository_id`; referências órfãs são limpas após uma listagem válida do GitHub;
- cards passam a usar uma leitura resumida de nome/versão, evitando consultar linguagens e todos os metadados completos só para montar a lista;
- a análise completa de tecnologias, package/applicationId e versionCode continua disponível nas telas internas;
- documentação e identificação de versão foram sincronizadas com a versão atual.

## Tamanho dos projetos 2.0.64

- mostra o tamanho informado pela API do GitHub ao lado da versão no card;
- mostra quantidade de projetos e tamanho total abaixo de **Meus repositórios**;
- não adiciona chamadas extras por projeto para obter o tamanho.


## Tela de APKs e Releases 2.0.63

- Releases deixam de ficar escondidas dentro de uma lista expansível e passam a aparecer diretamente na tela;
- cada arquivo de Release recebe identificação visual clara de **Release**, formato, versão/tag e download direto;
- Artifacts continuam separados e agora recebem o selo explícito **Artifact**, reduzindo a confusão entre as duas origens;
- busca por nome/versão e filtro **Todos / Releases / Artifacts** foram adicionados;
- a barra superior foi simplificada, mantendo busca, filtro, upload e um menu para ações administrativas;
- a tela continua usando os dados reais do repositório, sem inventar nomes, ícones ou versões.

## Recuperação inteligente de envios 2.0.62

- cada tentativa registra o **método de sincronização** usado: incremental, reconstrução completa da árvore ou arquivos individuais;
- falhas temporárias de rede, `408`, `429` e `5xx` recebem repetição automática controlada, com espera e histórico visível;
- quando o GitHub rejeita a árvore incremental com `422`, a recuperação automática revalida o SHA da branch e tenta **reconstruir a árvore final completa**, em vez de repetir os mesmos dados;
- antes de publicar um commit, trocar de método ou alterar um arquivo individual, o app confirma novamente o SHA da branch e interrompe se houver mudança concorrente;
- como último recurso manual, alterações pequenas e seguras podem usar a **API de arquivos individuais**, com limite de operações/tamanho e bloqueio para executáveis ou objetos Git não compatíveis;
- o diálogo de erro diferencia **Repetir método atual** de **Tentar método alternativo** e mostra qual opção é recomendada;
- o histórico do envio registra cada recuperação, código HTTP/endpoint relevante e o método que efetivamente concluiu a sincronização;
- Configurações ganhou **Recuperação automática de envios**, ativada por padrão e limitada a alternativas consideradas seguras.


## Diagnóstico detalhado de falhas no envio 2.0.61

- o diálogo de falha informa exatamente **onde o envio parou**, preservando a última operação real em vez de mostrar apenas “Falha no envio”;
- exibe **até onde o processo chegou**, incluindo arquivos já analisados e se a falha ocorreu depois da leitura do ZIP;
- preserva e mostra **HTTP, endpoint, código interno e resposta detalhada da API do GitHub**;
- respostas `422` passam a explicar separadamente falhas ao criar árvore Git, commit, atualizar branch, enviar blob ou usar a API de conteúdo;
- quando for possível determinar com segurança, informa o **impacto no repositório** — por exemplo, se a branch permaneceu no commit anterior;
- o GitHub Manager mostra blocos separados de **Resposta do GitHub**, **O que isso significa** e **O que fazer agora**;
- o parser da API inclui detalhes do array `errors` retornado pelo GitHub, não apenas a mensagem genérica `Validation Failed`;
- **Copiar diagnóstico** reúne etapa, progresso, HTTP, endpoint, resposta do GitHub, interpretação e ação sugerida;
- as etapas recentes deixam de cortar a mensagem em uma única linha no diálogo de envio.


## Builds em tempo quase real e diagnóstico 2.0.60

- a tela de Builds continua consultando o GitHub mesmo quando nenhuma execução estava ativa ao abrir a tela;
- atualização automática adaptativa: 6 s com build em andamento e 15 s quando tudo está parado, usando uma consulta leve das execuções recentes;
- a listagem mostra horário de cada execução e o momento da última atualização;
- segurar uma build, quando existem falhas visíveis, seleciona automaticamente todas as falhas, preservando as execuções de sucesso;
- exclusão em lote continua mesmo se uma execução falhar ao apagar e mantém apenas as falhas restantes selecionadas;
- detalhes da build mostram evento, tentativa, horários, duração de jobs/etapas e resumo do estado do APK quando isso pode ser determinado com segurança;
- falhas consultam annotations e analisam automaticamente o ZIP de logs para destacar a linha e o contexto mais relevantes;
- botão **Copiar diagnóstico** reúne os dados necessários para compartilhar o erro sem baixar e procurar manualmente no log inteiro.

## Dados do GitHub sem cache local 2.0.59

- Repositórios, descrições e perfil agora são consultados diretamente na API do GitHub, sem fallback para snapshots persistidos.
- Acompanhados persiste apenas a lista `owner/repo` escolhida pelo usuário; os dados exibidos são buscados novamente no GitHub.
- Diagnóstico de permissões não reutiliza relatório remoto em TTL local.
- Snapshots legados `github.repositories`, `github.profile` e `followed.repositories.cache` são apagados automaticamente.
- Providers de perfil, repositórios e metadados de projeto usam `autoDispose` para não manter dados remotos fora da tela.

A lista agora usa o cache somente para abrir imediatamente e passa a tratar a resposta mais recente da API como fonte autoritativa. Criar, editar, renomear, excluir e criar fork atualizam os cards no mesmo instante. Ao voltar da tela interna, a listagem reconcilia silenciosamente com o GitHub, corrigindo descrições e demais metadados antigos sem spinner de tela inteira.

`GitHubRepository` também possui igualdade por valor, estabilizando o cache de versão/tecnologias dos cards: o mesmo repositório não cria providers duplicados a cada reconstrução e, quando os dados realmente mudam, os metadados são renovados.

## Rename de repositório reforçado 2.0.57

- valida o novo nome antes de chamar o GitHub;
- mostra a prévia do novo endereço `owner/nome`;
- bloqueia nome vazio, igual ao atual, acima de 100 caracteres, com espaços, barras ou caracteres incompatíveis;
- detecta previamente quando já existe um repositório com o nome escolhido;
- atualiza cache principal, Acompanhados, informações do projeto e permissões após renomear.

## Listagem estável 2.0.56

A lista preserva os cards durante atualizações e deixa o spinner central restrito à primeira carga sem dados disponíveis.

## Android/Kotlin nativo 2.0.55

A detecção reconhece `app/build.gradle.kts` e `app/build.gradle`, extraindo `versionName`, `versionCode`, `applicationId`/`namespace` para cards, ZIPs e builds.

## Identidade oficial

- versão: `2.0.74+200088`;
- package Dart: `github_manager`;
- applicationId/namespace: `br.com.githubmanager.app`;
- assinatura oficial própria e permanente;
- APK Release universal com `armeabi-v7a` e `arm64-v8a`.


## Inicialização sem travar na splash 2.0.54

A 2.0.54 remove inicializações bloqueantes antes de `runApp()`. O Flutter agora desenha o primeiro frame imediatamente; leitura do tema, WorkManager e notificações são inicializados depois do primeiro frame, com timeout e isolamento de falhas. Assim, indisponibilidade ou lentidão de plugins nativos não mantém o aplicativo preso no logo.

## Splash screen Android 2.0.53

A 2.0.53 corrige o corte do ícone na tela de abertura do Android 12+, usando um recurso de splash com área segura maior e fundo branco em qualquer tema. O launcher/adaptive icon permanece igual.


## Ícone Android e correção de build 2.0.52

A 2.0.52 corrige os foreground services de upload e download para usar um ícone monocromático próprio de notificação (`ic_stat_github_manager`), evitando a falha Kotlin causada pela antiga referência `R.drawable.ic_launcher` depois da migração do launcher para `mipmap`.


O aplicativo passa a usar o novo ícone roxo de repositório/sincronização como launcher oficial. Foram adicionados recursos `mipmap` para todas as densidades Android e Adaptive Icon para Android 8 ou superior.

A versão também corrige o `pubspec.lock` da 2.0.50: quatro dependências fornecidas pelo Flutter SDK estavam com o campo `description` incorreto, fazendo `flutter pub get --enforce-lockfile` abortar com exit code 65 tanto na CI quanto no workflow de APK. O monitor local de notificações de build também deixa de bloquear o envio quando falha, corrigindo a causa dos testes antigos do `UploadManagerService`.

## Correção da conexão GitHub 2.0.50

O assistente de configuração agora diferencia corretamente ausência de autenticação de um token rejeitado pelo GitHub. Respostas `401` do endpoint `/user` deixam de exibir a mensagem enganosa “Conecte sua conta GitHub para continuar” e passam a explicar que o Personal Access Token pode estar expirado, revogado ou copiado incorretamente.

A entrada do PAT também é normalizada antes do teste e antes de ser gravada: espaços/quebras de linha acidentais, caracteres invisíveis, aspas/backticks e prefixos copiados como `Bearer` ou `Authorization: Bearer` são removidos. O botão Colar usa a mesma normalização, e o teclado pode concluir diretamente com “Testar e conectar”.

## Consolidação de segurança e sincronização 2.0.49

A listagem de repositórios continua abrindo pelo cache local para manter a inicialização rápida, mas agora reconcilia os dados com a API ao entrar na tela e ao retornar ao aplicativo. Repositórios removidos diretamente no site do GitHub deixam de permanecer como itens fantasmas no cache.

Downloads redirecionados deixaram de propagar URLs temporárias assinadas para endpoints diagnósticos e mensagens persistidas. Os serviços Android de upload/download tratam o timeout de `dataSync` do Android 15+, preservando os checkpoints existentes para retomada posterior.

As dependências usadas pela aplicação foram fixadas na resolução utilizada pelo Flutter 3.47.1 e o `pubspec.lock` passou a fazer parte do projeto. No envio de ZIP, arquivos maiores passam por arquivo temporário e base64 em fluxo, evitando manter simultaneamente o binário descompactado e sua representação base64 completa na memória.


## APKs compactos e envio flexível 2.0.31

A tela de APKs e Artifacts foi compactada: ações `Baixar`, `Publicar` e `Excluir` ficam lado a lado, com botões menores, enquanto o card mostra formato, versão detectada, data, tamanho, workflow run e classificação provável de build (`Debug`, `Profile`, `Release`, `AAB / Play`, `Estável provável`, `Prévia`). A estabilidade é tratada como inferência quando o GitHub não fornece o buildType diretamente.

A proteção de envio deixou de usar nome e versão como bloqueios rígidos. Regressão de versão é permitida com aviso; renomear projeto/repositório gera apenas alerta. Divergência isolada de `applicationId` ou pacote também pode ser confirmada. Somente a divergência simultânea de dois identificadores fortes entra em modo de risco alto, ainda com uma segunda confirmação explícita para `Forçar envio`.

## Interface e proteção de identidade 2.0.30

A versão 2.0.30 aproxima a interface do novo padrão visual do GitHub Manager: fundo azul-preto, superfícies em camadas, bordas discretas, cartões de repositório maiores e mais informativos, chips compactos, ações primária/secundária e navegação inferior flutuante. O tema compartilhado propaga a mesma linguagem para telas de builds, downloads, Secrets, configurações e diálogos sem criar uma segunda arquitetura visual.

A proteção de envio também corrige falso bloqueio quando o nome visível usa acentos ou separadores diferentes do nome do repositório, como `Tática Manager` e `TaticaManager`. A comparação agora dobra diacríticos antes da normalização e, em projetos Android/Flutter, tenta ler `applicationId` diretamente de `android/app/build.gradle(.kts)` quando os metadados de raiz não o informam. `applicationId` incompatível continua bloqueando o envio.

## Hotfix de compilação e CI 2.0.29

A versão 2.0.29 corrige a incompatibilidade introduzida no importador de Secrets com `file_picker 12`: `PlatformFile.size` não existe mais nessa API e foi substituído por `await PlatformFile.length()`. O limite preventivo de tamanho do arquivo continua sendo validado antes da leitura completa.

A CI também deixou de bloquear todo o pipeline por dívida de formatação preexistente. O runner normaliza `lib` e `test`, emite um warning quando houver diferenças e então executa `flutter analyze` e `flutter test`. Erros reais de análise ou testes continuam reprovando a CI.

## Proteção preventiva de permissões 2.0.28

Ações críticas agora consultam um diagnóstico antes de chamar a API. **Enviar nova versão** exige permissão de Contents para sincronizar arquivos; operações explicitamente ligadas ao GitHub Actions continuam validando Actions, operações de Secrets verificam `Secrets: write` e a exclusão permanente verifica a capacidade de exclusão. Quando uma negação já foi confirmada, a ação é interrompida antes de selecionar/enviar dados e o app mostra exatamente a permissão necessária, com acesso direto ao diagnóstico do token.

O cache dura poucos minutos e usa uma impressão SHA-256 do token apenas em memória como parte da chave. Se o token for trocado, o diagnóstico antigo não é reutilizado. Resultados inconclusivos de PAT fine-grained não bloqueiam a operação: como o GitHub não oferece introspecção segura de todas as permissões de escrita, a chamada real continua sendo a autoridade final. Rate limit ou indisponibilidade temporária do diagnóstico também não são tratados como permissão ausente.

## Diagnóstico de permissões 2.0.27

Cada repositório próprio possui `Diagnóstico do token`. A verificação é não destrutiva: usa somente consultas de leitura para testar acesso a Contents, Actions, Secrets e Administration, lê `X-Accepted-GitHub-Permissions` quando o GitHub o retorna e identifica os escopos expostos por PAT clássico.

O relatório separa `Confirmada`, `Disponível` por inferência, `Sem acesso` e `Verifique no token`. Em PAT fine-grained, permissões de escrita não são testadas por mutações, para que o diagnóstico nunca altere arquivos, Secrets, workflows ou configurações. O app mostra a permissão necessária para cada função, incluindo `Contents: write + Workflows: write` para sincronização completa por ZIP, `Actions: write`, `Secrets: write` e `Administration: write` para administração/exclusão. Para PAT clássico, o diagnóstico considera `repo`, `workflow` e `delete_repo` junto com o papel da conta no repositório.

O diagnóstico pode ser copiado sem incluir o token.

## GitHub Secrets 2.0.26

O módulo de Secrets aceita PAT fine-grained (`github_pat_...`) e token clássico (`ghp_...`). Para Secrets, o fine-grained deve ter `Secrets: Read and write`; no token clássico, use o escopo `repo`. Antes de gravar, o aplicativo valida nomes, duplicidades, limite de 48 KB por valor e o limite final de 100 Secrets por repositório.

Importações TXT/ENV aceitam `NOME=valor`, `NOME: valor` e `export NOME=valor`; JSON e XML continuam suportados. O lote é pré-visualizado como `Criar` ou `Substituir` e o resultado é individual por Secret, permitindo sucesso parcial. O diagnóstico copiável registra nome, HTTP, endpoint, código e mensagem da API quando disponíveis, mas nunca inclui o valor do Secret.

A criptografia continua local com sealed box/Libsodium antes do `PUT` na API do GitHub. Arquivos de importação recebem limite preventivo de tamanho para evitar consumo excessivo de memória.

## Repositório oficial

O desenvolvimento oficial usa `adriedsonlemoz/GitHub-Manager`. Validações de Actions e builds devem sempre ser feitas neste repositório; o repositório anterior não é fonte de validação da versão atual.

## Repositórios acompanhados

A lista usa cache local e atualização paralela para abrir rapidamente. Cada acompanhado possui ação `Fork`, que cria uma cópia na conta conectada, e o diálogo de inclusão possui botão para colar a URL.

A área Projetos possui um seletor interno entre `Meus projetos` e `Acompanhados`. Repositórios públicos de outros desenvolvedores podem ser adicionados por URL ou `owner/repo`, sem criar outra sessão. Ao colar somente uma URL de perfil, como `github.com/usuario`, o app consulta os repositórios públicos daquela conta e permite escolher qual acompanhar. Eles são mantidos localmente como referências e abertos em modo somente leitura, com download do projeto e acesso a Releases/APKs quando disponíveis.

## Notificações de Builds

O GitHub Manager pode acompanhar execuções em segundo plano e avisar quando uma build termina com sucesso, falha, é cancelada ou excede o tempo. O monitor é ativado por padrão após a permissão do Android e pode ser desligado em Configurações.

Para economizar bateria e respeitar as regras do Android, a verificação periódica é feita em intervalos aproximados de 15 minutos e o próprio sistema pode atrasar uma execução em situações de economia de energia.

## GitHub Actions e Builds

A tela Builds usa `GET /repos/{owner}/{repo}/actions/runs` como fonte principal das execuções recentes. Cada run preserva `workflow_id` e `path`; ao abrir um workflow específico, o filtro é feito localmente. Se o resultado filtrado for vazio, o app consulta também o endpoint específico por workflow ID/arquivo e exibe diagnóstico em vez de transformar automaticamente a resposta em “nenhuma execução”.

A tela agrupa execuções pelo mesmo commit/envio. Cada grupo mostra data e hora com segundos, SHA curto e origem (`push`, manual ou ambos); dentro dele ficam os workflows relacionados, com número, tentativa, branch, status e duração. Runs em andamento são atualizados automaticamente. Jobs e steps exibem explicações simples e, em falhas, o app tenta recuperar a annotation principal do check run para destacar job, etapa e mensagem.

O fluxo **Enviar nova versão** da tela do projeto primeiro permite escolher a branch, compara os metadados contra essa mesma branch, sincroniza o ZIP e, quando existe um workflow de APK compatível, verifica as execuções pelo SHA do novo commit. Se o `push` já iniciou o workflow Android APK, nenhuma execução duplicada é criada. Se não iniciou, o app aguarda a indexação e usa `workflow_dispatch`; em repositório recém-criado, também inspeciona estruturalmente os YAMLs em `.github/workflows` quando a listagem de workflows ainda estiver vazia. Se um workflow de APK por `push` existe mas o Actions demora a indexar a execução, o app espera uma janela adicional antes de marcar a build como pendente. Se não existir workflow de APK na branch escolhida, o envio termina normalmente como **Projeto atualizado • Sem workflow de build**. Falha real em um workflow existente não desfaz o commit nem transforma o envio já concluído em falha.


## Central de Envios

O fluxo **Enviar nova versão** não depende de um diálogo bloqueando a tela. Cada sincronização entra em uma fila global do aplicativo, pode ser minimizada e continua visível em qualquer tela por um indicador flutuante. A Central de Envios mantém histórico, progresso, etapa atual, arquivo processado, commit, workflow, falhas e logs copiáveis.

Para reduzir chamadas desnecessárias, o envio calcula o SHA Git dos arquivos do ZIP e reutiliza blobs já idênticos na árvore atual. Envios concorrentes são serializados e uma tentativa duplicada do mesmo ZIP/repositório é ignorada enquanto a anterior estiver ativa.

Durante a sincronização, o Android mantém um serviço em primeiro plano com notificação de progresso. Se a interface for removida dos recentes, o envio continua enquanto o processo estiver vivo. Se o processo for realmente encerrado, a fila é restaurada automaticamente ao abrir o app: o GitHub Manager usa a cópia privada do ZIP e reaproveita blobs/commit já salvos no checkpoint. Se o ZIP não tiver alterações, a Central mantém a opção `Executar build` usando o commit atual, sem reenviar o projeto.

A versão 2.0.25 remove o banner vermelho global. O destaque vermelho com texto branco aparece somente na confirmação de envio do ZIP, identificando claramente a versão do GitHub Manager instalada antes da sincronização. A Home permite editar o perfil GitHub tocando no avatar, e o menu de gerenciamento do repositório usa uma engrenagem com diálogo centralizado.


## Central de Downloads

Todos os downloads GitHub usam o mesmo gerenciador interno:

- APKs e artifacts;
- ZIP do projeto;
- logs do GitHub Actions;
- arquivos GitHub integrados futuramente pelo mesmo serviço.

A Central separa `Baixando`, `Concluídos` e `Falharam`, mostrando progresso, bytes, tamanho total, velocidade, estimativa restante e status. Durante downloads ativos, um serviço Android em primeiro plano mantém o processo com notificação de progresso ao minimizar ou remover a interface dos recentes. Downloads interrompidos preservam o arquivo parcial e, quando o servidor aceita `Range`, retomam a partir dos bytes já recebidos em vez de reiniciar do zero.

Arquivos concluídos são publicados diretamente na pasta pública `Downloads` do Android, sem pedir uma pasta a cada operação. O histórico pode ser removido sem apagar o arquivo; a exclusão do arquivo é uma ação separada. Arquivos concluídos podem ser abertos ou compartilhados. APKs oferecem `Instalar`, que apenas abre o instalador oficial do Android.

Falhas mantêm log sanitizado com data/hora, endpoint da API, HTTP, etapa, bytes, tamanho esperado, mensagem do GitHub e código interno. Token, Secrets, API Keys, senhas, `Authorization` e URLs temporárias assinadas não são registrados.

## Artifacts

Artifacts expirados continuam visíveis no histórico e são marcados como expirados, em vez de simplesmente desaparecer. Artifacts ativos com APK são extraídos e publicados como APK; outros artifacts são baixados como ZIP.

## Sincronização por ZIP

O envio de ZIP sincroniza completamente os arquivos do projeto. A implementação compara a árvore atual do repositório com os caminhos presentes no ZIP e cria remoções Git (`sha: null`) para arquivos antigos que não existem mais no pacote antes de criar o novo commit. A exceção de segurança é `.github/workflows/**`: workflows já existentes são preservados quando o ZIP apenas os omite, evitando que uma atualização do código desative a própria build. Se o ZIP trouxer o mesmo caminho de workflow, ele pode ser atualizado normalmente.

Se a árvore resultante for idêntica à árvore atual, o app não cria commit nem dispara build automaticamente. A tela informa que o projeto já está atualizado e oferece `Executar build mesmo assim` para uma recompilação manual do mesmo commit.

## Assinatura

Os workflows `Android APK` e `Android Release` usam os mesmos Secrets oficiais:

- `KEYSTORE_BASE64`
- `KEYSTORE_PASSWORD`
- `KEY_ALIAS`
- `KEY_PASSWORD`

A chave oficial desta geração usa o alias `github_manager_release`. O certificado público esperado fica em `android/release-signing.properties`. Keystore, arquivo de Secrets, `.env` e `key.properties` não fazem parte do ZIP do projeto.


## Sobre e suporte

A área Sobre mantém as três mudanças mais recentes recolhidas em um painel expansível, identifica o desenvolvedor como `@AdriedsonLemos`, oferece chave Pix e canal de feedback copiáveis e informa que o GitHub Manager é um projeto independente, sem parceria, afiliação, endosso ou patrocínio do GitHub. A integração Groq permanece opcional e reservada para futuros recursos de IA, como resumo de logs e explicação de erros; ela não é necessária para as funções GitHub atuais.


## Persistência SQLite 2.0.71

O banco local agora possui um único proprietário por isolate (`LocalDatabase.shared`). A UI inteira reutiliza a mesma conexão, e operações auxiliares como monitoramento de builds, preferências de recuperação e limpeza inicial deixaram de abrir e fechar conexões temporárias. A abertura concorrente é deduplicada e o WorkManager mantém sua própria conexão somente porque executa em outro isolate. Isso substitui o workaround de múltiplas conexões independentes da 2.0.67 sem alterar o esquema ou apagar dados.

## Arquitetura de ManagedUpload 2.0.72

`ManagedUpload` continua sendo o contrato consumido pela Central de Envios e pelo `UploadManagerService`, mas suas responsabilidades internas foram separadas. O arquivo principal mantém os dados persistidos e a API pública; estado derivado, diagnóstico de falhas, mutações de ciclo de vida, relatório técnico e codec JSON ficam em partes internas específicas. A estrutura JSON permanece compatível com checkpoints das versões anteriores.

Ao alterar o fluxo de upload, evitar recolocar regras extensas diretamente em `managed_upload.dart`: mudanças de diagnóstico pertencem a `managed_upload_failure.dart`, mudanças de retry/progresso a `managed_upload_lifecycle.dart`, textos/estado derivado a `managed_upload_state.dart`, relatório a `managed_upload_report.dart` e persistência a `managed_upload_codec.dart`.


## Correção 2.0.73

Os workflows 63 revelaram dois erros de análise no teste de limpeza de build: uma variável local `final` era usada dentro de listas `const`. A variável agora é `const`, permitindo que CI/testes avancem sem alterar a lógica de limpeza de builds/APKs/artifacts.
