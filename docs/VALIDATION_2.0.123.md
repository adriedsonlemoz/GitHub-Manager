# Validação 2.0.123

## Fonte do diagnóstico

- `GitHub-Manager-Android-APK-112-logs.zip`, etapa `Analisar código antes do APK`.
- 5 erros `argument_type_not_assignable` em `test/static_web_project_detection_test.dart`, linhas 10 a 14.
- 1 aviso `unnecessary_non_null_assertion` na linha 15.

## Correções

- Converte o conteúdo dos `ArchiveFile` para `List<int>` com `utf8.encode()`.
- Usa tamanho de bytes real e elimina `!` desnecessário em `ZipEncoder().encode()`.
- Acrescenta cobertura para um site estático sem CSS/JS adicional.

## Verificações e limites

- Verificação de consistência pelo script `tool/check_version_sync.sh`.
- Inspeção de JSON/YAML, integridade ZIP e checagem de assinaturas do construtor nos testes.
- Não foi possível executar `flutter analyze`, `flutter test` ou compilar APK localmente, porque Flutter/Dart não estão instalados. A CI precisa confirmar a correção.
