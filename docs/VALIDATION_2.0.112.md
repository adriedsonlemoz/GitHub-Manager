# Validação da versão 2.0.112

## Inspeção local

- `bash tool/check_version_sync.sh` para versão e documentação.
- Testes de contrato adicionados em `test/builds_ui_112_contract_test.dart` e parser em `test/workflow_error_location_test.dart`.
- Integridade do ZIP; inspeção estática de strings e artefatos.

## Rodar em ambiente Flutter

```sh
flutter pub get --enforce-lockfile
dart format lib test
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test
flutter build apk --release
```

## Testes manuais essenciais

1. Na aba Builds, abrir a lupa e fechar sem alterar status/histórico; abrir filtro de branch/workflow/período.
2. Em uma build sem APK, botão APK deve mostrar progresso e resultado explícito. Testar erro 403/404 em apenas uma das fontes e conferir que a outra aparece.
3. Dentro dos detalhes de uma execução, conferir progresso visível no botão APK e bloqueio de múltiplos toques.
4. Nos Downloads, conferir nome curto, Compartilhar/Excluir por ícones e detalhes com nome físico completo.
5. Prévia de ZIP com arquivos adicionados, alterados e removidos: pastas recolhíveis, caminhos copiáveis e exclusão visível.
6. Build falha com annotation `path`, `start_line`: conferir localização; log Dart/Kotlin/Python: conferir indicação “Detectado no log”; para resumo sem linha: não inventar arquivo.
7. Usar link apenas quando caminho relativo seguro e SHA da execução válidos.

Sem SDK Dart/Flutter neste ambiente, não declarar compilação ou testes Flutter aprovados apenas pela inspeção local.
