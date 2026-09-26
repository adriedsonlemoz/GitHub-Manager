# Validação — GitHub Manager 2.0.99+200113

## Escopo

- redução visual do raio dos cards da lista de projetos;
- tela de novidades exibida somente no primeiro acesso de cada versão;
- sincronização de identidade e documentação.

## Verificações executadas neste ambiente

- `tool/check_version_sync.sh`: valida `pubspec.yaml` contra `github-manager.json`;
- inspeção de referências da versão atual em código/documentação;
- verificação estrutural do ZIP final e ausência de APK dentro do pacote;
- contratos adicionados em `test/update_whats_new_contract_test.dart`.

## Limitação do ambiente

Flutter/Dart não estão instalados neste ambiente, portanto `flutter analyze` e `flutter test` não podem ser executados localmente. Os testes permanecem no projeto para execução pela CI/GitHub Actions.
