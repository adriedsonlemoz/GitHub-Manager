# Arquitetura

```text
Flutter UI
   ↓
Providers / Controllers
   ↓
Repositories / Domain Services
   ↓
GitHubApiClient ───────→ GitHub REST API
   ↓
Local data sources ────→ SQLite
   ↓
SecureStorageService ──→ Android secure storage
```

## Princípios

### Local-first
O app abre sem internet. Configurações, cache e histórico permanecem acessíveis. Recursos remotos falham de forma controlada.

### Feature-first

```text
features/
  auth/
  home/
  repositories/
  projects/
  actions/
  artifacts/
  releases/
  secrets/
  variables/
  api_vault/
```

### Sem serviço GitHub monolítico
Planejado: `RepositoryService`, `GitContentService`, `GitTreeService`, `BranchService`, `CommitService`, `ActionsService`, `ArtifactService`, `ReleaseService`, `SecretsService`, `VariablesService`.

### Persistência
SQLite guarda cache, favoritos, histórico, metadados e logs sanitizados. Credenciais ficam fora do banco.

`LocalDatabase.shared` é o único proprietário da conexão SQLite dentro de cada isolate. A UI/provider reutiliza a mesma conexão durante toda a sessão; serviços auxiliares não devem abrir/fechar handles próprios. O callback do WorkManager roda em outro isolate e recebe naturalmente seu próprio `LocalDatabase.shared`. O esquema continua idempotente e pode ser reparado/reconstruído sem apagar o token seguro.

### Futuro VPS
A VPS deve entrar atrás de uma interface, por exemplo `BuildProvider`, com implementações GitHub Actions e VPS. A UI não depende da implementação concreta.

## Central de Envios

`UploadManagerService` mantém a fila global de sincronizações de ZIP e o histórico persistido. A tela do repositório apenas seleciona/confirma o projeto e entrega o trabalho ao gerenciador; por isso o painel pode ser minimizado sem cancelar o envio.

As mutações de sincronização são executadas sequencialmente. O serviço de upload compara o SHA Git (`blob <tamanho>\0<conteúdo>`) com a árvore atual e reutiliza blobs idênticos, evitando chamadas desnecessárias à API.

Durante um envio existe um foreground service Android do tipo `dataSync`. Ele mantém uma notificação persistente e, em conjunto com o FlutterEngine principal mantido em cache, permite que a sincronização continue quando a Activity é removida dos recentes enquanto o processo permanece vivo. Ao reabrir o app no mesmo processo, `MainActivity.getCachedEngineId()` só aponta para o engine preservado quando o isolate já está executando; o reattach usa `NormalTheme` imediatamente e mantém `shouldDestroyEngineWithHost() = false`, evitando que a splash de cold start seja tratada como se o engine ainda aguardasse o primeiro frame.

Cada blob remoto criado é salvo no histórico como checkpoint de conteúdo. Se o processo for realmente encerrado, o próximo início do app restaura a fila automaticamente: blobs cujo SHA ainda corresponde ao ZIP são reutilizados e, se o commit já foi persistido, a retomada pula diretamente para a etapa de build. `Forçar parada` e encerramento do processo pelo sistema não podem executar código em segundo plano; nesses casos a retomada acontece ao abrir o GitHub Manager novamente.

## Telemetria local de estabilidade (2.0.101)

`AppTelemetryService` centraliza falhas capturadas pelo Flutter/Dart e persiste um histórico curto no SQLite (`error_telemetry`). `main.dart` conecta `FlutterError.onError`, `PlatformDispatcher.onError` e `runZonedGuarded`. No Android, `GitHubManagerApplication` instala um `UncaughtExceptionHandler` antes da Activity e preserva o último crash fatal em `SharedPreferences`; `MainActivity` entrega esse registro ao Flutter no próximo acesso. O mesmo armazenamento nativo registra o último `cached_engine_reattach`, importado como evento informativo `android.engine_reattach` no `resumed` do Flutter. A telemetria é local, opt-out e não possui endpoint de envio automático.
