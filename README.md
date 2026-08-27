# GitHub Manager 2.0.26

GitHub Manager é um aplicativo Flutter/Dart para Android que administra repositórios e GitHub Actions diretamente pela API do GitHub, sem backend intermediário.

## Identidade oficial

- versão: `2.0.26+200040`;
- package Dart: `github_manager`;
- applicationId/namespace: `br.com.githubmanager.app`;
- assinatura oficial própria e permanente;
- APK Release universal com `armeabi-v7a` e `arm64-v8a`.



## GitHub Secrets 2.0.26

O módulo de Secrets aceita PAT fine-grained (`github_pat_...`) e token clássico (`ghp_...`). Para Secrets, o fine-grained deve ter `Secrets: Read and write`; no token clássico, use o escopo `repo`. Antes de gravar, o aplicativo valida nomes, duplicidades, limite de 48 KB por valor e o limite final de 100 Secrets por repositório.

Importações TXT/ENV aceitam `NOME=valor`, `NOME: valor` e `export NOME=valor`; JSON e XML continuam suportados. O lote é pré-visualizado como `Criar` ou `Substituir` e o resultado é individual por Secret, permitindo sucesso parcial. O diagnóstico copiável registra nome, HTTP, endpoint, código e mensagem da API quando disponíveis, mas nunca inclui o valor do Secret.

A criptografia continua local com sealed box/Libsodium antes do `PUT` na API do GitHub. Arquivos de importação recebem limite preventivo de tamanho para evitar consumo excessivo de memória.

## Repositório oficial

O desenvolvimento oficial usa `adriedsonlemoz/GitHub-Manager`. Validações de Actions e builds devem sempre ser feitas neste repositório; o repositório anterior não é fonte de validação da versão atual.

## Repositórios acompanhados

A lista usa cache local e atualização paralela para abrir rapidamente. Cada acompanhado possui ação `Fork`, que cria uma cópia na conta conectada, e o diálogo de inclusão possui botão para colar a URL.

A tela inicial separa `Meus repositórios` e `Acompanhados`. Repositórios públicos de outros desenvolvedores podem ser adicionados por URL ou `owner/repo`, sem criar outra sessão. Ao colar somente uma URL de perfil, como `github.com/usuario`, o app consulta os repositórios públicos daquela conta e permite escolher qual acompanhar. Eles são mantidos localmente como referências e abertos em modo somente leitura, com download do projeto e acesso a Releases/APKs quando disponíveis.

## Notificações de Builds

O GitHub Manager pode acompanhar execuções em segundo plano e avisar quando uma build termina com sucesso, falha, é cancelada ou excede o tempo. O monitor é ativado por padrão após a permissão do Android e pode ser desligado em Configurações.

Para economizar bateria e respeitar as regras do Android, a verificação periódica é feita em intervalos aproximados de 15 minutos e o próprio sistema pode atrasar uma execução em situações de economia de energia.

## GitHub Actions e Builds

A tela Builds usa `GET /repos/{owner}/{repo}/actions/runs` como fonte principal das execuções recentes. Cada run preserva `workflow_id` e `path`; ao abrir um workflow específico, o filtro é feito localmente. Se o resultado filtrado for vazio, o app consulta também o endpoint específico por workflow ID/arquivo e exibe diagnóstico em vez de transformar automaticamente a resposta em “nenhuma execução”.

A tela agrupa execuções pelo mesmo commit/envio. Cada grupo mostra data e hora com segundos, SHA curto e origem (`push`, manual ou ambos); dentro dele ficam os workflows relacionados, com número, tentativa, branch, status e duração. Runs em andamento são atualizados automaticamente. Jobs e steps exibem explicações simples e, em falhas, o app tenta recuperar a annotation principal do check run para destacar job, etapa e mensagem.

O botão `Enviar build` da tela do projeto sincroniza o ZIP e verifica as execuções pelo SHA do novo commit. Se o `push` já iniciou o workflow Android APK, nenhuma execução duplicada é criada. Se não iniciou, o app aguarda a indexação e usa `workflow_dispatch`; em repositório recém-criado, também inspeciona estruturalmente os YAMLs em `.github/workflows` quando a listagem de workflows ainda estiver vazia.


## Central de Envios

O botão `Enviar build` não depende mais de um diálogo bloqueando a tela. Cada sincronização entra em uma fila global do aplicativo, pode ser minimizada e continua visível em qualquer tela por um indicador flutuante. A Central de Envios mantém histórico, progresso, etapa atual, arquivo processado, commit, workflow, falhas e logs copiáveis.

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

O envio de ZIP é uma sincronização completa. A implementação compara a árvore atual do repositório com os caminhos presentes no ZIP e cria remoções Git (`sha: null`) para arquivos antigos que não existem mais no pacote antes de criar o novo commit.

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
