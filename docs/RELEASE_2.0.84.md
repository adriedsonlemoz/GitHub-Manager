# GitHub Manager 2.0.84

Versão: `2.0.84+200098`

## Correções

- Corrige `Undefined name 'push'` em `permission_preflight_service_test.dart`, erro fatal que interrompia o CI e o build Android #73 durante `flutter analyze`.
- Remove o operador nulo inalcançável em `repository_git_workflows.dart`.
- Limpa o lint recente do `separatorBuilder` em Builds.

## Validação

Execute no CI: `flutter analyze` e `flutter test`. O script `tool/check_version_sync.sh` deve confirmar `2.0.84+200098`.
