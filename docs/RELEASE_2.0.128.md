# GitHub Manager 2.0.128+200142

**Data:** 15/10/2026 | **versionCode:** 200142

## Implementação

- Quinta ação **Play** no detalhe de cada repositório; linha compacta preserva Enviar, GitHub/Fork, Copiar e APK.
- Pop-up de análise da branch principal, com reavaliação, separação de achados automáticos e tarefas Play Console.
- Detecta **targetSdk API 36** literal em Gradle/Manifest, mostra diferença para `compileSdk`, e trata configuração dinâmica como desconhecida.
- Verifica indícios de `versionCode`, `applicationId`, `.aab` e workflow, assinatura debug na configuração, permissões de atenção, arquivos de privacidade.
- Checklist manual de Segurança dos dados, privacidade, conteúdo, testes fechados e revisão final do Play Console.
- Links para documentação oficial e Play Console; não solicita permissões Google Play nem consulta Secrets/keystores.

## Limites

A avaliação é assistiva, não garante aprovação e não substitui a inspeção do bundle Release. Mudanças de política após esta data exigem revisão. Sem execução local do SDK Flutter/Gradle: validação de código e build na CI ainda é necessária.

Fontes oficiais:
- https://support.google.com/googleplay/android-developer/answer/11926878?hl=pt-BR
- https://support.google.com/googleplay/android-developer/answer/10787469?hl=pt-BR
- https://support.google.com/googleplay/android-developer/answer/14151465?hl=pt-BR
