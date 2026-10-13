# Validação 2.0.121

## Critérios estáticos

- `bash tool/check_version_sync.sh` sem divergências (pubspec, JSON, Novidades, Configurações, README, CHANGELOG e RELEASE).
- `ci.yml` legado segue inativo; arquivos YAML e JSON válidos.
- Detalhe da build mostra Evento + Branch no mesmo contêiner e move commitMessage para Detalhes técnicos.
- Downloads utilizam média móvel de cinco segundos e limitam notificações da UI; reconexão preserva tamanho parcial e respeita cancelamento.
- Content-Range 206 precisa começar no byte solicitado e o stream não pode finalizar com menos bytes que o comprimento HTTP conhecido.

## CI e Android (executar após enviar ao GitHub)

```sh
flutter pub get --enforce-lockfile
bash tool/check_version_sync.sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --release
```

Testes no aparelho: transferir APK grande em Wi-Fi bom e fraco; alternar rede para provocar erro e retomada; cancelar durante retentativa; comparar tamanho/SHA-256 com asset remoto; verificar largura estreita e acessibilidade do cartão novo. Não inventar resultados de CI.
