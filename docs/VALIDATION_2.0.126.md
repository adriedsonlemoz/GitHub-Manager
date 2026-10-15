# Validação 2.0.126+200140

- Log analisado: Android APK #115, 227 testes passaram e 1 falhou no contrato de seleção de APK.
- A falha era uma asserção de texto desatualizada após migração da lógica de consultas para `repository_apk_status_provider.dart`.
- O contrato corrigido verifica o fluxo atual sem remover os demais requisitos de download e seleção.
- Validação local: sincronização de versionName/versionCode, consistência do teste com o código e integridade do ZIP.
- Pendentes: execução Flutter real (`flutter analyze`, `flutter test`) e compilação Android no GitHub Actions, além de teste em aparelho.
