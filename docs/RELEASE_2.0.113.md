# GitHub Manager 2.0.113+200127

## Correção

- **CI #102** e **Android APK #103**: `185 tests passed, 1 failed` por `Bad state: No element` no teste de busca de builds.
- O campo `builds-search` é montado apenas após tocar em **Buscar builds** (lupa), desde a v2.0.112. O teste agora reproduz o fluxo real, inclusive validando estados fechado e aberto.
- Interface e lógica de negócios preservadas; não houve alteração no serviço de builds, na busca real nem na seleção de APKs.

## Versão

- versionName: `2.0.113`
- versionCode: `200127`
- Fonte canônica: `pubspec.yaml`, `version: 2.0.113+200127`.

## Verificação

Ver `docs/VALIDATION_2.0.113.md`. A validação completa com Flutter/Dart exige CI ou uma máquina com o SDK instalado.
