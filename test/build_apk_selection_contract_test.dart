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

  test('repository APK shortcut busca a última versão sem pré-desabilitar o botão', () {
    final source = File(
      'lib/features/repositories/presentation/repository_detail_screen.dart',
    ).readAsStringSync();
    final actions = File(
      'lib/features/repositories/presentation/repository_detail_screen_actions.dart',
    ).readAsStringSync();

    expect(source, contains('onTap: () => _downloadLatestApk(repository)'));
    expect(source, contains('enabled: !_apkShortcutBusy'));
    expect(source, isNot(contains('latestApk != null')));
    expect(actions, contains('listReleaseAssets(repository.fullName)'));
    expect(actions, contains('listArtifacts(repository.fullName)'));
    expect(actions, contains('LatestApkShortcut.resolve('));
    expect(actions, contains('showSmartApkPicker<Object>'));
    expect(actions, contains('startReleaseAsset('));
    expect(actions, contains('startArtifactApk('));
    expect(File('lib/features/builds/presentation/smart_apk_picker.dart').readAsStringSync(),
        contains('if (!preferred.exactRun && runNumber > 0)'));
  });
}
