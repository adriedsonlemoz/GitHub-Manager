# Validação da versão 2.0.127+200141

- Origem: Android APK #116, 227 testes aprovados e 1 falha por histórico de Configurações fora de ordem.
- Corrigido o histórico para as três versões sequenciais em ordem decrescente e com conteúdo compatível.
- `tool/check_version_sync.sh`: executar e registrar resultado na validação local.
- Verificação estática da ordem das notas e versão canônica.
- Conferência de JSON/YAML e CRC do ZIP.
- `flutter analyze`, `flutter test` e compilação APK não executados localmente por ausência do SDK Flutter.
