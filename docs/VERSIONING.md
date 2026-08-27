# Versionamento

A fonte canônica é `pubspec.yaml`.

Versão atual:

`version: 2.0.22+200036`

- antes do `+`: versionName exibido ao usuário;
- depois do `+`: versionCode Android;
- cada APK futuro precisa usar versionCode maior;
- versões oficiais não usam o sufixo `alpha`.

A versão `2.0.22+200036` adiciona a Central de Envios minimizável, fila global persistida, deduplicação de envios, reutilização de blobs Git idênticos e identificação visual de APK de teste.

A versão `2.0.21+200035` corrigiu a trava de identidade/versão, seleção de workflows, Releases privadas e persistência de downloads interrompidos.

A versão `2.0.20+200034` corrigiu os erros de nulabilidade encontrados nos logs #17 e moveu as ações do detalhe da build para o topo.
