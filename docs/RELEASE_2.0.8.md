# GitHub Manager 2.0.8 (200022)

## Simplificação do CI e assinatura

- `ci.yml` continua executando `flutter analyze`, mas warnings e infos não bloqueiam o workflow.
- Erros reais do analyzer continuam falhando normalmente.
- Foi removida do workflow `Android APK` a comparação manual e redundante do SHA-256 do certificado depois da compilação.
- Com os 4 Secrets, o Gradle continua usando a chave oficial.
- Sem Secrets, o Android APK continua gerando APK de teste com assinatura debug.
- Secrets parcialmente configurados continuam sendo tratados como erro de configuração.
- Foi removida a classe `_StepIcon` que havia ficado sem uso após a mudança visual dos passos.

## Base preservada

Mantém todas as melhorias anteriores de Builds, agrupamento, ordem mais recente primeiro, cores de sucesso/falha, downloads, sincronização completa e detecção de ZIP idêntico.

## Validação

- Workflows YAML analisados estruturalmente.
- Metadados JSON validados.
- Sincronização de versão validada.
- ZIP final testado quanto à integridade.

A compilação final deve ser confirmada pelo GitHub Actions após o envio desta versão.
