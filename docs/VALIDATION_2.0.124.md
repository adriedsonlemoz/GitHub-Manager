# Validação da versão 2.0.124

- Alterações de código: resolvedor puro de APK recente, tela de repositório e ação direta de download.
- Cobertura adicionada: `test/latest_apk_shortcut_test.dart`, incluindo Release sem Artifact, variantes múltiplas, versões entre fontes, artifacts expirados e agrupamento por execução.
- Contrato atualizado: `test/build_apk_selection_contract_test.dart`.
- Verificar `bash tool/check_version_sync.sh`, JSON, YAML e integridade do ZIP.
- Não foram executados `flutter analyze`, `flutter test` ou Gradle localmente: SDK Flutter/Dart indisponível neste ambiente.
- Validar em dispositivo Android o botão APK ativo, variantes corretas e comportamento quando só existe Release ou Artifact.
