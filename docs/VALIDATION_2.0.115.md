# Validação 2.0.115

## Base dos erros

- `GitHub-Manager-CI-104-logs.zip`: 191 testes passaram; `android_recents_task_contract_test.dart` falhou exigindo `action = Intent.ACTION_MAIN`.
- `GitHub-Manager-Android-APK-105-logs.zip`: mesma falha, sem entrar no passo de compilação Android.

## Correção

- Os dois `ForegroundService` usam `ACTION_MAIN` e `CATEGORY_LAUNCHER`, mantendo a rota no extra `notificationRoute` e flags `CLEAR_TOP`/`SINGLE_TOP`.
- Testes de regressão verificam o contrato e as rotas `/uploads?uploadId=` e `/downloads?downloadId=`.

## Comandos da CI

```bash
bash tool/check_version_sync.sh
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test
```

Validar em aparelho real com toque na notificação de upload e download quando o app estiver em primeiro plano, em segundo plano e encerrado. Verificar que a Central destaca a transferência correspondente e que não há tarefa duplicada nos Recentes.

**Estado local:** verificação estática e sincronização de versão disponíveis; Flutter/Dart e compilação de APK não executados neste ambiente.
