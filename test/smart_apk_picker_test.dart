import 'package:flutter_test/flutter_test.dart';
import 'package:github_manager/features/builds/domain/build_manifest.dart';
import 'package:github_manager/features/builds/presentation/smart_apk_picker.dart';

void main() {
  test('sugestão não pode ser considerada confirmada sem as ABIs Android', () {
    const options = [
      SmartApkOption(value: 1, name: 'app-arm64-v8a.apk', bytes: 1234, source: 'Release'),
      SmartApkOption(value: 2, name: 'app-universal.apk', bytes: 2200, source: 'Artifact', exactRun: true),
    ];
    expect(smartApkRecommendedIndex(options, const []), isNull);
    expect(smartApkRecommendedIndex(options, const ['arm64-v8a']), 0);
    expect(smartApkRecommendedIndex(options, const ['x86_64']), 1);
  });

  test('APK com arquitetura desconhecida nunca recebe recomendação forte', () {
    const options = [
      SmartApkOption(value: 1, name: 'app-release.apk', bytes: 100, source: 'Artifact'),
      SmartApkOption(value: 2, name: 'app-x86_64.apk', bytes: 100, source: 'Release'),
    ];
    expect(smartApkRecommendedIndex(options, const ['arm64-v8a']), isNull);
  });

  test('run ID e commit do manifesto precisam coincidir', () {
    final data = {
      'schema': 1,
      'run_id': 55,
      'commit_sha': 'abc12345',
      'version_name': '2.0.116',
      'version_code': 200130,
      'application_id': 'br.com.githubmanager.app',
      'apks': [{
        'file_name': 'app-universal.apk',
        'abi': 'universal',
        'size_bytes': 15489,
        'sha256': List.filled(64, 'a').join(),
      }],
    };
    expect(BuildManifest.parse(data,
        expectedRunId: 56, expectedCommit: 'abc12345'), isNull);
    expect(BuildManifest.parse(data,
        expectedRunId: 55, expectedCommit: 'wrong'), isNull);
    final manifest = BuildManifest.parse(data,
        expectedRunId: 55, expectedCommit: 'AbC12345');
    expect(manifest?.versionName, '2.0.116');
    expect(manifest?.versionCode, 200130);
    expect(manifest?.apks.single.abi, 'universal');
    expect(manifest?.apks.single.sha256.length, 64);
  });

  test('rejeita nome de arquivo malicioso no manifesto', () {
    final manifest = BuildManifest.parse({
      'schema': 1,
      'run_id': 1,
      'commit_sha': 'abcdef',
      'version_name': '1.2.3',
      'version_code': 12,
      'application_id': 'app.id',
      'apks': [{
        'file_name': '../evil.apk', 'size_bytes': 12, 'sha256': List.filled(64, 'a').join(),
      }],
    }, expectedRunId: 1, expectedCommit: 'abcdef');
    expect(manifest?.apks, isEmpty);
  });
}
