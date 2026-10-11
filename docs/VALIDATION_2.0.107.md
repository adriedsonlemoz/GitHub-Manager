# Validação — GitHub Manager 2.0.107+200121

## Verificações estáticas

- [x] Fonte canônica `pubspec.yaml` sincronizada com `github-manager.json`.
- [x] `versionName` incrementado de 2.0.106 para 2.0.107 e `versionCode` de 200120 para 200121.
- [x] Novidades e histórico das três mudanças referenciam a versão atual.
- [x] Descrição apresentada sem `maxLines` quando a preferência está ativa.
- [x] Preferência local com valor inicial falso e propagação via Riverpod.
- [x] `valueOrNull` substituído por `asData?.value` nas alterações da funcionalidade.
- [x] Documentação de release, changelog, README e handoff atualizados.

## Dependências da CI

- [ ] `flutter analyze` e `flutter test`: não executados neste ambiente, pois Flutter/Dart não estão instalados.
- [ ] Build e instalação em Android real: ainda não verificados.

O ZIP contém o projeto-fonte, sem APK compilado.
