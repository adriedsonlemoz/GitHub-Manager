# GitHub Manager 2.0.59

Versão: `2.0.59+200073`

## Dados remotos sem cache

- Remove cache persistente de repositórios e perfil do GitHub.
- A lista de repositórios consulta `/user/repos` diretamente.
- Acompanhados mantém localmente apenas as referências escolhidas; os dados são resolvidos novamente pela API.
- Permissões são diagnosticadas novamente a cada verificação.
- Providers de dados remotos usam `autoDispose`.
- Snapshots remotos legados são apagados automaticamente do SQLite no startup.
- Dados locais próprios do app, como preferências, filas, históricos e estado operacional, continuam persistidos.
