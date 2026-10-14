# GitHub Manager 2.0.123+200137

Data: 14/10/2026. VersionCode Android: 200137.

## Correção do Android APK #112

- A etapa de análise de código detectou **5 erros de tipos** em `test/static_web_project_detection_test.dart`: `ArchiveFile` da biblioteca `archive` exige conteúdo binário (`List<int>`), mas recebia texto (`String`).
- O teste agora converte HTML, CSS, JavaScript, JSON e README com `utf8.encode()`, calcula o comprimento real dos bytes e usa `ZipEncoder().encode()` sem operador `!` desnecessário.
- Foi adicionado teste de regressão de um ZIP com somente `index.html`.
- As melhorias de detecção de projetos web da 2.0.122 e as otimizações de Builds/Downloads foram preservadas.

## Validação

- Inspeção do log e correção das cinco linhas reportadas.
- Sincronização do versionamento e verificação estrutural do ZIP.
- Build Flutter/Android e testes automatizados em execução **pendentes**, pois o SDK não está presente neste ambiente.
