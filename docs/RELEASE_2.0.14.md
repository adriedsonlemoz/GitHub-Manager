# GitHub Manager 2.0.14 (200028)

## Seleção múltipla de execuções

- A tela Builds ganhou modo `Selecionar`.
- É possível marcar várias execuções concluídas e excluí-las permanentemente em uma única ação.
- Toque prolongado em uma execução também inicia a seleção.
- `Selecionar todas` marca todas as execuções concluídas visíveis no filtro atual.
- `Selecionar falhas` marca somente as execuções concluídas com falha.
- Execuções ainda em andamento não podem ser selecionadas para exclusão.
- A exclusão usa a API oficial do GitHub Actions e exige `Actions: write`.
- A confirmação informa que artifacts ligados às execuções também podem ser removidos pelo GitHub.

## Base preservada

Mantém as melhorias anteriores de artifacts, downloads organizados por projeto, cabeçalho sólido, Acompanhados, Fork, notificações e Central de Downloads.

## Validação

- Estrutura Dart verificada.
- Workflows YAML validados.
- pubspec.yaml e AndroidManifest.xml válidos.
- JSON/versionamento sincronizados.
- ZIP final testado quanto à integridade.

A compilação final deve ser confirmada pelo GitHub Actions.
