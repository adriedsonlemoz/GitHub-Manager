# GitHub Manager 2.0.106+200120

## Destaques

- Falhas de build em janela própria, sem empurrar o restante dos detalhes para baixo.
- Explicação por erro com **O que aconteceu**, **Onde aconteceu**, **Causa identificada/Possível causa** e **Como corrigir**.
- Mensagem original e contexto do log preservados em **Detalhes técnicos**.
- Botão APK restrito aos arquivos vinculados à execução/commit selecionado.
- Tela global **Builds** também usa seletor explícito quando há mais de uma opção; o atalho APK do repositório abre a lista de APKs em vez de escolher um arquivo silenciosamente.
- Seletor de variantes com arquitetura, tamanho, origem e recomendação baseada nas ABIs reais do aparelho.
- Aviso antes de baixar APK de arquitetura incompatível.
- Informações do aparelho em Configurações, sem permissão especial.
- Extração de Artifacts respeita a preferência de ABI e preserva essa informação em retry.

## Arquivos principais alterados

- `lib/features/repositories/presentation/repository_run_details.dart`
- `lib/features/repositories/presentation/repository_run_details_controller.dart`
- `lib/features/repositories/presentation/repository_run_details_widgets.dart`
- `lib/features/repositories/presentation/repository_artifacts_screen_actions.dart`
- `lib/features/builds/presentation/global_builds_screen.dart`
- `lib/features/repositories/presentation/repository_detail_screen.dart`
- `lib/features/builds/domain/apk_variant.dart`
- `lib/features/downloads/data/download_manager_service.dart`
- `lib/features/downloads/domain/managed_download.dart`
- `lib/core/platform/platform_actions.dart`
- `android/app/src/main/kotlin/br/com/githubmanager/app/MainActivity.kt`
- `lib/features/settings/presentation/settings_screen.dart`
- `lib/features/settings/presentation/settings_widgets.dart`

## Versão

- versionName: `2.0.106`
- versionCode: `200120`
