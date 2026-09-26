import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tema global padroniza retângulos com o mesmo raio da Home', () {
    final card = File(
      'lib/features/repositories/presentation/repository_card.dart',
    ).readAsStringSync();
    final theme = File('lib/app/theme/app_theme.dart').readAsStringSync();

    expect(card, contains('borderRadius: BorderRadius.circular(4)'));
    expect(theme, contains('borderRadius: BorderRadius.circular(4)'));
    expect(theme, isNot(contains('BorderRadius.circular(22)')));
  });

  test('novidades automáticas usam rota opaca fora do MaterialApp.builder', () {
    final coordinator = File(
      'lib/features/update/application/startup_update_coordinator.dart',
    ).readAsStringSync();
    final app = File('lib/app/github_manager_app.dart').readAsStringSync();
    final main = File('lib/main.dart').readAsStringSync();

    expect(app, isNot(contains('StartupUpdateGate')));
    expect(app, isNot(contains('startup_update_gate.dart')));
    expect(coordinator, contains("'app.whats_new.last_seen_version'"));
    expect(coordinator, contains('MaterialPageRoute<bool>'));
    expect(coordinator, contains("RouteSettings(name: 'startup-whats-new')"));
    expect(coordinator, contains('requireConfirmation: true'));
    expect(coordinator, contains('await WidgetsBinding.instance.endOfFrame'));
    expect(coordinator, contains('AppLifecycleState.resumed'));
    expect(main, contains('StartupUpdateCoordinator.instance.start()'));
  });

  test('reattach de engine nunca dispara novidades automáticas', () {
    final coordinator = File(
      'lib/features/update/application/startup_update_coordinator.dart',
    ).readAsStringSync();
    final platform = File(
      'lib/core/platform/platform_actions.dart',
    ).readAsStringSync();
    final activity = File(
      'android/app/src/main/kotlin/br/com/githubmanager/app/MainActivity.kt',
    ).readAsStringSync();

    expect(coordinator, contains('launchState.cachedEngineReattach'));
    expect(coordinator, contains("source: 'startup.whats_new_skipped_reattach'"));
    expect(coordinator, contains('launchState.flutterUiDisplayed'));
    expect(platform, contains('getActivityLaunchState'));
    expect(activity, contains('"getActivityLaunchState"'));
    expect(activity, contains('"cachedEngineReattach" to reattachingCachedEngineOnCreate'));
    expect(activity, contains('"flutterUiDisplayed" to flutterUiDisplayed'));
  });

  test('novidades só marcam versão após Continuar e registram os marcos', () {
    final coordinator = File(
      'lib/features/update/application/startup_update_coordinator.dart',
    ).readAsStringSync();

    expect(coordinator, contains('.readJson(_lastSeenVersionKey)'));
    expect(coordinator, contains('.putJson(_lastSeenVersionKey, version)'));
    expect(coordinator, contains('final confirmed = await routeResult'));
    expect(coordinator, contains('if (confirmed == true)'));
    expect(coordinator, contains("source: 'startup.whats_new_check_started'"));
    expect(coordinator, contains("source: 'startup.whats_new_needed'"));
    expect(coordinator, contains("source: 'startup.whats_new_route_opened'"));
    expect(coordinator, contains("source: 'startup.whats_new_first_frame'"));
    expect(coordinator, contains("source: 'startup.whats_new_continue'"));
  });

  test('tela de novidades possui confirmação explícita e mudanças atuais', () {
    final screen = File(
      'lib/features/update/presentation/update_whats_new_screen.dart',
    ).readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final currentVersion = RegExp(r'^version: ([^+\n]+)\+', multiLine: true)
        .firstMatch(pubspec)!
        .group(1)!;

    expect(screen, contains("releaseNotesVersion = '$currentVersion'"));
    expect(screen, contains("'Novidades da atualização'"));
    expect(screen, contains("ValueKey('whats_new_continue')"));
    expect(screen, contains("label: const Text('Continuar')"));
    expect(screen, contains("title: 'Builds mais fáceis de ler'"));
    expect(screen, contains("title: 'Detalhes técnicos sob demanda'"));
  });
}
