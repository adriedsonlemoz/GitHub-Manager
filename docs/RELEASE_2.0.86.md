# GitHub Manager 2.0.86

Versão: `2.0.86+200100`

## Correções

- Corrige o timer de persistência pendente que fazia `repository_send_flow_widget_test.dart` falhar ao encerrar.
- Corrige a corrida de filesystem em `upload_manager_service_test.dart`, onde a pasta temporária podia ser apagada enquanto o histórico ainda estava sendo gravado.
- Em testes, a persistência é imediata e sem debounce; em produção, o debounce de 650 ms é preservado.
- `waitUntilIdle()` passa a incluir a conclusão das gravações pendentes.
- O descarte do gerenciador aguarda o encerramento seguro da persistência e do serviço de foreground.
