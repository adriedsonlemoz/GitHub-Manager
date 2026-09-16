# Changelog

## 2.0.73+200087 — 2026-09-16

- Corrigidos os dois erros `non_constant_list_element` detectados nos logs Android APK 63 e CI 63.
- `leftover` em `build_cleanup_service_test.dart` passou a ser constante em tempo de compilação, preservando os testes de limpeza de artifacts.
- Removido import de teste não utilizado.
- Nenhuma regra de exclusão de build, artifact ou APK de Release foi alterada.

## 2.0.72+200086 — 2026-09-16

- Refatorado `ManagedUpload` em componentes internos de estado, diagnóstico, ciclo de vida, relatório e codec JSON.
- Preservado o contrato público usado pela Central de Envios, telas e `UploadManagerService`.
- Mantidas as mesmas 51 chaves de persistência para compatibilidade com checkpoints anteriores.
- Adicionado teste de contrato cobrindo diagnóstico, relatório, round-trip JSON e retry após a divisão.

## 2.0.71+200085 — 2026-09-16

- Refatorado o ciclo de vida do SQLite para uma única conexão compartilhada por isolate.
- Removido o construtor público de `LocalDatabase`, evitando abertura acidental de conexões independentes.
- Aberturas concorrentes do banco agora reutilizam o mesmo `Future<Database>`.
- `localDatabaseProvider`, startup, monitor de builds e preferências de recuperação deixaram de fechar o banco após operações curtas.
- `singleInstance: true` voltou a ser usado com ownership controlado por isolate.
- Mantidos reparo idempotente do esquema, reconstrução local segura e preservação do token GitHub.

## 2.0.70+200084 — 2026-09-16

- Refatoradas as telas grandes de Configurações, Detalhe do repositório, Builds/Detalhe da build e APKs/Releases.
- Exclusão de build passou a limpar artifacts e APKs de Release vinculados com segurança ao mesmo commit.
- Adicionada exclusão direta de assets de Release e paginação ampliada de Releases.

## 2.0.69+200083 — 2026-09-16

- Corrigida a referência de `_shortSha` que interrompia a compilação.
- Workflow Android passou a executar análise e testes Dart antes do Gradle.
