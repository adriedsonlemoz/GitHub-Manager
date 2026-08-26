# GitHub Manager 2.0.16 (200030)

## Avisos centralizados

- Criado um componente único de aviso no centro da tela.
- Removidos os SnackBars inferiores das telas do GitHub Manager.
- Mensagens de sucesso, informação e erro agora aparecem centralizadas.
- O componente usa ícone e estilo visual diferente conforme o tipo da mensagem.
- Criação, atualização e exclusão de repositório exibem confirmação centralizada.
- Remoção de repositório acompanhado também recebe confirmação centralizada.
- Avisos de arquivos, Actions, artifacts, downloads, Secrets, Bugs, configurações e assistente de configuração foram migrados para o mesmo padrão.

## Enviar build

- O diálogo de envio agora mostra progresso real com base nos arquivos processados.
- Exibe quantidade `atual / total`.
- Exibe porcentagem quando o total é conhecido.
- Mostra o nome do arquivo atualmente processado.
- A barra passa a avançar conforme o projeto é processado.
- Adicionado bloco `Processo` com as últimas etapas do envio.
- Etapas como preparação da branch, processamento dos arquivos, remoção de arquivos antigos, criação do commit e confirmação da build ficam visíveis.
- Projetos grandes deixam de parecer travados durante a sincronização.

## Base preservada

Mantém GitHub Releases, seleção múltipla em Actions e Artifacts, notificações em segundo plano, Acompanhados, Fork, downloads organizados por projeto e demais melhorias anteriores.

## Validação

- Nenhum `SnackBar` restante em `lib/`.
- Estrutura Dart verificada.
- Workflows YAML validados.
- pubspec.yaml e AndroidManifest.xml validados.
- JSON/versionamento sincronizados.
- ZIP final testado quanto à integridade.

A compilação final continua dependendo do GitHub Actions.
