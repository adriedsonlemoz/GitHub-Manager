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
