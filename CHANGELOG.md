# Changelog

## 2.0.74+200088 — 2026-09-23

- O envio de uma nova versão agora permite escolher a branch de destino antes da conferência; a última branch escolhida por repositório é lembrada localmente e branches protegidas são identificadas.
- A comparação de identidade/versão do projeto passa a consultar a branch realmente selecionada, evitando comparar `dev`/`release` contra `main`.
- Adicionada a aba global **Builds** no menu inferior, reunindo as execuções recentes do GitHub Actions de todos os projetos e permitindo filtrar por executando, sucesso ou falha.
- **Acompanhados** foi movido para dentro de Projetos em um seletor `Meus projetos / Acompanhados`, mantendo cinco itens no menu inferior.
- Projetos sem workflow de APK, como scripts e utilitários que não precisam de compilação, agora são identificados já na conferência e terminam como **Projeto atualizado • Sem workflow de build**, sem falso erro ou estado de build pendente.
- O pré-check de **Enviar nova versão** exige somente permissão de Contents; permissões de Actions continuam necessárias apenas para operações de build.
- Quando um workflow de APK é detectado, a conferência permite desmarcar **Iniciar build após o envio**; nesse caso o projeto é sincronizado sem consultar/disparar Actions.
- A detecção de ausência de workflow foi antecipada para evitar espera desnecessária antes de concluir projetos que não utilizam GitHub Actions; falhas de rede/API durante a inspeção continuam sendo tratadas como diagnóstico pendente, não como ausência de workflow.
- Testes foram ampliados para cobrir branch específica, projeto sem workflow e a separação de permissões entre sincronização e build.

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
