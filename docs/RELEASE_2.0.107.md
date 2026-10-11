# GitHub Manager 2.0.107+200121

## Destaque

- **Configurações > Página inicial > Mostrar descrição dos repositórios**: permite exibir a descrição completa cadastrada no GitHub abaixo do nome de cada repositório na Home.
- O texto é renderizado sem `maxLines` e sem corte por número de caracteres, usando quebra de linha automática.
- O ajuste inicia desabilitado, não modifica dados no GitHub e fica salvo localmente.
- Os cartões atualizam após mudanças de preferência via Riverpod.

## Arquivos principais

- `lib/features/repositories/data/repository_description_settings.dart`
- `lib/features/repositories/presentation/repository_providers.dart`
- `lib/features/repositories/presentation/repository_card.dart`
- `lib/features/settings/presentation/settings_screen.dart`
- `lib/features/settings/presentation/settings_screen_actions.dart`
- `lib/features/update/presentation/update_whats_new_screen.dart`
- `test/repository_description_settings_contract_test.dart`
- `test/update_whats_new_contract_test.dart`

## Versão

- versionName: `2.0.107`
- versionCode: `200121`
- versão canônica em `pubspec.yaml`: `2.0.107+200121`.
