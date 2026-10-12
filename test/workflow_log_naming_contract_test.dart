import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('workflows usam nomes estáveis para a saída de logs', () {
    expect(File('.github/workflows/ci.yml').existsSync(), isFalse);
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

    expect(
      managerSource,
      contains('final safeRepositoryName = _safeName(repositoryName);'),
    );
    expect(managerSource, contains("fileName: '\$fileStem-logs.zip'"));
    expect(
      buildsSource,
      contains("runTitle: '\${entry.run.name}-\${entry.run.runNumber}'"),
    );
  });
  test('APK e Release mantêm análise e testes sem workflow CI duplicado', () {
    expect(File('.github/workflows/ci.yml').existsSync(), isFalse);
    for (final workflowPath in [
      '.github/workflows/android-apk.yml',
      '.github/workflows/android-release.yml',
    ]) {
      final workflow = File(workflowPath).readAsStringSync();
      expect(workflow, contains('bash tool/check_version_sync.sh'));
      expect(workflow, contains('flutter analyze --no-pub'));
      expect(workflow, contains('flutter test --no-pub'));
      expect(workflow, contains('flutter build apk --release --no-pub'));
    }
    final apk = File('.github/workflows/android-apk.yml').readAsStringSync();
    final release = File('.github/workflows/android-release.yml').readAsStringSync();
    expect(apk, contains('Validar APK, assinatura e compatibilidade'));
    expect(release, contains('Verificar APK e certificado oficial'));
  });
}
