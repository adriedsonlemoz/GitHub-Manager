# Validação GitHub Manager 2.0.130

- Código de pausa/retomada e ciclo de vida do arquivo parcial revisados.
- `test/download_pause_resume_test.dart` adiciona regressão para estado pausado serializado, preservação de bytes, limpeza do histórico, segurança de retomada e componentes da UI.
- Mantidos `test/download_recovery_contract_test.dart` e demais testes anteriores.
- Versionamento sincronizado via `tool/check_version_sync.sh`.
- Estrutura ZIP, referências de versão, JSON, YAML e XML verificadas localmente.
- Flutter/Dart não disponíveis no ambiente de edição. Compilação Android, testes reais Dart e velocidade com redes distintas seguem pendentes de validação em CI/aparelho.
