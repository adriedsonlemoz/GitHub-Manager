# Versionamento

A fonte canônica é `pubspec.yaml`.

Versão atual:

`version: 2.0.20+200034`

- antes do `+`: versionName exibido ao usuário;
- depois do `+`: versionCode Android;
- cada APK futuro precisa usar versionCode maior;
- versões oficiais não usam o sufixo `alpha`.

A versão `2.0.20+200034` corrige os erros de nulabilidade encontrados nos logs #17 e move as ações do detalhe da build para o topo.
