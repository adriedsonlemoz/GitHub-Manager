# GitHub Manager 2.0.24 (200038)

## Relatório de envios

- substitui o bloco textual cru da Central de Envios por um relatório visual organizado;
- destaca status e etapa final em um banner de resultado;
- mostra métricas de arquivos analisados, alterados, já atualizados, retomados e removidos;
- mostra duração do envio;
- separa informações do projeto das informações do GitHub/Build;
- permite copiar o SHA diretamente;
- mostra workflow, arquivo do workflow e Run ID em seção própria;
- arquivos alterados ficam em seção expansível, com amostra limitada para não poluir a tela;
- linha do tempo mostra somente etapas importantes;
- relatório em texto continua disponível e copiável para diagnóstico ou envio em suporte.

## Redução de ruído

Eventos por arquivo, como `Arquivo já está atualizado`, `Processando arquivos do projeto` e checkpoints individuais, deixam de ocupar a linha do tempo principal. A informação é convertida em contadores e, quando relevante, em lista de arquivos alterados.

## Compatibilidade

O histórico anterior continua sendo carregado. Novos campos de resumo possuem valores padrão quando um envio antigo ainda não os contém.

Versão: `2.0.24+200038`.
