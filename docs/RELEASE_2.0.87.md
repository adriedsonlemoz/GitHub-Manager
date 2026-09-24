# GitHub Manager 2.0.87

Versão: `2.0.87+200101`

## Correções

- Remove o polling com `Future.delayed(10 ms)` de `UploadManagerService.waitUntilIdle()`.
- Usa `Completer` para sinalizar o fim real da fila de upload, evitando deadlock no relógio virtual de `testWidgets`.
- Faz os caminhos de falha aguardarem a persistência de `history.json` e a limpeza segura do ZIP antes de a fila ser considerada ociosa.
- Mantém persistência sem debounce em `UploadManagerService.forTest` e debounce normal em produção.

## Origem

Os jobs GitHub Manager CI #76 e Android APK #77 concluíam praticamente toda a suíte rapidamente, mas permaneciam presos no teste `repository_send_flow_widget_test.dart` até cancelamento. A causa era a espera de 10 ms baseada em Timer dentro de `FakeAsync`.
