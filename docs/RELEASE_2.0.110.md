# GitHub Manager 2.0.110+200124

## Novidades

- Confirmação de envio simplificada: repositório, branch, versões, resumo de alterações e avisos prioritários. Detalhes técnicos recolhidos.
- A prévia de arquivos continua disponível; arquivos removidos recebem destaque.
- Novo diagnóstico de identificação com explicação para versão ausente no ZIP/GitHub, nome em modo alternativo, falha de consulta e divergências, com cópia do relatório sem credenciais.
- Identificação adicional do nome de exibição de projetos Android por `AndroidManifest.xml` e `strings.xml` quando não há nome explícito.
- Preservada a validação de permissão, a escolha da branch, a proteção de workflows e a confirmação forte de envio a projeto diferente.

## Versionamento

- `versionName`: `2.0.110`
- `versionCode`: `200124`
- Fonte canônica: `pubspec.yaml` (`2.0.110+200124`).

## Homologação

A estrutura foi revista e o ZIP pode ser validado estaticamente. Flutter/Dart não estão disponíveis neste ambiente; executar `dart format lib test`, `flutter analyze`, `flutter test` e `flutter build apk --release` antes de publicar. Testar especialmente o diálogo em telefone pequeno e a identificação de Manifest/strings em repositórios Android reais.
