# Validação — GitHub Manager 2.0.106+200120

- `pubspec.yaml` e `github-manager.json` sincronizados em `2.0.106+200120`;
- detalhes de Build preservam Logs, Repetir, APK, Excluir, Atualizar, jobs e etapas;
- falhas usam resumo compacto com **Ver erros**, sem bloco técnico longo na tela principal;
- janela de erros oferece navegação, explicação leiga, detalhes técnicos recolhidos e cópia/logs;
- **Causa identificada** depende de log inspecionado e assinatura técnica forte;
- botão APK usa `runId` e commit para localizar Artifacts/Releases da execução atual;
- tela global **Builds** não escolhe mais `first` silenciosamente quando existem várias opções;
- atalho APK do repositório abre a lista explícita de APKs, preservando a escolha de versão/arquitetura;
- múltiplos APKs exibem arquitetura, tamanho, origem e recomendação para o aparelho;
- variante incompatível exige confirmação antes do download;
- `Build.SUPPORTED_ABIS` e `SUPPORTED_64_BIT_ABIS` são lidos sem permissão especial;
- Configurações exibe modelo, Android/API, ABI principal, ABIs suportadas e suporte a 64 bits;
- seleção interna de APK em Artifact considera todas as ABIs suportadas e persiste a preferência para retry;
- tela de Novidades aponta somente para mudanças da 2.0.106;
- o ZIP final deve conter somente código-fonte e documentação, sem APK.

## Validação disponível neste ambiente

- varredura estrutural executada sobre 182 arquivos Dart, sem desequilíbrio de delimitadores e sem imports/parts locais ausentes;
- `pubspec.yaml` e `github-manager.json` foram parseados/conferidos e permanecem sincronizados;
- `git diff --no-index --check` não apontou whitespace errors;
- não há arquivos `.apk` dentro da árvore de código-fonte;
- `flutter analyze` e `flutter test` não foram executados localmente porque este ambiente não possui os binários Flutter/Dart; a validação de compilação deve continuar no workflow/ambiente Flutter do projeto.
