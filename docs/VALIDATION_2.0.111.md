# Validação 2.0.111

## Origem

Logs fornecidos: `GitHub-Manager-CI-99-logs.zip`, `GitHub-Manager-Android-APK-100-logs.zip` (duas falhas, versão anterior), `GitHub-Manager-CI-100-logs.zip` e `GitHub-Manager-Android-APK-101-logs.zip` (177 testes aprovados, 3 falhos).

## Correções aplicadas

1. `global_corner_radius_contract_test.dart`: antes havia raios 6 e 5; ambos agora são 4.
2. `system_ui_settings_contract_test.dart`: verifica o histórico recente sem fixar versões antigas.
3. `upload_identification_diagnosis_test.dart`: relatório e teste concordam em `Versão no GitHub`.
4. `update_whats_new_contract_test.dart`: remove dependência de títulos de lançamento que mudam a cada versão.
5. Warning de classe não utilizada: `_ProjectVersionBanner` removido.

## Checagens estáticas locais

- `bash tool/check_version_sync.sh`
- Verificar raios e versões com testes estáticos, além da integridade do ZIP.

## Obrigatório na CI / máquina com Flutter

```sh
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub --no-fatal-infos --no-fatal-warnings
flutter test --no-pub
flutter build apk --release
```

A verificação de formatação do workflow é não bloqueante. É possível que outros arquivos do projeto ainda precisem de formatação. Não executar `dart format` indiscriminadamente numa correção pontual sem revisar o diff.

**Limite:** sem Flutter/Dart SDK neste ambiente, a compilação e os testes Dart não puderam ser executados aqui.
