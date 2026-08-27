# GitHub Manager — handoff

Estado atual: `2.0.24+200038`, com Central de Envios global/minimizável, serviço Android em primeiro plano, retomada por checkpoint e relatório de envio visual/textual resumido por métricas e etapas.

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
- repositórios acompanhados em modo somente leitura, com Releases/APKs públicos;
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
- GitHub Secrets com sealed box;
- configurações, perfil GitHub, Groq/API local e tema;
- Central de Downloads integrada com publicação na pasta pública Downloads;
- download do projeto em ZIP;
- instalação de APK iniciada pelo usuário via FileProvider/instalador Android.

## Segurança

Nunca incluir keystore, `.env`, tokens ou key.properties no ZIP/repositório.

## ZIP idêntico

Se um ZIP gerar a mesma árvore Git já publicada, não criar commit nem build automática. Informar `Projeto já está atualizado` e permitir `Executar build mesmo assim` via `workflow_dispatch`.
