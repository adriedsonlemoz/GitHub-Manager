# GitHub Manager 2.0.77

Versão: `2.0.77+200091`
Data: 2026-09-23

## Correção

Corrige a suíte `TokenPermissionDiagnosticsService`: o diagnóstico de **Contents** para PAT clássico agora é validado como `repo`, alinhado com o fluxo atual em que sincronizar o projeto não exige `workflow`.

Corrige a separação de permissões introduzida no fluxo de projetos sem workflow. **Enviar nova versão** valida somente a permissão necessária para sincronizar o conteúdo do projeto; **Enviar build** continua validando também a capacidade necessária para GitHub Actions.

Os logs CI-67 e Android-APK-67 indicavam 99 testes aprovados e uma única falha em `TokenPermissionDiagnosticsService`, porque o teste ainda esperava `repo + workflow` mesmo após a separação entre sincronização do projeto e controle de GitHub Actions.
