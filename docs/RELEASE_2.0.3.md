# GitHub Manager 2.0.3 (200017)

## Escopo

Esta versão consolida as correções de Actions/Downloads da 2.0.1 e 2.0.2 e fecha a identidade de assinatura do GitHub Manager.

## Assinatura oficial nova

Foi criada uma nova keystore exclusiva para GitHub Manager, fora do ZIP do projeto.

- alias: `github_manager_release`;
- RSA 3072;
- certificado SHA-256 público fixado em `android/release-signing.properties`;
- os workflows Android APK e Android Release continuam usando `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS` e `KEY_PASSWORD`;
- em divergência de certificado, o log mostra SHA-256 esperado e encontrado, sem expor chave privada ou senha.

A chave anterior não é mais a identidade oficial desta versão. APKs assinados com chaves diferentes não podem ser atualizados diretamente uns sobre os outros.

## Builds agrupadas por envio

A tela Builds agora agrupa runs pelo mesmo `head_sha`.

Cada grupo exibe:

- `Atualização` para runs de `push` ou `Build manual` para execuções manuais;
- data e hora até segundos;
- SHA curto do commit;
- origem `push` ou manual;
- quantidade de workflows relacionados.

Dentro do grupo, cada run exibe:

- nome do workflow;
- número da run;
- número da tentativa (`run_attempt`);
- branch;
- status;
- duração.

Isso evita repetir dois cards quase idênticos quando Android APK e CI pertencem ao mesmo envio. Execuções manuais ficam em grupos próprios, mesmo quando usam o mesmo commit, para não esconder novas tentativas.

## Enviar build

Permanece o fluxo da 2.0.2:

1. sincronizar completamente o ZIP;
2. criar o commit automático `Atualização • GitHub Manager • DD/MM/AAAA HH:MM:SS`;
3. verificar runs pelo SHA do novo commit;
4. se Android APK já iniciou pelo `push`, não criar duplicata;
5. se necessário, usar `workflow_dispatch` como fallback.

## CI

Foram removidos os três padrões de collection-if que o Flutter 3.47.1 reportou como `use_null_aware_elements` em `platform_actions.dart`. A lógica continua igual, mas os argumentos opcionais do MethodChannel são montados fora do literal de mapa.

## Diagnóstico real anterior

No repositório oficial `adriedsonlemoz/GitHub-Manager`, o commit 2.0.1 demorou cerca de 20 minutos para aparecer no Actions, mas depois o GitHub confirmou que os workflows foram disparados pelo evento `push`. As falhas posteriores foram reais: o CI parou nos três avisos do analyzer e o APK parou porque o fingerprint esperado não correspondia à chave usada nos Secrets.

## Validação local desta entrega

- versão canônica: `2.0.4+200018`;
- JSON/YAML/XML e scripts serão validados antes do empacotamento;
- a nova keystore e o arquivo contendo os Secrets permanecem fora do ZIP do projeto;
- o ambiente local desta preparação não possui Flutter/Dart, portanto a confirmação de `flutter analyze`, testes e APK desta versão depende da próxima execução do GitHub Actions.
