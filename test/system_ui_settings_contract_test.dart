import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:github_manager/core/platform/system_ui_settings.dart';

void main() {
  test('prefere tela inteira quando ainda não há preferência salva', () {
    expect(SystemUiSettings.enabledFromStored(null), isTrue);
    expect(SystemUiSettings.enabledFromStored(true), isTrue);
    expect(SystemUiSettings.enabledFromStored(false), isFalse);
  });

  test('modo visual é persistido e não interrompe a primeira renderização', () {
    final service = File('lib/core/platform/system_ui_settings.dart')
        .readAsStringSync();
    final main = File('lib/main.dart').readAsStringSync();
    expect(service, contains("'settings.fullscreen_enabled'"));
    expect(service, contains('LocalDatabase.shared.readJson(preferenceKey)'));
    expect(service, contains('LocalDatabase.shared.putJson(preferenceKey, enabled)'));
    expect(service, contains('SystemUiMode.immersiveSticky'));
    expect(service, contains('SystemUiMode.edgeToEdge'));
    expect(main, contains('runApp(const ProviderScope(child: GitHubManagerApp()))'));
    expect(main, contains('SystemUiSettings.instance.initialize()'));
    expect(main, contains('SystemUiSettings.instance.reapply()'));
    expect(main, contains('const Duration(milliseconds: 1250)'));
    expect(main, isNot(contains('SystemChrome.setEnabledSystemUIMode(')));
  });

  test('aparência permite alternar modo em tempo real e mantém histórico', () {
    final settings = File('lib/features/settings/presentation/settings_screen.dart')
        .readAsStringSync();
    final actions = File('lib/features/settings/presentation/settings_screen_actions.dart')
        .readAsStringSync();
    expect(settings, contains("title: const Text('Tela inteira')"));
    expect(settings, contains('ValueListenableBuilder<bool>'));
    expect(settings, contains('valueListenable: SystemUiSettings.instance'));
    expect(settings, contains('_setFullScreenEnabled'));
    expect(actions, contains('SystemUiSettings.instance.setEnabled(enabled)'));
    expect(settings, contains("version: '2.0.108'"));
    expect(settings, contains("version: '2.0.107'"));
    expect(settings, contains("version: '2.0.106'"));
  });
}
