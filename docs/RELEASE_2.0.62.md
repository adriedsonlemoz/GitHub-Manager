# GitHub Manager 2.0.62

Versão: `2.0.62+200076`

## Recuperação inteligente de envios

- O método de envio é identificado e persistido em cada tentativa: atualização incremental, reconstrução completa da árvore ou arquivos individuais.
- Falhas transitórias de rede, HTTP 408, 429 e 5xx recebem repetição automática limitada, com espera progressiva e registro no histórico.
- Se o GitHub rejeitar a criação da árvore incremental com `GITHUB_VALIDATION`/422, a recuperação automática valida novamente o SHA atual da branch e tenta a reconstrução completa da árvore final.
- O SHA da branch é revalidado antes da criação/publicação final e antes de cada mutação do fallback individual; mudança concorrente interrompe o envio com `UPLOAD_BRANCH_CHANGED`.
- Existe fallback manual por API de Contents para conjuntos pequenos e seguros, limitado a 12 operações e arquivos de até 8 MB; arquivos executáveis e objetos Git não comuns são bloqueados para evitar perda de modo ou atualização parcial inadequada.
- A interface diferencia “Repetir método atual” de “Tentar método alternativo” e informa qual método é recomendado para o erro detectado.
- O diagnóstico registra as tentativas de recuperação, método utilizado, HTTP/endpoint quando disponíveis e quantidade de commits individuais eventualmente publicados.
- Configurações inclui “Recuperação automática de envios”, ativada por padrão.

## Segurança

A recuperação não usa `force` para mover a branch. Antes de trocar de método ou publicar mudanças, o app confirma que a branch ainda aponta para o SHA usado na comparação. Se houver alteração externa, a operação é interrompida e uma nova tentativa precisa recomparar o projeto.
