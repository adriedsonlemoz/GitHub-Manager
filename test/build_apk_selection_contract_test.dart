import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('global Builds never picks the first APK silently', () {
    final source = File(
      'lib/features/builds/presentation/global_builds_screen.dart',
    ).readAsStringSync();

    expect(source, contains('showSmartApkPicker<_GlobalApkCandidate>'));
    expect(source, contains('SmartApkOption('));
    expect(File('lib/features/builds/presentation/smart_apk_picker.dart').readAsStringSync(), contains('Baixar opção sugerida'));
    expect(source, contains('apkRecommendationRank'));
    expect(source, contains('getAndroidDeviceInfo'));
    expect(source, isNot(contains('releaseApks.first')));
    expect(source, isNot(contains('apkArtifact = artifact;')));
  });

  test('repository APK shortcut opens the explicit APK list', () {
    final source = File(
      'lib/features/repositories/presentation/repository_detail_screen.dart',
    ).readAsStringSync();

    expect(
      source,
      contains("'/repositories/\${repository.fullName}/artifacts'"),
    );
    expect(source, isNot(contains('_downloadLatestApk(repository, latestApk)')));
  });
}
