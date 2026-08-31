# GitHub Manager 2.0.58

Versão: `2.0.58+200072`

## Listagem e cache

- Cache local continua abrindo a lista imediatamente, inclusive offline.
- A resposta mais recente de `/user/repos` passa a ser a fonte visual autoritativa sem invalidar a tela inteira.
- Criar, editar, renomear, excluir e criar fork atualizam os cards localmente no mesmo instante.
- Ao voltar da tela de detalhes, a lista faz reconciliação silenciosa com o GitHub.
- Acompanhados também atualiza seu snapshot local ao adicionar/remover itens, evitando inconsistência entre as duas abas.
- Descrição, privacidade, arquivamento, nome e demais metadados deixam de depender de um snapshot antigo enquanto a tela permanece aberta.
- `GitHubRepository` ganhou igualdade/hash por valor, evitando providers de metadados duplicados a cada reconstrução da mesma lista e permitindo renovar versão/tecnologias quando os dados realmente mudam.

A atualização preserva o comportamento offline: falha de rede mantém a última lista válida em vez de apagar os cards.
