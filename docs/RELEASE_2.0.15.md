# GitHub Manager 2.0.15 (200029)

## GitHub Releases

- APKs gerados em Artifacts agora possuem a ação `Publicar versão`.
- O GitHub Manager sugere automaticamente a tag a partir da versão encontrada no nome do artifact.
- É possível editar tag, título e notas da versão antes de publicar.
- Opções para definir como versão mais recente e marcar como pré-lançamento.
- O app baixa o artifact, localiza o APK, cria a Release e envia o APK como asset.
- Se a criação da Release acontecer mas o envio do APK falhar, o app tenta remover a Release incompleta.
- Depois da publicação, a Release passa a aparecer na própria área de Releases públicas.
- Repositórios acompanhados continuam exibindo Releases para download, sem permissão de escrita.

## Permissões

Publicar Releases requer permissão de escrita no conteúdo do repositório pelo token GitHub conectado.

## Base preservada

Mantém seleção múltipla de Actions, Artifacts, downloads por projeto, notificações, Fork e demais melhorias anteriores.

## Validação

- Estrutura Dart verificada.
- Workflows YAML validados.
- pubspec e AndroidManifest válidos.
- Versionamento sincronizado.
- ZIP final testado quanto à integridade.

A compilação final deve ser confirmada pelo GitHub Actions.
