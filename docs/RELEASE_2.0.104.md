# GitHub Manager 2.0.104+200118

## Objetivo

Eliminar a possibilidade de a tela automática de novidades participar do mesmo ciclo visual da splash/reattach do Android.

## Mudanças

- `StartupUpdateGate` removido do `MaterialApp.builder` e do projeto.
- Novo `StartupUpdateCoordinator` abre Novidades como rota Flutter opaca.
- A abertura só ocorre com app em `resumed`, após dois frames, estabilização e `onFlutterUiDisplayed()` confirmado pela Activity.
- Reattach de `FlutterEngine` cacheado nunca abre a rota automática naquele ciclo.
- `MainActivity` expõe `getActivityLaunchState` ao Flutter.
- A versão só é marcada como vista após **Continuar**.
- Telemetria local registra os marcos do fluxo de Novidades.
- A tela manual de Novidades permanece em Configurações.

## Identidade

- versionName: `2.0.104`
- versionCode: `200118`
- applicationId: `br.com.githubmanager.app`
