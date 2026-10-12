# Validação 2.0.117

- Base: 2.0.116+200130.
- Logs: `GitHub-Manager-CI-106-logs.zip` mostrou dois `undefined_method` em `repository_run_details.dart:64:34` e `:259:34`.
- Causa: `_RunStatusIcon` e `_JobIcon` chamados sem declarações correspondentes na biblioteca Dart.
- Corrigidos com implementações privadas no part `repository_run_details_widgets.dart`.
- Novo contrato: `test/repository_run_status_icons_contract_test.dart` valida as referências, declarações e estados.
- Executar no ambiente Flutter:

```bash
flutter pub get --enforce-lockfile
bash tool/check_version_sync.sh
flutter analyze --no-pub --no-fatal-infos --no-fatal-warnings
flutter test --no-pub
flutter build apk --release
```

- Não afirmar que os testes ou APK passaram antes de executar a CI/Android.
