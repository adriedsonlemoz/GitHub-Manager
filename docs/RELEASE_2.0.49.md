# GitHub Manager 2.0.49

Versão: `2.0.49+200063`

## Correções e consolidação

- Corrige repositórios excluídos diretamente no GitHub que permaneciam na listagem por causa do cache local sem reconciliação automática. A tela agora mantém abertura cache-first, consulta a API ao abrir e ao retornar ao app e atualiza os providers após a reconciliação.
- Impede que URLs temporárias assinadas usadas nos redirects de downloads sejam persistidas como endpoint de diagnóstico ou reapareçam em mensagens técnicas copiáveis.
- Implementa `Service.onTimeout(startId, fgsType)` nos foreground services `dataSync` de upload e download, encerrando o serviço corretamente quando o Android 15+ aplicar o limite e preservando a retomada existente por checkpoint/arquivo parcial.
- Passa a versionar `pubspec.lock` e fixa as dependências diretas nas versões efetivamente resolvidas pelo Flutter 3.47.1 no CI da versão anterior.
- Reduz picos de memória no envio de ZIP: arquivos maiores são descompactados para temporário, têm SHA calculado por stream e são enviados em base64 por stream.
- Limita a leitura integral de arquivos candidatos a metadados de identidade a 1 MiB.

## Compatibilidade

Não altera applicationId, assinatura, formato dos checkpoints, regras de sincronização Git ou estrutura das filas.
