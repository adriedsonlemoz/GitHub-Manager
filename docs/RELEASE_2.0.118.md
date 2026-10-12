# GitHub Manager 2.0.118+200132

## CI independente removida sem desativar os testes de compilação

- O arquivo `.github/workflows/ci.yml` foi removido. Evita duplicação de tarefas na branch `main`.
- O workflow **GitHub Manager Android APK** continua validando `pubspec.yaml`/`github-manager.json`/UI por `tool/check_version_sync.sh`, executando `flutter analyze` e `flutter test` antes da compilação. Continua validando assinatura/configuração, arquitetura e identidade do APK.
- O workflow **GitHub Manager Android Release** preserva análise, testes e verificação do certificado oficial de assinatura.
- Nenhum teste Dart foi removido e as funcionalidades do aplicativo permaneceram inalteradas.
- Ajustado o teste de contrato dos workflows, README, CHANGELOG, VERSIONING, Novidades e Configurações.

## Atenção à proteção de branches

Caso `main` ou outra branch exija o check antigo `Analisar e testar` do workflow `GitHub Manager CI`, ajuste **GitHub → Settings → Rules → Rulesets** ou **Settings → Branches → Branch protection rules**. Remover a exigência do check antigo ou substituí-la pelo job `Build APK oficial universal`, conforme sua política de revisão. Regras de branch não são alteradas automaticamente ao excluir o arquivo YAML.

## Limitação

CI redundante removida; erros reais em `flutter analyze`, `flutter test` ou na compilação ainda impedirão o APK, como medida de segurança. O código não foi compilado nem testado em Android neste ambiente.
