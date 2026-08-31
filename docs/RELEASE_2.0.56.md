# GitHub Manager 2.0.56

Versão: `2.0.56+200070`

## Correção principal

- A listagem de repositórios passa a manter a última lista renderizada enquanto o provider é invalidado/recarregado.
- Criar, editar, renomear, excluir e reconciliar com o GitHub não apagam mais os cards para mostrar um spinner central.
- O loading de tela inteira fica restrito à primeira carga quando ainda não existe lista disponível.
- Em falhas de reconciliação automática, a lista anterior continua utilizável.
