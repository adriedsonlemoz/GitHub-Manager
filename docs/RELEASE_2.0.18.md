# GitHub Manager 2.0.18 (200032)

## Trava contra envio do projeto errado

Antes de sincronizar um ZIP, o GitHub Manager agora analisa a identidade interna do projeto e compara com o repositório aberto.

São considerados, quando disponíveis:

- nome interno do projeto;
- package do projeto;
- applicationId/namespace Android;
- versão;
- versionCode.

Comportamento:

- identidade incompatível: envio bloqueado;
- versão do ZIP anterior à versão do GitHub: envio bloqueado;
- mesma versão: aviso forte e envio continua disponível somente após confirmação;
- identidade incompleta: aviso para conferência manual;
- projeto compatível e versão nova: confirmação verde.

O popup mostra lado a lado projeto/versão do ZIP e projeto/versão existentes no GitHub.

## Versão nas Builds

- As execuções recentes tentam obter a versão diretamente dos arquivos do commit que está sendo compilado.
- São consultadas fontes como `github-manager.json`, `app.json`, `pubspec.yaml` e `VERSION`.
- A versão aparece no grupo da atualização, no card da execução e no detalhe da Build.
- Novos commits feitos pelo envio de ZIP registram também projeto e versão na mensagem automática do commit, junto da data/hora com segundos.
- O resultado fica armazenado em cache durante a sessão para evitar consultas repetidas ao GitHub.

## Tela inicial

- O cabeçalho superior foi reforçado como uma barra sólida e opaca.
- Conteúdo, filtros e cards não aparecem por trás do título ao rolar.
- Adicionados recorte, elevação e divisor inferior para separar visualmente a barra do conteúdo.

## Validação

- Estrutura Dart verificada.
- Workflows YAML validados.
- pubspec.yaml, AndroidManifest e JSON validados.
- Sincronização de versão validada.
- ZIP final testado quanto à integridade.

A compilação final deve ser confirmada pelo GitHub Actions.
