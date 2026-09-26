# GitHub Manager 2.0.100+200114

## Objetivo

Eliminar a duplicação do GitHub Manager em **Aplicativos recentes** do Android depois de atualizar o app, instalar APKs ou retornar por notificações de transferência.

## Alterações

- `MainActivity` muda de `singleTop` para `singleTask`;
- remove a afinidade vazia (`android:taskAffinity=""`) e volta a usar a afinidade padrão do pacote;
- adiciona `android:documentLaunchMode="never"` para impedir criação documental de uma segunda tarefa;
- adiciona limpeza preventiva das tarefas antigas duplicadas do próprio pacote em `onCreate()` e `onNewIntent()`, preservando somente a task atual;
- `openUri()` e `installApk()` deixam de usar `FLAG_ACTIVITY_NEW_TASK` quando executados pela própria Activity;
- notificações de upload/download reabrem explicitamente `MainActivity` com `ACTION_MAIN`, `CATEGORY_LAUNCHER`, `CLEAR_TOP` e `SINGLE_TOP`;
- tela **Novidades da atualização** e Configurações passam a descrever a correção;
- teste de contrato protege task, intents de instalação/URI e PendingIntents de notificação.

## Identidade

- versionName: `2.0.100`
- versionCode: `200114`
