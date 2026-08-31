# GitHub Manager 2.0.60

Versão: `2.0.60+200074`

## Builds e atualização automática

- A tela de Builds passa a procurar execuções novas mesmo quando nenhuma build estava ativa ao abrir a tela.
- Polling adaptativo: 6 segundos durante builds em andamento e 15 segundos quando tudo está parado.
- O polling automático usa somente as execuções recentes e as mescla com a lista já carregada, reduzindo chamadas desnecessárias à API.
- A lista exibe data e hora de cada execução e informa quando ocorreu a última atualização.

## Limpeza de falhas

- Toque longo em uma build, quando há falhas visíveis, seleciona automaticamente todas as falhas para limpeza rápida.
- A confirmação deixa explícito que builds concluídas com sucesso serão preservadas.
- Exclusão em lote não para na primeira falha de API: continua as demais e informa quantas foram excluídas e quantas falharam.
- Execuções que não puderam ser apagadas permanecem selecionadas para nova tentativa.

## Diagnóstico de build

- Detalhes exibem evento, branch, commit, tentativa, horários, quantidade de etapas e duração de jobs/etapas.
- Quando possível, o app informa se a falha ocorreu antes da geração/publicação do APK.
- O diagnóstico continua usando annotations do GitHub, mas agora também baixa temporariamente o ZIP de logs, identifica linhas de erro relevantes e mostra contexto próximo.
- A interface separa o que foi informado pelo GitHub da leitura automática feita pelo GitHub Manager.
- Novo botão **Copiar diagnóstico** reúne execução, versão, horários, job, etapa, annotation e trecho relevante do log.

Os arquivos de log usados no diagnóstico são temporários e são removidos após a análise.
