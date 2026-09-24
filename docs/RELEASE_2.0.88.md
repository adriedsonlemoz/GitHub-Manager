# GitHub Manager 2.0.88

Versão: `2.0.88+200102`

## Correção

Os logs CI #77 e Android APK #78 confirmaram que os outros 126 testes concluíam, enquanto `repository_send_flow_widget_test.dart` permanecia em execução até o cancelamento. O teste de interface iniciava a fila real do `UploadManagerService`, que executa I/O de arquivo para copiar o ZIP e persistir o histórico. Essa carga ficava presa no ambiente `FakeAsync` de `testWidgets`.

A 2.0.88 adiciona ao construtor `UploadManagerService.forTest` a opção `runBackgroundQueue`, com padrão `true`. O teste de interface usa `false`: ele valida que a UI seleciona a branch e a política de build corretas sem iniciar I/O em segundo plano. Os testes unitários existentes continuam usando o padrão e exercitando a fila real completa. O diálogo de progresso é fechado explicitamente antes do fim do teste.

## Proteção do CI

As etapas `flutter test` dos workflows CI, Android APK e Android Release têm timeout de 3 minutos. A suíte atual termina normalmente em menos de um minuto; o limite existe apenas para impedir que uma regressão de teste mantenha o runner preso até cancelamento manual.
