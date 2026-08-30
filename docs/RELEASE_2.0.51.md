# GitHub Manager 2.0.51

Versão: `2.0.51+200065`

## Ícone Android

- Integra o novo ícone roxo de repositório/sincronização ao aplicativo.
- Adiciona launcher PNG nas densidades `mdpi`, `hdpi`, `xhdpi`, `xxhdpi` e `xxxhdpi`.
- Adiciona Adaptive Icon para Android 8+ (`mipmap-anydpi-v26`).
- O `AndroidManifest.xml` passa a usar `@mipmap/ic_launcher` e `android:roundIcon`.

## Correção CI / APK

Os workflows `Verificação do Projeto (CI) #44` e `Android APK #44` falhavam em `flutter pub get --enforce-lockfile` com exit code 65. O lockfile continha quatro dependências do Flutter SDK com `description` incompatível com a resolução oficial: `flutter_localizations`, `flutter_test`, `flutter_web_plugins` e `sky_engine`. Todas foram corrigidas para `description: flutter`, preservando as versões travadas.

## Robustez da Central de Envios

- O monitor local de notificações de build deixa de ser uma dependência crítica do disparo: se SQLite/WorkManager/notificações falharem, o app registra o fato e continua consultando/iniciando a build no GitHub.
- Alinha o texto do relatório técnico com os testes: `Alterados nesta tentativa`.
- As correções eliminam também as cinco falhas que já apareciam na CI anterior: quatro no `UploadManagerService` e uma no relatório de `ManagedUpload`.

## Compatibilidade

Não altera `applicationId`, assinatura, armazenamento seguro, banco local, filas, checkpoints, formato de projeto ou permissões GitHub.
