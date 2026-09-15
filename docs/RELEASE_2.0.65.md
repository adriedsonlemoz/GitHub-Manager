# GitHub Manager 2.0.65

Versão: `2.0.65+200079`

## Projetos fixados e organização

- Ativa a tabela `favorite_repositories` já existente no SQLite.
- Adiciona **Fixar no topo** e **Desafixar do topo** ao gerenciamento do repositório.
- Projetos fixados ficam antes dos demais e recebem indicador discreto no card.
- Adiciona o filtro **Fixados**.
- Adiciona ordenação por **Mais recentes**, **Mais antigos**, **Nome A–Z**, **Maiores** e **Menores**.
- A fixação usa `repository_id`, é preservada em renomeações e referências órfãs são removidas após uma listagem válida.

## Lista mais leve

- Os cards usam uma leitura resumida de nome/versão.
- A listagem deixa de consultar linguagens e todos os metadados completos quando só precisa renderizar o card.
- A análise completa continua nas telas internas, preservando tecnologias, package/applicationId e versionCode.

## Documentação

- README, AI_HANDOFF, VERSIONING e `github-manager.json` sincronizados com 2.0.65.
