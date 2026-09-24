# GitHub Manager 2.0.90+200104

## Correção do travamento da suíte de testes

Os jobs CI #79 e Android APK #80 confirmaram que 33 dos 34 arquivos de teste terminavam e somente `repository_send_flow_widget_test.dart` permanecia ativo até o timeout de 3 minutos.

O teste antigo tentava validar o fluxo completo da tela de repositório, combinando seletor de branch, banco local, pré-check, prévia, confirmação, gerenciador de upload, roteamento e diálogo de progresso em um único `testWidgets`. Mesmo após retirar I/O e `pumpAndSettle`, esse encadeamento continuou instável no ambiente FakeAsync do Flutter.

A 2.0.90 substitui esse teste por cobertura de widget focada: uma prova a seleção real de `develop` no seletor reutilizável de branches; a outra abre um upload em modo de teste, confirma que o progresso indeterminado aparece e fecha pelo botão **Minimizar** usando apenas pumps de duração fixa. As regras de ordem e política do envio continuam cobertas por `repository_send_dialog_contract_test.dart` e os serviços de upload continuam cobertos por seus testes unitários próprios.
