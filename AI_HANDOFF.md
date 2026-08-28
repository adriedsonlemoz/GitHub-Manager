# GitHub Manager — handoff

Estado atual: `2.0.36+200050`, com pré-checagem em cache das permissões antes de Enviar build, gerenciar Secrets e excluir repositórios; mantém o diagnóstico seguro por repositório, Secrets reforçados, Central de Envios global/minimizável e downloads em foreground com retomada.

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
- metadados de projeto, versão e tecnologias;
- navegação/edição/upload de arquivos;
- ZIP com sincronização completa e remoção de arquivos obsoletos;
- Actions: executar, acompanhar, cancelar, reexecutar, jobs/etapas/logs;
- Builds agrupadas por commit/envio, com horário até segundos e número da tentativa;
- Enviar build sincroniza o ZIP e garante o disparo do Android APK sem duplicar runs;
- Central de Envios permite minimizar a sincronização, navegar no app, acompanhar fila/histórico e repetir interrupções;
- relatório de envio separa resumo, arquivos alterados, GitHub/build e linha do tempo, evitando logs repetitivos por arquivo;
- upload reutiliza blobs cujo SHA Git já corresponde ao conteúdo do ZIP e serializa envios para reduzir chamadas mutativas concorrentes;
- artifacts/APK;
- Commits;
- Bugs via GitHub Issues sem reformulação adicional;
- GitHub Secrets com sealed box, PAT fine-grained/clássico, validação 48 KB/100, importação TXT/ENV/JSON/XML e diagnóstico por Secret;
- diagnóstico não destrutivo do token por repositório, com leitura real, escopos clássicos, `X-Accepted-GitHub-Permissions` e permissões necessárias para escrita;
- configurações, edição de perfil GitHub por popup responsivo, Groq/API opcional e tema;
- Central de Downloads com serviço Android em primeiro plano, retomada parcial por HTTP Range e publicação na pasta pública Downloads;
- download do projeto em ZIP;
- instalação de APK iniciada pelo usuário via FileProvider/instalador Android.




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
