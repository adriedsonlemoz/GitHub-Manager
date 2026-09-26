# GitHub Manager 2.0.96+200110

## APKs organizados por versão

Esta versão simplifica a tela **APKs** e corrige a ordenação de projetos que publicam muitas versões dentro da mesma GitHub Release. A versão do asset passa a ser usada para ordenar os cards, evitando que APKs novos apareçam no fim da lista quando a tag/data da Release é compartilhada.

### Mudanças

- um card por versão detectada;
- variantes Universal, ARM64, ARMv7 e x86 agrupadas;
- seletor de variante ao tocar em **Escolher**;
- Universal priorizado e marcado como recomendado quando disponível;
- badges redundantes removidos dos cards de Release;
- exclusão/gerenciamento movidos para ação discreta;
- notificações de ação em SnackBar flutuante no rodapé;
- indicadores globais de upload/download compactos;
- teste de regressão para o caso de Release fixa do Explorador XP.

## Identidade Android

- applicationId: `br.com.githubmanager.app`
- versionName: `2.0.96`
- versionCode: `200110`

A fonte canônica continua sendo `pubspec.yaml`, espelhada em `github-manager.json`.
