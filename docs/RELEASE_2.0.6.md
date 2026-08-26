# GitHub Manager 2.0.6 (200020)

## Builds / GitHub Actions

- Execuções e grupos agora são ordenados explicitamente da mais recente para a mais antiga, independentemente da ordem recebida da API.
- A ordem interna real dos passos de cada job continua preservada.
- O bloco de falha principal aparece antes da sequência completa de passos.
- Falha principal e passos com falha usam fundo branco, borda/texto vermelho e maior destaque.
- Passos concluídos com sucesso usam fundo verde e texto branco.
- Runs concluídas com sucesso também recebem destaque verde; runs com falha recebem branco/vermelho.
- Estados em andamento, cancelados ou ignorados permanecem neutros para não serem confundidos com sucesso ou erro.

## Base preservada

Mantém as correções anteriores de sincronização de ZIP, detecção de ZIP idêntico, disparo de build, Actions, artifacts, downloads e assinatura opcional para APK de teste.

## Validação desta entrega

- YAML dos workflows analisado estruturalmente.
- JSON de metadados válido.
- Sincronização de versão executada.
- ZIP final testado quanto à integridade.
- O ambiente local desta preparação não possui Flutter/Dart; portanto esta versão só deve ser considerada compilada após o GitHub Actions executar o commit correspondente.
