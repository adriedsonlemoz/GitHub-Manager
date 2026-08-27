# GitHub Manager — handoff

Estado atual: `2.0.26+200040`, com módulo de Secrets reforçado para PAT fine-grained/clássico, pré-validação de lote, diagnóstico individual e testes dedicados; mantém Central de Envios global/minimizável e downloads em foreground com retomada.

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
- configurações, edição de perfil GitHub por popup responsivo, Groq/API opcional e tema;
- Central de Downloads com serviço Android em primeiro plano, retomada parcial por HTTP Range e publicação na pasta pública Downloads;
- download do projeto em ZIP;
- instalação de APK iniciada pelo usuário via FileProvider/instalador Android.


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
