# Versionamento

A fonte canônica é `pubspec.yaml`.

Versão atual:

`version: 2.0.2+200016`

- antes do `+`: versionName exibido ao usuário;
- depois do `+`: versionCode Android;
- cada APK futuro precisa usar versionCode maior;
- versões oficiais não usam o sufixo `alpha`.

A versão `2.0.2+200016` mantém as correções de Builds/Downloads da 2.0.1 e acrescenta a verificação do disparo de Actions após sincronização, fallback de `workflow_dispatch` para repositórios recém-criados e commit automático `Atualização` com segundos.
