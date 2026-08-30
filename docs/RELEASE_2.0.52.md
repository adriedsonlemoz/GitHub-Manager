# GitHub Manager 2.0.52

Versão: `2.0.52+200066`

## Correção de build Android

- Corrigida a compilação Kotlin de `UploadForegroundService` e `DownloadForegroundService`.
- Os serviços deixaram de referenciar o launcher em `R.drawable.ic_launcher`, recurso removido ao migrar o ícone do app para `mipmap`.
- Adicionado `drawable/ic_stat_github_manager.xml`, ícone monocromático dedicado para notificações de foreground, adequado às regras visuais do Android.
- O launcher e o Adaptive Icon introduzidos na 2.0.51 permanecem inalterados.

## Diagnóstico

O workflow Android APK 45 chegava até `:app:compileReleaseKotlin` e falhava com `Unresolved reference drawable` nos dois foreground services.
