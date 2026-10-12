# GitHub Manager 2.0.120+200134

## Origem: Android APK #109 e CI #108

Ambos executaram a versão 2.0.119 e terminaram em `flutter test`: 201 testes passaram e os mesmos 2 falharam em `test/workflow_log_naming_contract_test.dart`, ao encontrar o workflow CI antigo no checkout. `flutter analyze` e a verificação de versão passaram; a compilação do APK não foi iniciada.

## Correção

- A remoção de `.github/workflows/ci.yml` desde 2.0.118 não foi suficiente porque o serviço `GitProjectUploadService` preserva intencionalmente os arquivos GitHub Actions omitidos pelo ZIP.
- A integração conectada do GitHub confirmou `ci.yml` ativo em `main`, mas retornou HTTP 403 ao tentar removê-lo via Contents API.
- Foi reintroduzido um arquivo **de desativação**, não a CI anterior: somente `workflow_dispatch`, sem eventos automáticos, job `if: ${{ false }}` e permissão `contents: read`.
- O envio incremental pelo aplicativo substituirá o conteúdo remoto desse arquivo, permitindo que o fluxo de APK rode sem CI duplicada.
- Os testes agora verificam que o CI legado está ausente ou é comprovadamente inativo, sem aceitar o workflow antigo ativo. Nenhuma verificação dos workflows de APK ou Release foi retirada.

## Atenção

A correção só estará aplicada remotamente após enviar este ZIP para a branch `main` e verificar que o `ci.yml` foi sobrescrito. O nome do workflow ainda aparecerá no GitHub Actions até a exclusão definitiva. Se decidir excluí-lo, não reenvie o `ci.yml` do pacote; veja `docs/CI_LEGACY_REMOVAL.md`. Checks obrigatórios de branch protection que dependiam de `Analisar e testar` podem precisar ser alterados.

## Validação

`bash tool/check_version_sync.sh` deve concluir. Executar em CI: `flutter analyze --no-pub --no-fatal-infos --no-fatal-warnings`, `flutter test --no-pub` e `flutter build apk --release --no-pub`. Sem Flutter/Dart SDK no ambiente local, o APK permanece pendente de compilação.
