# GitHub Manager 2.0.10

GitHub Manager é um aplicativo Flutter/Dart para Android que administra repositórios e GitHub Actions diretamente pela API do GitHub, sem backend intermediário.

## Identidade oficial

- versão: `2.0.10+200024`;
- package Dart: `github_manager`;
- applicationId/namespace: `br.com.githubmanager.app`;
- assinatura oficial própria e permanente;
- APK Release universal com `armeabi-v7a` e `arm64-v8a`.


## Repositório oficial

O desenvolvimento oficial usa `adriedsonlemoz/GitHub-Manager`. Validações de Actions e builds devem sempre ser feitas neste repositório; o repositório anterior não é fonte de validação da versão atual.

## Repositórios acompanhados

A tela inicial separa `Meus repositórios` e `Acompanhados`. Repositórios públicos de outros desenvolvedores podem ser adicionados por URL ou `owner/repo`, sem criar outra sessão. Eles são mantidos localmente como referências e abertos em modo somente leitura, com download do projeto e acesso a Releases/APKs quando disponíveis.

## Notificações de Builds

O GitHub Manager pode acompanhar execuções em segundo plano e avisar quando uma build termina com sucesso, falha, é cancelada ou excede o tempo. O monitor é ativado por padrão após a permissão do Android e pode ser desligado em Configurações.

Para economizar bateria e respeitar as regras do Android, a verificação periódica é feita em intervalos aproximados de 15 minutos e o próprio sistema pode atrasar uma execução em situações de economia de energia.

## GitHub Actions e Builds

A tela Builds usa `GET /repos/{owner}/{repo}/actions/runs` como fonte principal das execuções recentes. Cada run preserva `workflow_id` e `path`; ao abrir um workflow específico, o filtro é feito localmente. Se o resultado filtrado for vazio, o app consulta também o endpoint específico por workflow ID/arquivo e exibe diagnóstico em vez de transformar automaticamente a resposta em “nenhuma execução”.

A tela agrupa execuções pelo mesmo commit/envio. Cada grupo mostra data e hora com segundos, SHA curto e origem (`push`, manual ou ambos); dentro dele ficam os workflows relacionados, com número, tentativa, branch, status e duração. Runs em andamento são atualizados automaticamente. Jobs e steps exibem explicações simples e, em falhas, o app tenta recuperar a annotation principal do check run para destacar job, etapa e mensagem.

O botão `Enviar build` da tela do projeto sincroniza o ZIP e verifica as execuções pelo SHA do novo commit. Se o `push` já iniciou o workflow Android APK, nenhuma execução duplicada é criada. Se não iniciou, o app aguarda a indexação e usa `workflow_dispatch`; em repositório recém-criado, também pode disparar por `android-apk.yml` quando a listagem de workflows ainda estiver vazia.

## Central de Downloads

Todos os downloads GitHub usam o mesmo gerenciador interno:

- APKs e artifacts;
- ZIP do projeto;
- logs do GitHub Actions;
- arquivos GitHub integrados futuramente pelo mesmo serviço.

A Central separa `Baixando`, `Concluídos` e `Falharam`, mostrando progresso, bytes, tamanho total, velocidade, estimativa restante e status. Downloads podem ser cancelados e falhas repetidas quando a origem ainda existe.

Arquivos concluídos são publicados diretamente na pasta pública `Downloads` do Android, sem pedir uma pasta a cada operação. O histórico pode ser removido sem apagar o arquivo; a exclusão do arquivo é uma ação separada. Arquivos concluídos podem ser abertos ou compartilhados. APKs oferecem `Instalar`, que apenas abre o instalador oficial do Android.

Falhas mantêm log sanitizado com data/hora, endpoint da API, HTTP, etapa, bytes, tamanho esperado, mensagem do GitHub e código interno. Token, Secrets, API Keys, senhas, `Authorization` e URLs temporárias assinadas não são registrados.

## Artifacts

Artifacts expirados continuam visíveis no histórico e são marcados como expirados, em vez de simplesmente desaparecer. Artifacts ativos com APK são extraídos e publicados como APK; outros artifacts são baixados como ZIP.

## Sincronização por ZIP

O envio de ZIP é uma sincronização completa. A implementação compara a árvore atual do repositório com os caminhos presentes no ZIP e cria remoções Git (`sha: null`) para arquivos antigos que não existem mais no pacote antes de criar o novo commit.

Se a árvore resultante for idêntica à árvore atual, o app não cria commit nem dispara build automaticamente. A tela informa que o projeto já está atualizado e oferece `Executar build mesmo assim` para uma recompilação manual do mesmo commit.

## Assinatura

Os workflows `Android APK` e `Android Release` usam os mesmos Secrets oficiais:

- `KEYSTORE_BASE64`
- `KEYSTORE_PASSWORD`
- `KEY_ALIAS`
- `KEY_PASSWORD`

A chave oficial desta geração usa o alias `github_manager_release`. O certificado público esperado fica em `android/release-signing.properties`. Keystore, arquivo de Secrets, `.env` e `key.properties` não fazem parte do ZIP do projeto.
