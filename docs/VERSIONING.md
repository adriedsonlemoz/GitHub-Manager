# Versionamento

A fonte canônica é `pubspec.yaml`.

Versão atual:

`version: 2.0.56+200070`

- antes do `+`: versionName exibido ao usuário;
- depois do `+`: versionCode Android;
- cada APK futuro precisa usar versionCode maior;
- versões oficiais não usam o sufixo `alpha`.


A versão `2.0.56+200070` mantém a última lista de repositórios renderizada durante invalidações e reconciliações, evitando o spinner central após criar, editar, renomear ou excluir. A 2.0.55 adicionou reconhecimento de `app/build.gradle.kts`/`app/build.gradle` para Android nativo; a 2.0.54 corrigiu a inicialização presa na splash.

A versão `2.0.53+200067` corrige a splash screen do Android 12+: fundo branco em qualquer tema e recurso de splash separado, com área segura maior para impedir o corte do ícone. O launcher/adaptive icon continua inalterado.

A versão `2.0.50+200064` corrige o assistente de configuração: `401` no `/user` passa a ser identificado como PAT rejeitado, e tokens colados são normalizados para remover formatação/whitespace invisível antes do teste e armazenamento.

A versão `2.0.49+200063` adiciona reconciliação de repositórios excluídos externamente, sanitização de URLs temporárias de download, timeout `dataSync` no Android 15+, lock de dependências e menor uso de memória para arquivos grandes em ZIP.

A versão `2.0.28+200042` integra o diagnóstico às ações críticas: Enviar build, mutações de Secrets e exclusão de repositório usam pré-checagem em cache e bloqueiam somente permissões já negadas com segurança.

A versão `2.0.26+200040` reforça GitHub Secrets com suporte documentado a PAT fine-grained/clássico, validação de 48 KB/100 Secrets, importação com diagnóstico por item e testes dedicados.

A versão `2.0.25+200039` remove o banner global de teste, melhora Acompanhados para aceitar URLs de perfil, adiciona edição de perfil pela Home, reorganiza Sobre/suporte e mantém downloads em foreground com retomada parcial por HTTP Range.

A versão `2.0.24+200038` reorganiza o log de envio em relatório visual e textual com métricas de arquivos, resultado da build, workflow, arquivos alterados e linha do tempo limpa.

A versão `2.0.23+200037` mantém envios em primeiro plano com notificação de progresso e adiciona checkpoints persistentes para retomada automática após encerramento do processo.

A versão `2.0.22+200036` adicionou a Central de Envios minimizável, fila global persistida, deduplicação de envios, reutilização de blobs Git idênticos e identificação visual de APK de teste.

A versão `2.0.21+200035` corrigiu a trava de identidade/versão, seleção de workflows, Releases privadas e persistência de downloads interrompidos.

A versão `2.0.20+200034` corrigiu os erros de nulabilidade encontrados nos logs #17 e moveu as ações do detalhe da build para o topo.


A versão `2.0.56+200070` preserva a última lista renderizada durante refresh/invalidation de repositórios. O spinner central é usado somente quando ainda não existe nenhum dado renderizável.
