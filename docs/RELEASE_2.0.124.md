# GitHub Manager 2.0.124+200138

Data: 15/10/2026. versionCode Android: 200138.

## Atalho APK do repositório

- O botão APK da tela do repositório não depende mais de uma consulta prévia aos Artifacts, que o deixava desabilitado mesmo quando havia APK de Release.
- Ao tocar, o app consulta sob demanda Releases e Artifacts. Cada fonte tem tratamento de falhas independente.
- Escolhe a última versão identificada dentre as Releases publicadas ou um Artifact cuja versão seja explicitamente mais recente; em ausência de versão verificável em Artifact, prefere Release.
- Se existirem variantes (ARM64, ARM32, x86, x86_64, Universal), apresenta o seletor já existente com sugestão quando a ABI do aparelho estiver disponível. Não presume compatibilidade perfeita apenas pelo nome.
- Se existir apenas um APK, o download começa diretamente pela Central de Downloads, após confirmação se a ABI parecer incompatível.
- Artifacts expirados são descartados. A seleção de artifacts respeita o workflowRunId para não misturar variantes de builds diferentes.
- Caso nenhum APK esteja disponível, a tela explica e oferece acesso ao catálogo completo.

## Validação

- Adicionados testes unitários do resolvedor e atualizado o contrato do botão APK.
- Sincronizados README, CHANGELOG, docs/VERSIONING, tela Novidades, histórico e metadados de versão.
- Flutter/Gradle não executados localmente porque o SDK não está disponível no ambiente. Confirmar com a CI e testes reais no aparelho.
