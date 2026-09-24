# GitHub Manager 2.0.85

Versão: `2.0.85+200099`

## Correções

- Corrige a falha de detecção de `applicationId` em ZIP Android nativo composto pelo módulo `app/`.
- Atualiza o contrato de repositório vazio para a implementação atual em `repository_branch_selector.dart`.
- Corrige o teste de widget do envio para rolar o conteúdo antes de tocar em `Iniciar build após o envio`.

## Nomes de logs

- Workflow CI: `GitHub Manager CI`.
- Workflow APK: `GitHub Manager Android APK`.
- Workflow Release: `GitHub Manager Android Release`.
- Download pelo aplicativo: `<Repositorio>-<Workflow>-<Run>-logs.zip`, sem duplicar o nome do repositório quando ele já está no título do workflow.

## Validação esperada no CI

- `bash tool/check_version_sync.sh`
- `flutter analyze --no-pub --no-fatal-infos --no-fatal-warnings`
- `flutter test --no-pub`
- workflow Android APK
