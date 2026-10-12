# GitHub Manager 2.0.116+200130

## Melhorias

- Seleção de APK por decisão guiada, com sugestão baseada na ABI informada pelo Android e em nomes reconhecíveis; alternativas compactas e nomes originais recolhidos.
- Não promete compatibilidade, desempenho ou verificação criptográfica antes de inspecionar realmente os bytes do APK baixado. Mantém confirmação da associação ambígua de Releases e da possível incompatibilidade.
- Builds distinguem versão identificada do app e número da execução GitHub Actions.
- Diagnóstico de falhas traz orientação conservadora, arquivo/linha quando recuperável, cópia de diagnóstico e botão para abrir o arquivo no commit correto.
- Workflow GitHub Manager Android APK publica `build-info-<run_id>` com `build-info.json`: versão, versionCode, applicationId, SHA, runId, APK, ABI, tamanho e SHA-256 declarado pelo workflow.
- Leitura opcional e sob demanda do manifesto valida runId/commit e tamanho do ZIP; não exige mudanças nos workflows de outros repositórios.
- Valida a estrutura ZIP real do APK após baixar e antes de publicar em Downloads; registra ABIs nativas encontradas e impede variantes incompatíveis quando o Android forneceu suas ABIs. Não verifica assinatura/SDK mínimo.
- Notificações de Builds mostram versão provável quando detectada no título/commit, separando o número da execução.
- Testes de regressão para escolha, versão, manifesto e diagnósticos.

## Pendências de validação

Compilar com Flutter 3.47.1 e executar `flutter test` + `flutter analyze` nos workflows; validar navegação em Android físico e upload/download do manifest. O SHA-256 vindo do workflow é um valor **declarado**: somente a conferência dos bytes baixados confirma a integridade.
