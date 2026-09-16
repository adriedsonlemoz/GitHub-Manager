# GitHub Manager 2.0.71

Versão: `2.0.71+200085`

## Refatoração de persistência

- `LocalDatabase` passa a ter um único proprietário por isolate através de `LocalDatabase.shared`.
- O construtor público foi removido, impedindo novos serviços de abrirem conexões SQLite independentes por engano.
- A abertura do banco agora deduplica chamadas concorrentes com um único `Future<Database>` enquanto a conexão está sendo criada.
- O app volta a usar `singleInstance: true`: no isolate principal existe uma única conexão compartilhada; o callback do WorkManager, executado em outro isolate, recebe naturalmente outra conexão própria.
- `localDatabaseProvider`, startup, monitor de builds e preferências de recuperação de upload reutilizam a conexão do isolate e não a fecham após operações curtas.
- `rebuildLocalDatabase()` é o único fluxo que fecha internamente a conexão compartilhada antes de remover e reabrir o banco.

## Prevenção

- Elimina o padrão que motivou o workaround `singleInstance: false` da 2.0.67.
- Reduz risco de uma operação auxiliar fechar a conexão que a tela de Projetos/Configurações ainda está usando.
- Reduz abertura simultânea de handles SQLite e possibilidade de disputa desnecessária durante migração, monitoramento e leitura de preferências.
- O esquema idempotente e o reparo introduzidos na 2.0.67 permanecem intactos.
- O teste de contrato do banco agora verifica que `LocalDatabase.shared` é estável dentro do isolate.

## Compatibilidade

- Nenhuma tabela foi removida e `schemaVersion` permanece em 2, portanto esta versão não força migração destrutiva.
- Token GitHub continua fora do SQLite em `flutter_secure_storage`.
