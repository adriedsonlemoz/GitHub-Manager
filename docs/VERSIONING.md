# Versionamento

A fonte canônica é `pubspec.yaml`.

Versão atual:

`version: 2.0.5+200019`

- antes do `+`: versionName exibido ao usuário;
- depois do `+`: versionCode Android;
- cada APK futuro precisa usar versionCode maior;
- versões oficiais não usam o sufixo `alpha`.

A versão `2.0.5+200019` mantém as correções anteriores e acrescenta detecção de ZIP idêntico: sem alteração real não há novo commit nem build automática, e o usuário pode executar uma build manual se desejar.
