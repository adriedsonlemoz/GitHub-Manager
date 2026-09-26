# Validação — GitHub Manager 2.0.102+200116

## Verificações estáticas

- `pubspec.yaml` e `github-manager.json` sincronizados em `2.0.102+200116`;
- tela de novidades aponta para `2.0.102`;
- Release e Artifact usam `Versão`, badges compactos e `_CompactArtifactButton`;
- Artifact não contém mais a frase `Classificação inferida pelo nome do artifact`;
- Artifact já publicado recebe `Publicado` e não recebe callback de `Publicar`;
- parser de versão limita sufixos aos qualificadores de pré-release suportados;
- testes de contrato atualizados/adicionados para a nova interface.

## Testes de Flutter

O ambiente de edição não possui Flutter/Dart instalados. `flutter analyze` e `flutter test` devem ser executados pelo workflow CI antes da distribuição do APK.
