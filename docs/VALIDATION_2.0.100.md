# Validação — GitHub Manager 2.0.100+200114

## Escopo

- garantir uma única task/entrada do GitHub Manager em Aplicativos recentes;
- evitar criação de nova task em instalação de APK e abertura de URI iniciadas pela Activity;
- garantir retorno consistente por notificações de upload/download;
- sincronização de identidade, novidades e documentação.

## Verificações executadas neste ambiente

- `tool/check_version_sync.sh`;
- inspeção estrutural do `AndroidManifest.xml`;
- inspeção da limpeza de tarefas duplicadas via `ActivityManager.appTasks`;
- busca por `FLAG_ACTIVITY_NEW_TASK` em `MainActivity.kt`;
- verificação dos `PendingIntent` dos serviços de upload/download;
- teste de contrato `test/android_recents_task_contract_test.dart`;
- verificação estrutural do ZIP final e ausência de APK dentro do pacote.

## Limitação do ambiente

Flutter/Dart não estão instalados neste ambiente, portanto `flutter analyze` e `flutter test` não podem ser executados localmente. A suíte permanece preparada para execução pela CI/GitHub Actions.
