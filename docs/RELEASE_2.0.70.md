# GitHub Manager 2.0.70

Versão: `2.0.70+200084`

## Refatoração

- **Configurações** separa a composição visual das operações de tema, token, API, notificações, ajuda e reparo local.
- **Detalhe do repositório** separa a UI das ações de carregar/atualizar, enviar build, download e gerenciamento.
- **Builds** separa polling/seleção/exclusão/ações da composição visual, e **Detalhe da build** foi dividido em apresentação, controller de ciclo de vida/ações e widgets de diagnóstico.
- **APKs/Releases** separa a renderização da tela das operações de busca, filtros, publicação, download e exclusão.
- A refatoração é conservadora: os fluxos existentes foram mantidos e a mudança principal é reduzir acoplamento e tamanho dos arquivos visuais.

## Builds, artifacts e APKs

- A exclusão de build passa por `BuildCleanupService`.
- O workflow run é removido primeiro. Depois, o app confirma se ainda existe artifact com o mesmo `run_id` e faz limpeza explícita quando necessário.
- APKs anexados a Releases são recursos independentes do run. Eles só são apagados automaticamente quando o GitHub Manager consegue provar que pertencem ao mesmo commit da build.
- Releases novas publicadas pelo app usam o `head_sha` do artifact como `target_commitish` quando disponível, melhorando o vínculo build → APK.
- Excluir o APK de uma Release remove somente o asset; Release e tag permanecem.
- A ação **Excluir APKs anteriores** agora trata Actions artifacts e Release assets, preservando o item mais recente de cada origem.
- A listagem de Releases passou de uma única página de 30 itens para paginação de até 500 Releases.

## Prevenção

- Providers de artifacts e Releases são invalidados após exclusões para impedir estado visual obsoleto.
- Novos testes cobrem o vínculo `workflow_run/head_sha`, limpeza de build e limpeza de APKs antigos nas duas origens.
- Se a exclusão de um Release asset for negada, o token fine-grained precisa ter permissão de repositório **Contents: write**.
