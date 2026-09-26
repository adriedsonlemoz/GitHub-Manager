# GitHub Manager 2.0.99+200113

## Objetivo

Refinar visualmente a Home e informar as mudanças de cada atualização sem repetir o aviso em todos os acessos.

## Alterações

- cards da lista **Meus repositórios** com raio reduzido de 22 px para 4 px apenas nessa tela;
- nova tela completa **Novidades da atualização**;
- exibição automática depois do primeiro frame somente quando a versão instalada ainda não foi apresentada;
- persistência da versão já vista no SQLite pela chave `app.whats_new.last_seen_version`;
- a versão é marcada como apresentada assim que a tela abre; o botão **Continuar** fecha o resumo e retorna ao aplicativo;
- tratamento com timeout/falha controlada para que a novidade nunca atrase ou impeça o startup;
- Configurações, README, CHANGELOG, VERSIONING e AI_HANDOFF sincronizados.

## Identidade

- versionName: `2.0.99`
- versionCode: `200113`
