# Validação 2.0.119

- [ ] Confirmar que `.github/workflows/ci.yml` não existe na branch remota `main` (não basta omiti-lo do ZIP).
- [ ] Executar `bash tool/check_version_sync.sh` para todos os metadados/versionCode.
- [ ] Executar `flutter analyze --no-pub --no-fatal-infos --no-fatal-warnings`.
- [ ] Executar `flutter test --no-pub`, incluindo `global_builds_screen_test.dart` e `workflow_log_naming_contract_test.dart`.
- [ ] Validar o workflow Android APK e seu APK gerado, sem executar CI duplicada.
- [ ] Conferir branch protection caso exija `Analisar e testar` antigo.

Resultado local: checks de versão e ZIP; Flutter/Gradle ainda dependem de execução externa.
