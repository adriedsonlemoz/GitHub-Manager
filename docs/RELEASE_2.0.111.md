# GitHub Manager 2.0.111+200125

## Objetivo

Desbloquear os testes que impediram a geração do APK nos jobs CI #100 e Android APK #101. Mudanças de manutenção, sem novas permissões nem alterações nos fluxos de envio, builds ou downloads.

## Correções

- `repository_detail_widgets.dart`: raio de 6 px → 4 px na prévia de sincronização; remove banner de versão não utilizado.
- `repository_detail_screen_actions.dart`: raio de 5 px → 4 px no aviso de identidade.
- `system_ui_settings_contract_test.dart`: verifica as três versões recentes calculadas a partir da versão canônica, sem expectativas fixas que expiram a cada release.
- `upload_identification_diagnosis_test.dart`: alinha o rótulo para `Versão no GitHub`, preservando a terminologia usada na confirmação e no relatório.
- `update_whats_new_contract_test.dart`: mantém testes de versão, confirmação explícita e itens sem amarrar o contrato a títulos de releases anteriores.
- `tool/check_version_sync.sh`: valida também a sincronização da versão em UI e documentação.

## Versionamento

- `versionName`: `2.0.111`
- `versionCode`: `200125`
- Fonte canônica: `pubspec.yaml` (`2.0.111+200125`).

## Homologação

Veja `docs/VALIDATION_2.0.111.md`. Compilação Android e `flutter test` precisam ocorrer em ambiente com Flutter 3.47.1 e Dart compatível. Não afirmar aprovação de APK apenas por validação estática.
