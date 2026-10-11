# Validação da versão 2.0.113

## Base dos logs recebidos (2026-10-11)

- CI #102: 185 testes aprovados, 1 falha.
- Android APK #103: 185 testes aprovados, 1 falha (o build do APK não começou).
- Única falha: `test/global_builds_enhancements_test.dart` na chamada `enterText()` da linha 62, lançando `StateError: Bad state: No element`.
- Causa: a busca foi recolhida atrás da lupa na v2.0.112, mas o teste ainda esperava `builds-search` montado antes do toque.
- Os 73 apontamentos informativos do `flutter analyze --no-fatal-infos --no-fatal-warnings` não foram a causa da interrupção.

## Verificações

```bash
bash tool/check_version_sync.sh
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub --no-fatal-infos --no-fatal-warnings
flutter test --no-pub test/global_builds_enhancements_test.dart
flutter test --no-pub
flutter build apk --release
```

O workflow existente usa `dart format` como aviso não fatal. A compilação Android depende de todas as etapas anteriores aprovadas. Não declarar aprovação dos testes e do APK antes de executar os comandos em um ambiente Flutter.
