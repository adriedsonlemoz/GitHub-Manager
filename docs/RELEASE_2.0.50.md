# GitHub Manager 2.0.50

Versão: `2.0.50+200064`

## Correção do assistente de configuração

- Corrige a mensagem enganosa exibida quando o GitHub responde `401` ao teste do Personal Access Token em `/user`. O app agora informa que o token foi rejeitado e que pode estar expirado, revogado ou copiado incorretamente, em vez de dizer apenas que a conta não está conectada.
- Normaliza o PAT antes da validação e do armazenamento seguro, removendo whitespace acidental, quebras de linha, caracteres invisíveis, aspas/backticks e prefixos de cabeçalho como `Bearer` e `Authorization: Bearer`.
- O botão `Colar` do assistente usa a mesma normalização, evitando que formatação trazida pelo clipboard gere `401` com um token válido.
- O campo do token passa a aceitar a ação de teclado `Concluir` para disparar `Testar e conectar`.
- Adiciona testes unitários para os principais formatos de colagem/normalização do token.

## Segurança

O valor do PAT nunca é incluído em mensagens de erro, documentação ou logs. O token só é salvo depois de `/user` responder com sucesso.

## Compatibilidade

Não altera `applicationId`, assinatura Android, permissões dos repositórios, banco local, filas de upload/download ou formato dos checkpoints.
