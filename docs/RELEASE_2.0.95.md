# GitHub Manager 2.0.95+200109

Correção de estabilidade da CI e dos testes do seletor de branch.

## Correções

- contrato de repositório vazio tolera whitespace/formatação;
- teste do seletor aguarda a lista por estado real, sem atraso fixo;
- botão **Outras branches** possui chave estável para automação;
- CI verifica formatação sem modificar `lib/` ou `test/` antes da análise e da suíte;
- teste de regressão impede a reintrodução da mutação de fontes no workflow.

## Versão

- versionName: `2.0.95`
- versionCode: `200109`
