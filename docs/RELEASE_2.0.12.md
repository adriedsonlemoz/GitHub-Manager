# GitHub Manager 2.0.12 (200026)

## Correção dos logs CI #10 / Android APK #10

Os dois workflows falharam em `flutter pub get` pelo mesmo motivo:

- `flutter_local_notifications 20.1.0` ainda dependia de `xml 6.x` por meio do suporte Windows;
- o GitHub Manager utiliza `xml 7.x`.

A versão foi atualizada para `flutter_local_notifications ^22.3.0`, exatamente a faixa indicada pelo resolvedor do Flutter para compatibilidade com o projeto. As chamadas usadas pelo GitHub Manager já seguem a API atual com parâmetros nomeados.

## Artifacts

- Adicionado modo `Selecionar`.
- É possível selecionar vários artifacts individualmente.
- Toque prolongado também inicia a seleção.
- Adicionado `Selecionar todos`.
- Adicionado `Excluir selecionados`, com confirmação de exclusão permanente.
- Mantidas exclusão individual e limpeza dos APKs anteriores.

## Detalhe da Build

- Ações finais reorganizadas em uma única linha.
- Nomes reduzidos para `Logs`, `Repetir`, `APK` e `Excluir`.
- `Excluir execução` passou a ser apenas `Excluir`, acompanhado por ícone de lixeira.
- Botões usam layout compacto com ícone sobre o nome para caber melhor em telas estreitas.

## Base preservada

Mantém notificações em segundo plano, Acompanhados com cache, Colar URL, Fork, exclusão de runs/artifacts, Releases públicas, refresh sem piscar e demais correções anteriores.

## Validação

- Logs CI #10 e Android APK #10 analisados.
- Estrutura Dart verificada.
- Workflows YAML validados.
- pubspec.yaml válido.
- AndroidManifest.xml válido.
- JSON e versionamento validados.
- ZIP final testado quanto à integridade.

A compilação final deve ser confirmada pelo próximo GitHub Actions.
