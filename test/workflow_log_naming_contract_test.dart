import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('workflows usam nomes estáveis para a saída de logs', () {
    expect(
      File('.github/workflows/ci.yml').readAsLinesSync().first,
      'name: GitHub Manager CI',
    );
    expect(
      File('.github/workflows/android-apk.yml').readAsLinesSync().first,
      'name: GitHub Manager Android APK',
    );
    expect(
      File('.github/workflows/android-release.yml').readAsLinesSync().first,
      'name: GitHub Manager Android Release',
    );
  });

  test('download interno de logs inclui o repositório sem duplicar prefixo', () {
    final managerSource = File(
      'lib/features/downloads/data/download_manager_service.dart',
    ).readAsStringSync();
    final buildsSource = File(
      'lib/features/builds/presentation/global_builds_screen.dart',
    ).readAsStringSync();

    expect(managerSource, contains('final safeRepositoryName = _safeName(repositoryName);'));
    expect(managerSource, contains("fileName: '\$fileStem-logs.zip'"));
    expect(
      buildsSource,
      contains("runTitle: '\${entry.run.name}-\${entry.run.runNumber}'"),
    );
  });
}
