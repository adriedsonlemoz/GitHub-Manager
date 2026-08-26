# GitHub Manager 2.0.13 (200027)

## Organização dos downloads

Todos os arquivos vinculados a um repositório passam a ser publicados em uma pasta própria no armazenamento público:

`Downloads/GitHub/<Projeto>/`

Isso vale para APKs, logs, ZIPs, artifacts e arquivos públicos baixados pelo GitHub Manager.

O nome da pasta é derivado do repositório e convertido para formato legível, por exemplo:

- `GitHub-Manager` → `GitHub Manager`
- `Social-Lite` → `Social Lite`

## ZIP do projeto

O ZIP não usa mais apenas `projeto-main.zip`.

O nome passa a incluir:
- nome do projeto;
- versão, quando detectada;
- data e hora do download;
- branch.

Exemplo:

`GitHub-Manager-v2.0.13-20260826-171530-main.zip`

Isso facilita identificar diferentes cópias do mesmo projeto.

## Cabeçalho do repositório

- SliverAppBar fixo agora possui fundo sólido.
- Conteúdo rolado não aparece mais visualmente por trás do título.
- Títulos longos usam reticências em vez de se sobrepor aos ícones.

## Status da Build

O status `Build em execução`, `Última build OK`, `Última build falhou` e `Sem builds` agora usa o mesmo componente visual de badge/card empregado em versão e branch, com ícone próprio.

## Base preservada

Mantém todas as correções anteriores, inclusive notificações, Acompanhados, Fork, seleção múltipla de artifacts, exclusões e Central de Downloads.

## Validação

- Estrutura Dart verificada.
- Workflows YAML validados.
- pubspec.yaml validado.
- AndroidManifest.xml validado.
- Kotlin revisado estruturalmente.
- JSON/versionamento validados.
- ZIP final testado quanto à integridade.

A compilação final deve ser confirmada pelo GitHub Actions.
