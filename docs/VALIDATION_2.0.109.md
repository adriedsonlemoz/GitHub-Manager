# Validação 2.0.109

## Verificações disponíveis

- Integração estática dos filtros, histórico, comparação, diagnóstico e proteção de Releases.
- Conferência de `versionName` / `versionCode`, README, CHANGELOG, VERSIONING, Novidades e notas de Release.
- Testes adicionados/atualizados: `global_builds_enhancements_test.dart`, `global_builds_service_cache_test.dart`, `build_cleanup_service_test.dart`.
- ZIP: teste de CRC/estrutura via `unzip -t`.

## Verificações não realizadas

- `flutter analyze`, `flutter test` e `flutter build apk`, pois Flutter/Dart SDK não está instalado neste ambiente.
- Testes reais de consulta GitHub Actions/limites de API, diagnóstico com ZIP de logs e layout em aparelho Android.

## Critérios para homologação

1. Rodar `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze`, `flutter test` e `flutter build apk --release` na CI.
2. Conferir histórico com múltiplas execuções e commits diferentes no mesmo repositório.
3. Validar filtros em projeto com vários workflows e branches; testar sem rede/restrições de Actions.
4. Testar duração em builds finalizadas e em execução; verificar a ausência de percentuais artificiais.
5. Excluir build que compartilha SHA com uma Release e confirmar que os APKs publicados na Release **não são removidos**.
6. Testar diagnóstico com steps e annotations, inclusive ausência de permissão para logs.
