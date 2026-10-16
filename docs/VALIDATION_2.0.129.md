# Validação 2.0.129+200143

- Verificar `bash tool/check_version_sync.sh`.
- Verificar JSON, YAML e XML do projeto; confirmar estrutura e CRC do ZIP.
- Verificar o contrato do botão na tela Play: habilitado somente com análise válida, cópia via `Clipboard.setData`, feedback e reavaliação.
- Novo teste unitário de texto `test/play_readiness_report_copy_test.dart`: todos os estados, evidências, observações e listas técnicas/manuais; projeto não Android sem dados inventados.
- Teste de contrato estendido em `test/play_readiness_ui_contract_test.dart`.

Pendente: `flutter analyze`, `flutter test` e build APK/instalação em aparelho, porque Flutter/Dart não estão instalados neste ambiente.
