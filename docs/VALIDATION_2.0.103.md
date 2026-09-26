# Validação — GitHub Manager 2.0.103+200117

- `pubspec.yaml` e `github-manager.json` sincronizados em `2.0.103+200117`;
- `MainActivity` usa `getCachedEngineId()` apenas para engine existente e executando Dart;
- `provideFlutterEngine()` não é mais usado no fluxo principal;
- `shouldDestroyEngineWithHost()` permanece `false`;
- `onFlutterUiDisplayed()` reforça a troca final para `NormalTheme` e remove o background do launch;
- tema noturno de launch usa Material escuro, barras com ícones claros e fundo `#050B14`;
- telemetria importa `cached_engine_reattach` como `android.engine_reattach` no resume;
- tela de novidades aponta para `2.0.103` e contém apenas itens desta versão;
- teste `android_cached_engine_contract_test.dart` protege o comportamento.
