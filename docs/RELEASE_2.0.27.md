# GitHub Manager 2.0.27+200041

## Diagnóstico de permissões do token

- nova tela por repositório próprio;
- teste seguro somente com consultas GET;
- Contents, Actions, Secrets, Administration e exclusão;
- sincronização por ZIP destaca também `Workflows: write`;
- PAT clássico usa escopos `repo`, `workflow` e `delete_repo` quando expostos pelo GitHub;
- PAT fine-grained mostra as permissões necessárias sem executar mutações para tentar descobrir permissões de escrita;
- usa `X-Accepted-GitHub-Permissions` para explicar falhas de leitura;
- considera o papel da conta no repositório;
- relatório copiável sem token;
- novos testes para os principais cenários de permissão.
