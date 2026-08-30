# GitHub Manager 2.0.55

Versão: `2.0.55+200069`

## Correções

- reconhece projetos Android/Kotlin nativos cujo módulo principal está em `app/`;
- lê `versionName`, `versionCode`, `applicationId` e `namespace` de `app/build.gradle.kts` e `app/build.gradle`;
- mantém suporte aos caminhos Flutter `android/app/build.gradle(.kts)`;
- usa a mesma detecção ao analisar ZIPs enviados;
- resolve a versão dos runs/builds do GitHub Actions também por Gradle nativo;
- adiciona testes específicos para o formato Kotlin do Nômade Raiz.
