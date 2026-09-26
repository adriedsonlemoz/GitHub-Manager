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

  test('novidades são controladas por versão e só marcam após continuar', () {
    final gate = File(
      'lib/features/update/presentation/startup_update_gate.dart',
    ).readAsStringSync();
    final app = File('lib/app/github_manager_app.dart').readAsStringSync();

    expect(gate, contains("'app.whats_new.last_seen_version'"));
    expect(gate, contains('InstalledVersionBanner.versionLabel'));
    expect(gate, contains('.readJson(_lastSeenVersionKey)'));
    expect(gate, contains('.putJson(_lastSeenVersionKey, version)'));
    expect(gate, contains('await _markVersionAsSeen(version)'));
    expect(gate, isNot(contains('unawaited(_markVersionAsSeen(version))')));
    expect(gate, contains('addPostFrameCallback'));
    expect(app, contains('StartupUpdateGate('));
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
    expect(screen, contains("title: 'Retorno imediato ao aplicativo'"));
    expect(screen, contains("title: 'Diagnóstico de reabertura'"));
  });
}
