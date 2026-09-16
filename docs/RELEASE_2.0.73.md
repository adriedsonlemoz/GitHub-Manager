# GitHub Manager 2.0.73

Versão: `2.0.73+200087`

## Correção dos builds 63

- Corrigido o erro de análise em `build_cleanup_service_test.dart` que impedia tanto a CI quanto o workflow Android APK de avançarem.
- O objeto `leftover` usado nas listas `const` agora é uma constante em tempo de compilação, compatível com os literais `const [leftover]`.
- Removido um import não utilizado no teste de GitHub Secrets.
- Nenhum comportamento de exclusão de builds/APKs/artifacts foi alterado; a correção é restrita ao código de teste/validação.

## Diagnóstico

Os dois logs 63 falhavam em `flutter analyze` antes da execução dos testes/Gradle com `non_constant_list_element` nas linhas 83 e 84 de `test/build_cleanup_service_test.dart`.
