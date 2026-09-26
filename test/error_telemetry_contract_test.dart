import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('startup registra erros globais de Flutter Dart e Android', () {
    final main = File('lib/main.dart').readAsStringSync();
    final telemetry = File(
      'lib/core/telemetry/app_telemetry_service.dart',
    ).readAsStringSync();
    final application = File(
      'android/app/src/main/kotlin/br/com/githubmanager/app/GitHubManagerApplication.kt',
    ).readAsStringSync();
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(main, contains('runZonedGuarded'));
    expect(main, contains('FlutterError.onError'));
    expect(main, contains('PlatformDispatcher.instance.onError'));
    expect(main, contains('importPendingNativeCrash'));
    expect(telemetry, contains("source: 'android.native'"));
    expect(application, contains('setDefaultUncaughtExceptionHandler'));
    expect(manifest, contains('GitHubManagerApplication'));
  });

  test('telemetria é local, limitada, sanitizada e acessível em configurações', () {
    final database = File(
      'lib/core/persistence/local_database.dart',
    ).readAsStringSync();
    final telemetry = File(
      'lib/core/telemetry/app_telemetry_service.dart',
    ).readAsStringSync();
    final settings = File(
      'lib/features/settings/presentation/settings_screen.dart',
    ).readAsStringSync();
    final router = File('lib/app/router/app_router.dart').readAsStringSync();

    expect(database, contains('CREATE TABLE IF NOT EXISTS error_telemetry'));
    expect(database, contains('LIMIT 120'));
    expect(telemetry, contains('[REDACTED]'));
    expect(telemetry, contains('Nada é enviado automaticamente'));
    expect(settings, contains("title: const Text('Erros e telemetria')"));
    expect(router, contains("path: 'telemetry'"));
  });
}
