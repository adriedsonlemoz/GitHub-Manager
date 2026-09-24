# Versionamento

A fonte canônica é `pubspec.yaml`.

Versão atual:

`version: 2.0.87+200101`

- antes do `+`: versionName exibido ao usuário;
- depois do `+`: versionCode Android;
- cada APK futuro precisa usar versionCode maior;
- versões oficiais não usam o sufixo `alpha`.

A versão `2.0.87+200101` corrige o deadlock de `waitUntilIdle()` em `testWidgets`, substituindo polling com `Future.delayed` por sinalização de conclusão da fila sem Timer.

A versão `2.0.86+200100` corrige o ciclo de persistência do `UploadManagerService`: testes não deixam mais debounce pendente, `waitUntilIdle()` aguarda gravações e `dispose()` aguarda o encerramento seguro antes de liberar arquivos temporários.

A versão `2.0.85+200099` corrige as três falhas de testes dos jobs CI #74 / Android APK #75 e padroniza os nomes dos workflows/downloads de logs para identificar projeto, tipo de workflow e execução.

A versão `2.0.84+200098` reorganiza Builds para um card por repositório, abre os workflows mais recentes em pop-up com downloads rápidos de Log/APK e corrige os erros fatais encontrados nos jobs #72.

A versão `2.0.82+200096` unifica a escolha/criação de branches, adiciona prévia read-only da sincronização e melhora a identificação de versões em projetos com subpastas, nomes com pré-release, Godot, Python e Rust.

A versão `2.0.81+200095` corrige a ordem branch → pré-check, libera o primeiro envio para repositórios realmente vazios, adota comparação SemVer correta e reduz o consumo da API na aba global Builds com cache em memória e polling seletivo.

A versão `2.0.80+200094` adiciona troca de branch diretamente na confirmação final de envio e amplia a identificação de versão para projetos Shell/Termux por `MANIFEST.json` e `manager.sh`, mantendo o nome do ZIP apenas como pista visual quando não houver metadado interno.

A versão `2.0.79+200093` corrige a incompatibilidade de `AsyncValue.valueOrNull` com Riverpod 3 na tela global de Builds, protege o retorno tipado do diálogo de envio com teste de regressão e limpa warnings introduzidos na reorganização recente.

A versão `2.0.78+200092` corrigiu a suíte `TokenPermissionDiagnosticsService`, alinhando o diagnóstico de Contents para PAT clássico ao fluxo atual de sincronização sem build. A versão `2.0.76+200090` havia corrigido o pré-check de permissões do envio.

A versão `2.0.72+200086` refatora o modelo `ManagedUpload` sem alterar seu contrato público, separando estado derivado, diagnóstico de falhas, mutações de ciclo de vida, relatório técnico e codec JSON em componentes internos menores.

A versão `2.0.71+200085` refatora o ciclo de vida do SQLite para uma única conexão compartilhada por isolate, deduplica aberturas concorrentes e remove fechamentos de banco por serviços auxiliares de curta duração.

A versão `2.0.70+200084` refatora as telas grandes de Configurações, Detalhe do repositório, Builds/Detalhe da build e APKs/Releases e torna a exclusão de builds responsável também pela limpeza de artifacts e APKs de Release vinculados com segurança ao mesmo commit.

A versão `2.0.69+200083` corrige a referência de `_shortSha` fora do escopo em `UploadProgressDialog`, compartilhando o helper no nível do arquivo e restaurando a compilação/CI da tela de progresso de envio.

A versão `2.0.68+200082` protege workflows do GitHub Actions contra remoção implícita durante a sincronização por ZIP, separa envio concluído de build pendente, melhora a descoberta de gatilhos e compacta o diagnóstico com ações de correção sem reenviar o projeto.

A versão `2.0.67+200081` corrige a migração e o ciclo de vida do SQLite, repara tabelas ausentes automaticamente, isola conexões locais entre serviços e adiciona diagnóstico/reconstrução do banco local sem apagar o token GitHub.

A versão `2.0.66+200080` corrige o build 57, adiciona leitura de versão de `package.json` em ZIPs Node/JavaScript, troca o banner de conferência pela versão real do projeto a enviar, acrescenta ajuda contextual para identidade/versão e expõe a chave/token GitHub atual com exibição/cópia em Configurações.

A versão `2.0.65+200079` ativa projetos fixados usando a persistência SQLite já existente, adiciona filtro/ordenação da lista e separa o carregamento resumido dos cards da análise completa de metadados para reduzir chamadas desnecessárias à API.

A versão `2.0.64+200078` adiciona o tamanho informado pelo GitHub aos cards de projetos e um resumo no topo com quantidade de projetos e tamanho total, sem chamadas extras por repositório.

A versão `2.0.63+200077` redesenha a tela de APKs/Releases: remove a lista recolhível de Releases, exibe cada arquivo diretamente em cards identificados, adiciona busca e filtros, simplifica a barra superior e mantém Artifacts claramente separados das Releases.

A versão `2.0.62+200076` adiciona recuperação inteligente de envios: repetição controlada para falhas temporárias, fallback automático de árvore incremental para reconstrução completa, proteção por SHA da branch, método manual por arquivos individuais para alterações pequenas/seguras e histórico de tentativas no diagnóstico.

A versão `2.0.61+200075` torna as falhas de envio explicáveis: preserva a operação exata que falhou, HTTP/endpoint/resposta completa do GitHub, progresso alcançado, impacto seguro no repositório e orientação específica por tipo de erro.

A versão `2.0.60+200074` melhora Builds: polling leve a cada 6/15 segundos, seleção automática de falhas por toque longo, exclusão em lote tolerante a falhas individuais e diagnóstico que combina annotations com contexto extraído dos logs do GitHub Actions.


A versão `2.0.59+200073` remove o uso de cache local para dados remotos do GitHub. Repositórios, descrições, perfil, permissões e metadados são consultados diretamente; Acompanhados guarda somente referências owner/repo; snapshots legados são removidos no startup.

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


A 2.0.58 preserva stale-while-revalidate, mas deixa de depender de invalidações para atualizar a Home: a lista fresca retornada pela API é aplicada diretamente, enquanto falhas de rede mantêm o último snapshot válido.
