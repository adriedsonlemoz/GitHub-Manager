# GitHub Manager 2.0.7 (200021)

## Correção do verificador de assinatura

O workflow Android APK agora lê o SHA-256 do certificado de forma compatível com diferentes formatos de saída do `apksigner`.

Foram contempladas saídas como:

- `Signer #1 certificate SHA-256 digest: ...`
- `V2 Signer: certificate SHA-256 digest: ...`

A validação continua comparando o SHA-256 encontrado no APK com o fingerprint oficial versionado em `android/release-signing.properties`.

## Base preservada

Mantém todas as correções anteriores da 2.0.6, incluindo:
- Builds mais recentes primeiro;
- destaque visual de sucesso e falha;
- agrupamento por commit;
- tentativa e horário com segundos;
- ZIP idêntico sem novo commit;
- build manual opcional;
- assinatura oficial quando há Secrets;
- APK de teste quando não há Secrets.

## Validação

- YAML dos workflows analisado estruturalmente;
- sincronização de versão validada;
- ZIP final testado quanto à integridade.

A compilação final deve ser confirmada pelo GitHub Actions após o envio desta versão.
