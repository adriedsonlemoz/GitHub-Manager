# GitHub Manager 2.0.115+200129

## Correção dos workflows CI #104 / Android APK #105

- **Causa:** o teste de task única do Android exigia lançamento de notificações com `Intent.ACTION_MAIN` e `Intent.CATEGORY_LAUNCHER`. A 2.0.114 havia trocado esse contrato por ações personalizadas.
- **Correção:** `UploadForegroundService` e `DownloadForegroundService` voltam a abrir a `MainActivity` existente com `ACTION_MAIN`, categoria `LAUNCHER`, `CLEAR_TOP` e `SINGLE_TOP`.
- **Navegação específica preservada:** o extra `notificationRoute` continua incluindo `uploadId` ou `downloadId` codificado, sem abrir indiscriminadamente a Home.
- **Regressão:** o contrato verifica ação, categoria, flags, ausência de `NEW_TASK`, IDs e request codes distintos nos `PendingIntent`s.

## Validação

Executar `bash tool/check_version_sync.sh`, `flutter analyze` e `flutter test`, depois Android APK. Testar toques nas notificações durante transferência com a Activity aberta, minimizada e encerrada. Não há compilação local confirmada.
