# GitHub Manager 2.0.64

Versão: `2.0.64+200078`

## Tamanho dos projetos

- Passa a ler o campo `size` retornado pela API REST do GitHub para cada repositório.
- Exibe o tamanho do repositório ao lado da versão no card, com conversão automática entre KB, MB e GB.
- Exibe abaixo de **Meus repositórios** a quantidade total de projetos e a soma dos tamanhos informados pelo GitHub.
- O resumo considera a lista completa de Meus repositórios, independentemente da busca ou filtro visual ativo.
- Não adiciona chamadas extras por projeto: os dados vêm da mesma resposta usada para montar a lista.
- O tamanho representa o valor informado pelo GitHub para o repositório, não o espaço de uma pasta extraída no aparelho.
