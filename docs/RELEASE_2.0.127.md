# GitHub Manager 2.0.127+200141

Data: 15/10/2026. Android versionCode: 200141.

## Origem

Workflow Android APK #116: etapa de análise Dart concluída sem erros fatais, `flutter test` encerrou com 227 aprovações e uma falha em `test/system_ui_settings_contract_test.dart`, linha 53. A compilação APK não começou.

## Causa

O teste exige que **Configurações → Últimas 3 mudanças** liste as versões sequenciais mais recentes, em ordem decrescente. A UI exibia `2.0.126`, `2.0.124`, `2.0.125` em vez da sequência correta `2.0.126`, `2.0.125`, `2.0.124`.

## Correção

- A 2.0.127 mostra **2.0.127, 2.0.126, 2.0.125**, na ordem correta, com descrições pertinentes.
- Mantém o teste de regressão que usa a versão canônica do `pubspec.yaml` e compara com o histórico.
- Nenhuma alteração no código de downloads, APK, instalação ou build.
- Metadados Android e notas de versão sincronizados.

## Validação pendente

Após envio à branch correta, executar `flutter analyze`, `flutter test` e o workflow Android APK no GitHub Actions. Não foi possível compilar Flutter/Android localmente neste ambiente.
