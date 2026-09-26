import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android expõe ABIs e dados básicos sem permissão adicional', () {
    final activity = File(
      'android/app/src/main/kotlin/br/com/githubmanager/app/MainActivity.kt',
    ).readAsStringSync();
    final platform = File(
      'lib/core/platform/platform_actions.dart',
    ).readAsStringSync();
    final settings = File(
      'lib/features/settings/presentation/settings_widgets.dart',
    ).readAsStringSync();

    expect(activity, contains('"getDeviceInfo"'));
    expect(activity, contains('Build.SUPPORTED_ABIS.toList()'));
    expect(activity, contains('Build.SUPPORTED_64_BIT_ABIS.toList()'));
    expect(platform, contains('class AndroidDeviceInfo'));
    expect(platform, contains('getAndroidDeviceInfo'));
    expect(settings, contains("'Arquitetura principal'"));
    expect(settings, contains("'Arquiteturas suportadas'"));
    expect(settings, contains("'Suporte a 64 bits'"));
  });
}
