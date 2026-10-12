import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('downloads APK passam por inspeção dos bytes antes de publicar', () {
    final download = File('lib/features/downloads/data/download_manager_service.dart')
        .readAsStringSync();
    final inspector = File('lib/features/downloads/domain/apk_package_inspector.dart')
        .readAsStringSync();
    expect(download, contains('ApkPackageInspection.inspect(source)'));
    expect(download, contains('item.inspectedAbis = inspection.nativeAbis'));
    expect(download.indexOf('ApkPackageInspection.inspect(source)'),
        lessThan(download.indexOf("item.failureStage = 'salvar_downloads'")));
    expect(inspector, contains("names.contains('AndroidManifest.xml')"));
    expect(inspector, contains("name.endsWith('.so')"));
  });

  test('metadados de versões não são inferidos de run_number', () {
    final manifest = File('lib/features/builds/domain/build_manifest.dart')
        .readAsStringSync();
    final workflow = File('.github/workflows/android-apk.yml').readAsStringSync();
    expect(manifest, contains("json['version_name']"));
    expect(manifest, contains("json['version_code']"));
    expect(manifest, contains("json['run_id']"));
    expect(workflow, contains('build-info.json'));
    expect(workflow, contains('name: build-info-'));
  });
}
