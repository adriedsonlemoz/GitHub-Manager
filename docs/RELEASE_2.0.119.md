# GitHub Manager 2.0.119+200133

## Correção da CI #107 e Android APK #108

- Ambos os workflows da v2.0.118 pararam em `flutter test` após **200 testes aprovados e 3 falhos**; nenhuma compilação de APK ocorreu.
- `test/global_builds_screen_test.dart`: asserções adaptadas ao texto atual da tela: `Android APK • execução #78` e `Verificação do Projeto (CI) • execução #78`.
- `test/workflow_log_naming_contract_test.dart`: diagnósticos explícitos se `.github/workflows/ci.yml` ainda estiver presente; continuam verificando que Android APK e Android Release executam análise e testes.
- `ci.yml` permanece ausente do ZIP. **O repositório remoto deve apagar explicitamente o arquivo antigo** para deixar de executar uma CI independente, pois uploads incrementais podem preservar arquivos não incluídos no pacote.
- Nenhuma regra de autenticação, assinatura Android, transferência ou exclusão foi modificada. Versão, changelog e interface de Novidades sincronizados.

## Validação pendente

Executar `bash tool/check_version_sync.sh`, `flutter analyze --no-pub --no-fatal-infos --no-fatal-warnings`, `flutter test --no-pub` e workflow Android APK no GitHub. A versão 2.0.119 ainda não foi compilada/testada em Android aqui.
