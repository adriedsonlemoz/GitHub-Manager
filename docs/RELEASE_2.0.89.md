# GitHub Manager 2.0.89+200103

Data: 2026-09-24

## Correção

Os logs CI #78 e Android APK #79 mostraram que 33 dos 34 arquivos de teste concluíam normalmente. O único arquivo sem conclusão era `repository_send_flow_widget_test.dart`.

O travamento vinha de `pumpAndSettle()` executado depois que o diálogo de progresso era aberto. Como esse diálogo possui animação contínua, o teste aguardava indefinidamente por um estado sem frames agendados.

A 2.0.89 remove `pumpAndSettle()` desse fluxo e usa esperas limitadas por número de pumps para os estados visuais esperados. O teste continua sem iniciar a fila real de I/O do upload, que permanece coberta pelos testes unitários próprios.

Os workflows continuam com timeout de 3 minutos na etapa de testes para impedir jobs presos em regressões futuras.
