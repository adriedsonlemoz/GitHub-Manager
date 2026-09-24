# GitHub Manager 2.0.76

Versão: `2.0.76+200090`
Data: 2026-09-23

## Correção

Corrige a separação de permissões introduzida no fluxo de projetos sem workflow. **Enviar nova versão** valida somente a permissão necessária para sincronizar o conteúdo do projeto; **Enviar build** continua validando também a capacidade necessária para GitHub Actions.

Os logs CI-66 e Android-APK-66 indicavam 99 testes aprovados e uma única falha em `PermissionPreflightService`, causada pelo diagnóstico de Contents ainda exigir `workflow`.
