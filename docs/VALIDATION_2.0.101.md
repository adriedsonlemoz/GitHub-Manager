# Validação — GitHub Manager 2.0.101+200115

## Verificações estáticas executadas

- sincronismo entre `pubspec.yaml` e `github-manager.json`;
- JSON do manifesto validado;
- XML do `AndroidManifest.xml` validado;
- scripts shell verificados com `bash -n`;
- varredura de todos os `BorderRadius.circular(...)` em `lib/`;
- somente raio `4` é aceito para retângulos explícitos; `99/999` ficam reservados a pills deliberadas;
- presença dos handlers globais Flutter/Dart e do `UncaughtExceptionHandler` Android conferida;
- tabela `error_telemetry`, retenção e sanitização protegidas por testes de contrato;
- gate de novidades protegido por teste para garantir persistência somente após **Continuar**.

## Limitação do ambiente

O ambiente de edição não possui Flutter/Dart instalados. Portanto `flutter analyze`, `flutter test` e o build Android completo não puderam ser executados localmente. Os testes e workflows do projeto permanecem preparados para executar essas validações no GitHub Actions.
