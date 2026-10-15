import 'package:flutter_test/flutter_test.dart';
import 'package:github_manager/features/builds/domain/action_artifact.dart';
import 'package:github_manager/features/builds/domain/latest_apk_shortcut.dart';
import 'package:github_manager/features/builds/domain/release_asset.dart';

ReleaseAsset _release(int id, String file, {String tag = 'dev'}) => ReleaseAsset(
      id: id,
      name: file,
      sizeBytes: 12345,
      downloadUrl: 'https://example.invalid/file',
      tagName: tag,
      publishedAt: DateTime.utc(2026, 10, 10),
      releaseId: 12,
      releaseName: 'Release',
      targetCommitish: 'main',
    );

ActionArtifact _artifact(
  int id,
  String name, {
  int? run,
  int day = 12,
  bool expired = false,
}) => ActionArtifact(
      id: id,
      name: name,
      sizeBytes: 123456,
      expired: expired,
      createdAt: DateTime.utc(2026, 10, day),
      workflowRunId: run,
    );

void main() {
  test('APK de Release é encontrado mesmo sem artifacts disponíveis', () {
    final result = LatestApkShortcut.resolve(
      releases: [_release(1, 'Vigia-IA-1.0.232-arm64-v8a.apk')],
      artifacts: [],
    );
    expect(result.isEmpty, isFalse);
    expect(result.isRelease, isTrue);
    expect(result.version, '1.0.232');
  });

  test('variações arm64 arm32 x86 e universal da última versão são oferecidas', () {
    final result = LatestApkShortcut.resolve(
      releases: [
        _release(1, 'App-1.0.230.apk'),
        _release(2, 'App-1.0.232-arm64-v8a.apk'),
        _release(3, 'App-1.0.232-armeabi-v7a.apk'),
        _release(4, 'App-1.0.232-x86.apk'),
        _release(5, 'App-1.0.232-universal.apk'),
        _release(6, 'App-1.0.232-debug-symbols.zip'),
      ],
      artifacts: [],
    );
    expect(result.version, '1.0.232');
    expect(result.releaseAssets, hasLength(4));
    expect(result.hasVariants, isTrue);
    expect(result.releaseAssets.every((asset) => asset.isApk), isTrue);
  });

  test('artifact mais novo, com versão explicitamente maior, prevalece', () {
    final result = LatestApkShortcut.resolve(
      releases: [_release(1, 'App-1.0.231.apk')],
      artifacts: [_artifact(22, 'App-1.0.232-arm64-v8a-apk', run: 100)],
    );
    expect(result.isRelease, isFalse);
    expect(result.artifacts.single.id, 22);
  });

  test('variants de artifact usam a mesma execução, sem misturar anteriores', () {
    final result = LatestApkShortcut.resolve(releases: [], artifacts: [
      _artifact(1, 'App-1.0.230-arm64-apk', run: 1, day: 10),
      _artifact(2, 'App-1.0.232-arm64-apk', run: 2),
      _artifact(3, 'App-1.0.232-armv7-apk', run: 2),
      _artifact(4, 'App-1.0.232-x86-apk', run: 2),
    ]);
    expect(result.artifacts, hasLength(3));
    expect(result.artifacts.every((item) => item.workflowRunId == 2), isTrue);
  });

  test('Artifact expirado não habilita download', () {
    final result = LatestApkShortcut.resolve(
      releases: [],
      artifacts: [_artifact(1, 'App-1.0.232-apk', expired: true)],
    );
    expect(result.isEmpty, isTrue);
  });

  test('Release é escolhida quando artifact não informa versão verificável', () {
    final result = LatestApkShortcut.resolve(
      releases: [_release(1, 'App-1.0.232.apk')],
      artifacts: [_artifact(20, 'Android-APK', run: 9)],
    );
    expect(result.isRelease, isTrue);
  });
}
