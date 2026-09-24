# GitHub Manager 2.0.78

Versão: `2.0.78+200092`
Data: 2026-09-24

## Objetivo

Estabilizar integralmente o conjunto branch + envio + build + tela Builds introduzido nas versões 2.0.74–2.0.77, corrigindo integrações que passavam pela análise estática mas podiam falhar em execução.

## Correções principais

- confirmação de **Enviar versão** retorna `ManagedUploadBuildPolicy`, nunca `bool`;
- diagnóstico de permissões é executado para a branch escolhida;
- sincronização normal exige Contents; alteração real de `.github/workflows` considera permissão de Workflows; Actions é verificada somente se a build automática for solicitada;
- PAT clássico usa `repo` para `workflow_dispatch`; `workflow` fica restrito à alteração de arquivos de workflow;
- fine-grained diferencia `Contents: write`, `Workflows: write` e `Actions: write`;
- falha ao listar branches interrompe o fluxo com **Tentar novamente**; leitura/gravação da preferência local é best-effort;
- Builds global abre o `runId` tocado, filtra pela branch e usa polling adaptativo (10 s com execução ativa, 60 s em repouso);
- `requested` e `pending` contam como execução ativa;
- `APK_WORKFLOW_NOT_FOUND` tardio muda a política para `skipNoWorkflow`.

## Cobertura de regressão adicionada

- widget test do retorno tipado da confirmação de envio;
- widget test da navegação Builds global → execução específica;
- teste dos estados ativos de workflow;
- teste do pré-check usando a branch selecionada;
- testes de PAT clássico/fine-grained para permissões contextuais;
- teste do fallback tardio sem workflow preservando o rótulo correto.

## Validação local deste pacote

O pacote inclui as novas verificações, mas `flutter analyze`/`flutter test` dependem do SDK Flutter. A validação definitiva deve ser feita pelo workflow do projeto, que já executa análise e testes antes da etapa Gradle.
