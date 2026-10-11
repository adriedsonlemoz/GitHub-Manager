# Validação 2.0.110

- Conferir versão no `pubspec.yaml`, `github-manager.json`, Novidades e histórico de Configurações.
- Conferir uso de `ProjectSafetyCheck` e confirmação extra em identidade bloqueada.
- Conferir `UploadIdentificationDiagnosis` sem token e caminhos de diagnóstico sob demanda.
- Conferir fallback Android somente quando não há nome explícito, com resolução XML.
- Executar `dart format lib test`, `flutter analyze`, `flutter test` e `flutter build apk --release` na CI. Estes comandos não foram executados localmente por ausência do SDK.
- Em aparelho: comparar ZIP de outro projeto, repositório vazio, mesma versão, regressão, API offline, upload com exclusões e envio sem workflow.
