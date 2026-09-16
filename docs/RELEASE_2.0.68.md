# GitHub Manager 2.0.68

Versão: `2.0.68+200082`

## Problema observado

Após sincronizar um ZIP, o projeto podia ser atualizado no GitHub mas o aplicativo exibia **Envio com falha** quando nenhuma execução automática aparecia e não encontrava um workflow de APK com `workflow_dispatch`. Além de a mensagem misturar duas etapas diferentes, a sincronização completa podia remover workflows existentes caso eles não estivessem presentes no ZIP.

## Correções

- protege `.github/workflows/**` contra remoção implícita na sincronização por ZIP;
- permite substituir um workflow normalmente quando o mesmo caminho estiver presente no ZIP;
- distingue **envio do projeto** de **inicialização da build**;
- após commit publicado, problemas no Actions viram **Projeto enviado • Build pendente**, preservando o commit;
- **Verificar build** reexecuta apenas a etapa de build, sem reenviar o ZIP;
- inspeciona os YAMLs reais para identificar APK, `push` e `workflow_dispatch`;
- diferencia workflow ausente, gatilho ausente e `push` que ainda não criou execução;
- adiciona espera extra para atraso de indexação do GitHub Actions;
- compacta o diagnóstico, torna o conteúdo rolável e move os detalhes técnicos para uma seção recolhida;
- adiciona atalhos para Builds e exemplo copiável de gatilho quando a configuração do workflow precisar ser corrigida;
- a confirmação do envio passa a explicar que workflows existentes são preservados.

## Prevenção de regressão

- teste de contrato garante que caminhos em `.github/workflows/**` sejam reconhecidos como infraestrutura protegida;
- testes do inspetor de workflows cobrem `push`, `workflow_dispatch` e workflows que não geram APK;
- teste do gerenciador de envios garante que falha de build após commit resulte em `buildPending` e que a nova tentativa não faça outro upload.
