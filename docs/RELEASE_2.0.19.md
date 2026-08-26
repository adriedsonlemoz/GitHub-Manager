# GitHub Manager 2.0.19 (200033)

## Enviar build — correção de lógica

- O SHA do commit recém-criado agora é sempre a primeira fonte consultada após o envio.
- A tela consulta `GET /repos/{owner}/{repo}/actions/runs?head_sha=<sha>` antes de procurar qualquer workflow manual.
- Se existir uma execução APK para o SHA, incluindo `queued`, `waiting`, `in_progress` ou até uma execução que terminou rapidamente, o envio é considerado iniciado.
- Nessa situação o app mostra `Projeto atualizado • Build iniciada`.
- Nenhum `workflow_dispatch` é enviado quando já existe execução automática para o commit.
- Antes de um dispatch manual existe uma segunda consulta do SHA para evitar condição de corrida e build duplicada.

## Detecção de workflow_dispatch

- A detecção não depende mais apenas de uma expressão simples.
- São reconhecidas formas YAML como:
  - `workflow_dispatch:`
  - `"workflow_dispatch":`
  - `on: [push, workflow_dispatch]`
  - `on: {push: ..., workflow_dispatch: ...}`
  - `on: workflow_dispatch`
- O app tenta localizar o workflow tanto pelo `path` devolvido pela API quanto por `.github/workflows/<arquivo>`.
- Se `/actions/workflows` ainda estiver atrasado, o app lista os arquivos reais de `.github/workflows`, identifica YAMLs de APK/Android e verifica o conteúdo antes de decidir que não existe dispatch.

## Detecção de APK

- Workflows/runs como `Android Signed APK` são tratados corretamente como build APK.
- Não há mais exclusão automática só porque o nome contém `release`, desde que o workflow seja claramente de APK.

## Confirmação

Quando uma build automática já existir, o resultado informa:
`Projeto atualizado • Build iniciada`

e identifica o SHA usado, deixando claro que nenhuma execução manual duplicada foi criada.

## Validação

- Estrutura Dart verificada.
- Workflows YAML validados.
- pubspec.yaml, AndroidManifest.xml e JSON validados.
- Versionamento sincronizado.
- ZIP final testado quanto à integridade.

A compilação final deve ser confirmada pelo GitHub Actions.
