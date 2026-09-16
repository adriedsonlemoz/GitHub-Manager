# GitHub Manager 2.0.72

Versão: `2.0.72+200086`

## Refatoração de ManagedUpload

- `ManagedUpload` deixou de concentrar quase mil linhas de estado, diagnóstico, relatório, mutações e persistência no mesmo arquivo.
- O contrato público foi preservado para não exigir mudanças nas telas, providers ou `UploadManagerService`.
- Estado derivado e apresentação foram movidos para `managed_upload_state.dart`.
- Diagnóstico e recomendações de recuperação foram isolados em `managed_upload_failure.dart`.
- Mutações de progresso, retry, retomada e interrupção foram isoladas em `managed_upload_lifecycle.dart`.
- Relatório técnico e linha do tempo foram isolados em `managed_upload_report.dart`.
- Serialização e restauração JSON foram isoladas em `managed_upload_codec.dart`, mantendo as mesmas 51 chaves persistidas.
- Adicionado teste de contrato que atravessa estado, diagnóstico, relatório, codec e retry para detectar regressões entre os componentes.

## Compatibilidade

A estrutura JSON persistida da Central de Envios não mudou. Checkpoints e históricos criados pelas versões anteriores continuam compatíveis com `ManagedUpload.fromJson`.
