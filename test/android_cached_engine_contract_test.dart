import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reabertura usa cachedEngineId e preserva engine sem splash presa', () {
    final activity = File(
      'android/app/src/main/kotlin/br/com/githubmanager/app/MainActivity.kt',
    ).readAsStringSync();
    final nightStyles = File(
      'android/app/src/main/res/values-night/styles.xml',
    ).readAsStringSync();
    final nightColors = File(
      'android/app/src/main/res/values-night/colors.xml',
    ).readAsStringSync();

    expect(activity, contains('override fun getCachedEngineId()'));
    expect(activity, contains('cachedRunningEngine()'));
    expect(activity, contains('dartExecutor.isExecutingDart'));
    expect(activity, contains('setTheme(R.style.NormalTheme)'));
    expect(activity, contains('override fun onFlutterUiDisplayed()'));
    expect(activity, contains('flutterUiDisplayed = true'));
    expect(activity, contains('reattachingCachedEngineOnCreate'));
    expect(activity, contains('\"getActivityLaunchState\"'));
    expect(activity, contains('shouldDestroyEngineWithHost(): Boolean = false'));
    expect(activity, isNot(contains('override fun provideFlutterEngine')));
    expect(nightStyles, contains('Theme.Material.NoActionBar'));
    expect(nightStyles, contains('android:windowLightStatusBar">false'));
    expect(nightColors, contains('#050B14'));
  });
}
