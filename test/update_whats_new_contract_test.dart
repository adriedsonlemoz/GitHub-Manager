import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cards da Home usam cantos quase retos sem mudar o tema global', () {
    final card = File(
      'lib/features/repositories/presentation/repository_card.dart',
    ).readAsStringSync();
    final theme = File('lib/app/theme/app_theme.dart').readAsStringSync();

    expect(card, contains('borderRadius: BorderRadius.circular(4)'));
    expect(theme, contains('borderRadius: BorderRadius.circular(22)'));
  });

  test('novidades são controladas por versão e não bloqueiam o startup', () {
    final gate = File(
      'lib/features/update/presentation/startup_update_gate.dart',
    ).readAsStringSync();
    final app = File('lib/app/github_manager_app.dart').readAsStringSync();

    expect(gate, contains("'app.whats_new.last_seen_version'"));
    expect(gate, contains('InstalledVersionBanner.versionLabel'));
    expect(gate, contains('.readJson(_lastSeenVersionKey)'));
    expect(gate, contains('.putJson(_lastSeenVersionKey, version)'));
    expect(gate, contains('unawaited(_markVersionAsSeen(version))'));
    expect(gate, contains('addPostFrameCallback'));
    expect(app, contains('StartupUpdateGate('));
  });

  test('tela de novidades possui confirmação explícita', () {
    final screen = File(
      'lib/features/update/presentation/update_whats_new_screen.dart',
    ).readAsStringSync();

    expect(screen, contains("'Novidades da atualização'"));
    expect(screen, contains("ValueKey('whats_new_continue')"));
    expect(screen, contains("label: const Text('Continuar')"));
  });
}
