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

### Futuro VPS
A VPS deve entrar atrás de uma interface, por exemplo `BuildProvider`, com implementações GitHub Actions e VPS. A UI não depende da implementação concreta.

## Central de Envios

`UploadManagerService` mantém a fila global de sincronizações de ZIP e o histórico persistido. A tela do repositório apenas seleciona/confirma o projeto e entrega o trabalho ao gerenciador; por isso o painel pode ser minimizado sem cancelar o envio.

As mutações de sincronização são executadas sequencialmente. O serviço de upload compara o SHA Git (`blob <tamanho>\0<conteúdo>`) com a árvore atual e reutiliza blobs idênticos, evitando chamadas desnecessárias à API. Se o processo do Android for encerrado, um envio ativo é restaurado como interrompido e pode ser repetido pela Central de Envios.
