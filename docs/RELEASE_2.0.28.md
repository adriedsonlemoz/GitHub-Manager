# GitHub Manager 2.0.28+200042

## Pré-checagem de permissões

- Enviar build verifica previamente Contents/Workflows e Actions.
- Criar, substituir, importar e excluir Secrets verifica previamente Secrets.
- Exclusão permanente de repositório verifica previamente a capacidade de exclusão.
- Bloqueios confirmados mostram a permissão ausente e oferecem acesso direto ao Diagnóstico do token.
- PAT fine-grained inconclusivo não é bloqueado preventivamente.
- O diagnóstico é reutilizado por até 3 minutos; a chave inclui fingerprint SHA-256 do token apenas em memória.
- Trocar o token invalida efetivamente o cache sem persistir nem expor o token.
- Rate limit e indisponibilidade do diagnóstico não são confundidos com permissão negada.
- Novos testes cobrem build, Secrets, exclusão, cache e troca de token.
