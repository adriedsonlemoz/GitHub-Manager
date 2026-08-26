# GitHub Manager 2.0.20 (200034)

## Correção dos logs #17

Os logs reais de `Android APK #17` e `Verificação do Projeto (CI) #17`
apontaram quatro erros de nulabilidade em:

- `local_project_service.dart`
- `repository_project_info_service.dart`

A versão detectada no YAML agora é promovida para uma variável não nula antes
de usar `contains()` e `split()`. Isso elimina os quatro erros que impediam
`flutter analyze` e `assembleRelease`.

## Detalhe da Build

As ações principais foram movidas para o início do detalhe da execução, logo
abaixo do status:

`Logs • Repetir • APK • Excluir`

Durante uma execução ativa, `Cancelar` aparece no mesmo local.

Não é mais necessário rolar todos os jobs e steps até o fim apenas para baixar
logs, repetir a execução, abrir o APK ou excluir a run.

## Base preservada

Mantém a lógica corrigida de SHA → build automática → workflow_dispatch,
proteção contra ZIP errado, versões nas builds, Releases, notificações e demais
melhorias anteriores.

## Validação

- Erros dos logs #17 corrigidos diretamente nos arquivos indicados.
- Estrutura Dart verificada.
- Workflows YAML validados.
- pubspec, Manifest e JSON validados.
- Versionamento sincronizado.
- ZIP final testado quanto à integridade.

A confirmação final de compilação continua dependendo do GitHub Actions.
