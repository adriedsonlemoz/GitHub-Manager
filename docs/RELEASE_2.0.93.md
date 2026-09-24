# GitHub Manager 2.0.93+200107

## Objetivo

Reduzir esperas sem feedback no seletor de branch, preparação de envio e abertura da tela Projeto.

## Alterações

- seletor de branch compacto, centralizado e carregado de forma assíncrona;
- botão Criar e lista recolhível de outras branches;
- timeout e retry para branches e carregamento do repositório;
- preparação do envio com feedback de etapa;
- consultas auxiliares da confirmação executadas em paralelo;
- cache somente em memória para abrir repositórios já listados sem uma segunda espera;
- shell de carregamento progressivo quando ainda não existe cache;
- atualização silenciosa do snapshot remoto em segundo plano.

## Versão

- versionName: `2.0.93`
- versionCode: `200107`
