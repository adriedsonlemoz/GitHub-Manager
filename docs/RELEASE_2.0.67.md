# GitHub Manager 2.0.67

Versão: `2.0.67+200081`

## Correção da falha ao carregar repositórios após atualização

A falha observada era compatível com estado local/SQLite, não com os dados dos repositórios no GitHub. A listagem principal chamava a reconciliação de projetos fixados depois de baixar os repositórios; qualquer erro nessa tabela local fazia a tela inteira falhar e exibia apenas mensagens genéricas.

Também havia dois riscos estruturais: o banco continuava com `version: 1` apesar da evolução do esquema, sem `onUpgrade`, e diferentes serviços abriam/fechavam `LocalDatabase` independentes enquanto o `sqflite` podia reutilizar a mesma conexão por padrão.

## Proteções adicionadas

- esquema SQLite elevado para 2;
- `onCreate`, `onUpgrade` e `onOpen` garantem tabelas/índices com operações idempotentes;
- `singleInstance: false` faz cada wrapper de banco possuir sua própria conexão e evita fechamento cruzado;
- falha na reconciliação de projetos fixados não bloqueia mais a lista remota de repositórios;
- JSON local malformado é removido apenas na chave afetada;
- Configurações > Diagnóstico de dados locais verifica `PRAGMA quick_check`, repara o esquema e, se necessário, oferece reconstrução somente do SQLite;
- reconstrução local preserva o token GitHub, armazenado separadamente no `flutter_secure_storage`;
- ajuda do aplicativo orienta o usuário a usar o diagnóstico em vez de limpar todos os dados do Android.

## Objetivo

Atualizações futuras não devem exigir “Limpar dados” para corrigir mudança de esquema local. Uma falha auxiliar de cache/favoritos também não deve tornar indisponíveis os repositórios já retornados pela API do GitHub.
