# GitHub Manager 2.0.29+200043

## Hotfix de compilação e CI

- Corrige o erro de compilação do módulo Secrets causado pelo uso de `PlatformFile.size` com `file_picker 12.0.0`.
- O tamanho do arquivo de importação agora é obtido por `await PlatformFile.length()`, mantendo o limite preventivo antes de `readAsBytes()`.
- A CI não falha mais apenas porque o formatter atual ajustaria arquivos preexistentes.
- `dart format lib test` normaliza a cópia do runner, registra warning quando houver diferenças e então segue para análise e testes.
- `flutter analyze` e `flutter test` continuam obrigatórios e reprovam a pipeline em erros reais.
