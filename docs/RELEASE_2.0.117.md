# GitHub Manager 2.0.117+200131

## Correção da CI #106

- A análise Dart falhava porque `repository_run_details.dart` utilizava `_RunStatusIcon(run: _run)` e `_JobIcon(job: job)` sem definição na biblioteca.
- Restaurados os widgets em `repository_run_details_widgets.dart`, declarados na mesma biblioteca de `repository_actions_screen.dart` via `part`. Os ícones exibem o estado da execução e de seus jobs (andamento, sucesso, falha, cancelamento e ignorados) com tooltips.
- Adicionado `test/repository_run_status_icons_contract_test.dart` como proteção contra remoção acidental dos componentes.
- Preservadas as mudanças da 2.0.116 em escolha de APK, metadados, diagnóstico, envios, downloads e notificações.
- Versão canônica `2.0.117+200131`, versionCode 200131.

## Validação pendente

`flutter analyze`, `flutter test` e compilação Android devem ser executados na CI: somente a verificação estática/local de consistência é possível neste ambiente.
