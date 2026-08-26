# Versionamento

A fonte canônica é `pubspec.yaml`.

Versão atual:

`version: 2.0.3+200017`

- antes do `+`: versionName exibido ao usuário;
- depois do `+`: versionCode Android;
- cada APK futuro precisa usar versionCode maior;
- versões oficiais não usam o sufixo `alpha`.

A versão `2.0.3+200017` mantém as correções anteriores e acrescenta a nova assinatura oficial do GitHub Manager, correção dos avisos do analyzer e agrupamento visual das execuções por commit/envio com horário até segundos e número da tentativa.
