# Validação — GitHub Manager 2.0.104+200118

- `pubspec.yaml` e `github-manager.json` sincronizados em `2.0.104+200118`;
- `StartupUpdateGate` removido do código de produção;
- `MaterialApp.builder` contém apenas a árvore principal e indicadores de transferência, sem camada de Novidades;
- fluxo automático usa `StartupUpdateCoordinator` + `MaterialPageRoute` opaca;
- coordinator exige `AppLifecycleState.resumed`, frames estáveis e `flutterUiDisplayed=true`;
- `cachedEngineReattach=true` impede abertura automática de Novidades;
- `MainActivity` fornece `getActivityLaunchState` via MethodChannel;
- versão vista é persistida somente depois de **Continuar**;
- tela de Novidades aponta somente para as mudanças da 2.0.104;
- testes de contrato atualizados para proteger o desacoplamento, launch state e reattach;
- ZIP de código-fonte não deve conter APK/binários de release.

## Limitação deste ambiente

O SDK Flutter não está instalado neste ambiente; `flutter analyze` e `flutter test` devem rodar no workflow CI/Android APK do projeto.
