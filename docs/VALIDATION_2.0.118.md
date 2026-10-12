# Validação 2.0.118

1. Verificar que `.github/workflows/ci.yml` foi removido e os demais workflows continuam válidos.
2. Validar `pubspec.yaml`, `github-manager.json`, README, CHANGELOG, docs/VERSIONING, tela de Novidades e Configurações com `bash tool/check_version_sync.sh`.
3. Confirmar que os workflows Android APK e Android Release mantêm `flutter analyze`, `flutter test`, validação da versão e assinatura.
4. No GitHub Actions, executar **GitHub Manager Android APK** e, em release com os Secrets configurados, **GitHub Manager Android Release**.
5. Conferir configurações de regras de branch e atualizar check obrigatório `Analisar e testar`, caso existente.

Sem Flutter/Dart local, `flutter analyze`, `flutter test` e o build Android não foram executados.
