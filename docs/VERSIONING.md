# Versionamento

A fonte canônica é `pubspec.yaml`.

Versão atual:

`version: 2.0.9+200023`

- antes do `+`: versionName exibido ao usuário;
- depois do `+`: versionCode Android;
- cada APK futuro precisa usar versionCode maior;
- versões oficiais não usam o sufixo `alpha`.

A versão `2.0.9+200023` simplifica a validação: o CI não falha por warnings/infos e o workflow Android APK não faz uma segunda comparação manual do certificado após o Gradle assinar o APK.
