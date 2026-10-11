# GitHub Manager 2.0.109+200123

## Novidades

- **Builds** tem agora dois modos: **Último commit** (padrão) e **Histórico recente** (até 25 execuções consultadas por repositório). A quantidade depende do que o GitHub retorna na primeira página e de permissões.
- Pesquisa por projeto, workflow, branch, versão, número de execução ou SHA; filtros por status, branch, workflow e últimos 7/30/90 dias.
- Cards exibem duração baseada nos horários do GitHub, tentativa e SHA; no histórico, comparam a duração e o status com a execução anterior do mesmo workflow, quando disponível.
- Botão **Etapas/Diagnóstico** consulta jobs e etapas apenas quando aberto; em falhas também tenta annotations e trechos relevantes do log, sem custo extra no polling.
- Atualização adaptativa: builds ativas em intervalos mínimos de 15 s; varredura geral a cada 60 s. Último horário efetivo de consulta visível. Ao retomar o app, solicita atualização. Falhas parciais preservam dados anteriores quando possível.
- APKs: prioriza artifacts da execução; não oculta artifacts por haver uma Release da mesma arquitetura. Releases encontradas por SHA/versão exigem confirmação, pois a associação não é exclusiva da execução.
- **Segurança de exclusão:** apagar uma execução **nunca exclui automaticamente APKs de Releases** apenas por compartilhar commit. Assets de Release devem ser excluídos explicitamente na seção APKs/Releases, se desejado.

## Observações

- A API de listagem recente está limitada a 25 execuções por repositório; o histórico não é uma sincronização completa nem armazenamento permanente.
- Duração de runs concluídos usa `updated_at - run_started_at` (ou `created_at`), podendo incluir tempo de atualização posterior à execução. Não há progresso percentual inventado; a quantidade de etapas só aparece quando solicitada ao GitHub.
- A versão de release encontrada pelo mesmo commit é apenas uma hipótese de associação, nunca autorização para exclusão.
- Sem Flutter/Dart SDK neste ambiente, análise de compilação e execução de testes devem ser realizadas na CI GitHub Actions ou computador com Flutter instalado.

## Arquivos centrais

- `lib/features/builds/data/global_builds_service.dart`
- `lib/features/builds/domain/global_build_entry.dart`
- `lib/features/builds/presentation/global_builds_screen.dart`
- `lib/features/builds/presentation/global_build_diagnostics.dart`
- `lib/features/builds/data/build_cleanup_service.dart`
- `lib/features/repositories/presentation/repository_run_details_controller.dart`

## Versão

- versionName: `2.0.109`
- versionCode: `200123`
- canônica: `pubspec.yaml`, `2.0.109+200123`.
