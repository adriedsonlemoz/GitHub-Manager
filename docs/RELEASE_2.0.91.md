# GitHub Manager 2.0.91+200105

Data: 2026-09-24

## Correção

Os jobs GitHub Manager CI #80 e Android APK #81 encerraram normalmente e mostraram uma única falha: o teste do seletor de branch encontrava `develop`, mas o item estava fora do viewport de 800x600 (`y=816`), portanto o toque não atingia o widget e o retorno permanecia `null`.

A 2.0.91 adiciona uma chave estável aos itens do seletor e faz o teste rolar até a branch desejada antes do toque. O funcionamento de produção do seletor não é alterado. Também foi removido o import não utilizado apontado pelo analyzer.
