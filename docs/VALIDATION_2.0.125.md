# Validação 2.0.125+200139

## Revisões locais

- Revisadas as ligações entre provedor de Releases/Artifacts, canal Android, comparação de versões e rótulo do botão APK.
- Criados `test/apk_installation_assessment_test.dart` e `test/installed_apk_integration_contract_test.dart` para cenários de comparação, versãoCode e visibilidade.
- Validação estrutural de JSON, XML, arquivos de versão e integridade do ZIP deve ser executada no empacotamento.

## Pendências

- `flutter analyze`, `flutter test` e build Android não executáveis localmente sem Flutter SDK.
- Testar no aparelho, especialmente Android 11+, e verificar os metadados e assinaturas reais dos APKs de Releases.
