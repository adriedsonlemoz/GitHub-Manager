# GitHub Manager 2.0.69

Versão: `2.0.69+200083`

## Correções

- Corrige o erro de compilação detectado nos workflows Android APK 60 e Verificação do Projeto CI 60.
- `_shortSha(...)` estava dentro de `_FailureDiagnostic`, mas também era chamado diretamente por `UploadProgressDialog`.
- O helper agora fica no escopo do arquivo e pode ser usado com segurança pelas duas classes.
- Remove uma importação não utilizada da tela de progresso.
- Mantém as melhorias de build pendente e proteção de workflows introduzidas na 2.0.68.

## Prevenção

Além da CI, o workflow **Android APK** agora executa `flutter analyze` e `flutter test` antes de entrar na compilação Gradle. Assim, erros Dart como referência fora de escopo são interrompidos mais cedo e com diagnóstico mais direto.
