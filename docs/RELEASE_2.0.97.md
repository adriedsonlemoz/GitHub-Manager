# GitHub Manager 2.0.97+200111

## Exclusões verificáveis e leitura mais rápida

Esta versão melhora quatro pontos observados no uso real do aplicativo: feedback ao excluir Builds, limpeza de APKs antigos, exclusão física de Downloads e abertura de READMEs grandes. A Home também fica mais compacta.

### Mudanças

- Builds exibem etapa, “N de total” e porcentagem de exclusão;
- limpeza de APKs antigos usa os itens já carregados na tela;
- Downloads só somem da Central depois de o Android confirmar a remoção física;
- botão de download passa a dizer **Excluir do aparelho**;
- descrição deixa de ocupar espaço nos cards da Home;
- pesquisa vira uma lupa compacta no topo;
- README usa cache em memória, decodificação em isolate para arquivos grandes e renderização lazy;
- cobertura adicionada para o progresso em lote.

## Identidade Android

- applicationId: `br.com.githubmanager.app`
- versionName: `2.0.97`
- versionCode: `200111`

A fonte canônica continua sendo `pubspec.yaml`, espelhada em `github-manager.json`.
