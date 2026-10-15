# GitHub Manager 2.0.126+200140

Data: 15/10/2026. VersionCode Android: 200140.

## Causa e correção do Android APK #115

O GitHub Actions terminou `flutter analyze` sem erros fatais. Durante `flutter test`, 227 testes passaram e 1 falhou: o teste `test/build_apk_selection_contract_test.dart` ainda exigia consultas diretas a Releases/Artifacts e resolução da última versão em `repository_detail_screen_actions.dart`.

Desde a 2.0.125, o fluxo efetivo passa por `repositoryApkStatusProvider`, responsável por consultar as duas fontes de forma independente, resolver a última versão e combinar a informação com o estado do app instalado no Android.

**Correção:** atualizamos o teste de contrato para conferir o fluxo real, incluindo a presença das duas consultas, suas falhas independentes, a resolução de versão, a avaliação de instalação, o seletor de arquiteturas e a inicialização do download. A lógica de produção não foi alterada.

## Mantido

- Botão APK do repositório com download direto da última versão e seleção de ABI.
- Verificação de aplicativo instalado com estados Instalar/Atualizar/Atualizado/Desconhecido.
- Recuperação dos downloads e verificações de integridade.

## Validação pendente

É necessário executar `flutter analyze`, `flutter test` e build Android no GitHub Actions. A compilação do APK foi interrompida antes de começar na execução #115.
