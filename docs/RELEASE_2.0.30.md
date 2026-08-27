# GitHub Manager 2.0.30+200044

## Alterações

- aplica o novo padrão visual azul-preto e índigo à Home de repositórios e ao tema compartilhado;
- redesenha cartões de repositório, pesquisa, filtros, ações e navegação inferior;
- mantém as funções existentes e a arquitetura Riverpod/serviços;
- corrige falso bloqueio de envio causado por acentos e separadores diferentes no nome do projeto;
- adiciona confirmação de identidade Android via Gradle quando `applicationId` não existe nos metadados de raiz;
- adiciona teste de regressão para `Tática Manager` versus `TaticaManager`.

## Segurança

A validação continua bloqueando ZIPs quando há `applicationId` comparável e diferente. A flexibilização vale somente para equivalência textual de nomes após normalização de acentos e separadores.
