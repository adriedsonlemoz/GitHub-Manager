# GitHub Manager 2.0.131+200145

Data: 16/10/2026. VersionCode Android: 200145.

## Novidades

- Controle da limpeza automática por projeto em Configurações → Transferências.
- Três modos: **Após concluir** (padrão seguro), **Antes de iniciar** e **Desativada**.
- Arquivos APK, ZIP, log, artifact e outros downloads do mesmo projeto são consolidados em um único arquivo final gerenciado por pasta; downloads de projetos distintos são preservados.
- A limpeza não altera os arquivos `.part`, pausados, em andamento, nem dados de usuário fora da pasta Downloads/GitHub. Android 10+ verifica propriedade e caminho exato no MediaStore. Android 9 e anterior usa somente arquivos do histórico local com caminho verificado.
- Publicações e exclusões são serializadas por pasta; o histórico é reconciliado com os arquivos efetivamente excluídos. Falhas de limpeza após publicação são exibidas ao usuário.
- Módulos de download, Play, pausas e retomada anteriores continuam disponíveis.

## Validação

- Testes de contrato e de serialização de `cleanupWarning` adicionados.
- Compilação Flutter, testes instrumentados do MediaStore e testes em aparelho permanecem pendentes.
