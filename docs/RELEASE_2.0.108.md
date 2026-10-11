# GitHub Manager 2.0.108+200122

## Destaque

- **Configurações > Aparência > Tela inteira**: alterna entre modo imersivo e barras do sistema visíveis.
- O modo imersivo continua ativado por padrão, preservando o comportamento da 2.0.107.
- A escolha é salva no banco local, reaplicada ao reabrir/retomar o app e após fechar o teclado, quando necessário.
- Para exibir as barras do Android, usa `SystemUiMode.edgeToEdge`, respeitando as áreas seguras do Flutter.
- Em Android 15/16, o modo imersivo pode não ser aplicado dependendo do `targetSdk` e das restrições da plataforma. Não há promessa de ocultar barras em todos os aparelhos.

## Arquivos principais

- `lib/core/platform/system_ui_settings.dart`
- `lib/main.dart`
- `lib/features/settings/presentation/settings_screen.dart`
- `lib/features/settings/presentation/settings_screen_actions.dart`
- `lib/features/update/presentation/update_whats_new_screen.dart`
- `test/system_ui_settings_contract_test.dart`

## Versão

- versionName: `2.0.108`
- versionCode: `200122`
- versão canônica: `pubspec.yaml` (`2.0.108+200122`).
