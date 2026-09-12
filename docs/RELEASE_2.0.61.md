# GitHub Manager 2.0.61

Versão: `2.0.61+200075`

## Diagnóstico de falhas no envio

Esta versão substitui mensagens genéricas de falha por um diagnóstico em camadas. O envio agora preserva a operação exata que estava em andamento, o progresso alcançado, o status HTTP, o endpoint e a resposta retornada pelo GitHub.

O diálogo mostra separadamente **Até onde chegou**, **Impacto no repositório**, **Resposta do GitHub**, **O que isso significa** e **O que fazer agora**. Quando a API retorna `errors`, os detalhes desses itens também entram no diagnóstico.

Para respostas `422`, o aplicativo diferencia rejeição ao criar árvore Git, criar commit, atualizar a referência da branch, enviar blobs e alterar conteúdo. O botão **Copiar diagnóstico** produz um texto completo para suporte sem exigir captura de tela ou busca manual no log.
