# GitHub Manager 2.0.130+200144

Data: 16/10/2026. Android versionCode: 200144.

## Central de Downloads: Pausar e Retomar

O botão **Pausar** fecha a conexão ativa e conserva o arquivo parcial. A seção **Pausados** permite **Retomar** e **Cancelar**. A retomada espera o fechamento da transferência anterior, preserva a posição real gravada em disco e pede o restante por HTTP Range. Se o servidor não aceita intervalos, baixa do início em vez de juntar partes erradas. Para Releases e Artifacts, as URLs temporárias são solicitadas novamente à API do GitHub.

A gravação do histórico é serializada, evitando que estados antigos sobrescrevam uma pausa recente. Pausados permanecem no histórico e não são apagados por **Limpar histórico**, nem retomados automaticamente ao abrir o aplicativo. Se uma URL pública com parâmetros temporários expirar, a retomada pode exigir um novo link.

## Investigação de downloads lentos

A medição existente usa janela móvel de cinco segundos. Grandes oscilações podem representar alterações reais de conectividade, gargalos Wi-Fi/móvel/CDN e concorrência entre downloads. Quando existem várias transferências, a interface informa que compartilham rede. Após 15 segundos sem receber novos bytes, velocidade e ETA anteriores não são mais exibidas como se fossem atuais. Uma reconexão pode ou não melhorar a taxa; o app não tem controle sobre banda ou servidores externos.

## Integridade

O recebimento por URL pública passa a conferir o ponto inicial do HTTP 206 e o total de bytes informado. Releases/Artifacts mantêm checagem de Content-Range e inspeção de APK antes de publicar o arquivo em Downloads.

## Verificações pendentes

Executar `flutter analyze`, `flutter test` e workflow Android APK. Testar pausas repetidas, retomada em Wi-Fi/móvel, servidores com e sem suporte a Range, APKs grandes e estados após reinício do app.
