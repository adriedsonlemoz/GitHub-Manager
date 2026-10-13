# GitHub Manager 2.0.121+200135

Data: 12/10/2026. VersionCode Android: 200135.

## Interface de Builds

- Evento e Branch passam a ocupar um único cartão com layout lado a lado; em larguras muito estreitas os campos se empilham.
- Duração e Etapas continuam em seus próprios cartões.
- Mensagem de commit deixa de aparecer aberta no resumo; permanece em Detalhes técnicos expandíveis, junto ao SHA e demais dados de execução.

## Downloads de APK

- Velocidade: amostragem/atualização visual a cada 350 ms no máximo; taxa medida entre amostras de uma janela de até cinco segundos, em bytes por segundo. As contagens de bytes continuam recebendo todos os chunks.
- Redução de eventos de atualização da interface, particularmente perceptível em transferências rápidas com chunks pequenos.
- Releases e Artifacts: três tentativas totais somente para falhas de rede, interrupção, término prematuro, URL temporária expirada e HTTP 408/500/502/503/504. Entre tentativas, reobtém URL assinada e continua do tamanho parcial em disco, se o servidor aceitar HTTP Range.
- Rejeição de Content-Range incoerente com o offset solicitado, evitando APKs corrompidos por concatenação incorreta.
- Reconhecimento de término prematuro quando o Content-Length ou o total informado em Content-Range é conhecido.
- Não altera assinatura, privilégios GitHub, pipeline de publicação nem lógica de seleção/inspeção do APK.

## Limitações e validação

A CDN e a rede Wi-Fi continuam determinando o limite físico do throughput. Não afirmar ganho garantido de MB/s. Em caso de erro definitivo de permissão, operação ainda exige intervenção do usuário. Os downloads por URLs públicas arbitrárias conservam o comportamento anterior de retry manual; o retry automático está no fluxo autenticado de Releases/Artifacts. Testes Flutter/Android completos e homologação em aparelhos/rede real são pendentes quando indisponíveis localmente.
