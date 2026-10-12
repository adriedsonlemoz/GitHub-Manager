import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// O checkout pode manter ci.yml após um ZIP incremental. Só aceitamos
/// ausência real OU a configuração de migração que não dispara em push/PR
/// nem executa job quando acionada manualmente.
void expectLegacyCiDormantOrRemoved() {
  final legacy = File('.github/workflows/ci.yml');
  if (!legacy.existsSync()) return;
  final definition = legacy.readAsStringSync();
  expect(
    definition,
    contains('name: GitHub Manager CI (legado desativado)'),
    reason: 'O CI antigo ainda está ativo. Envie ci.yml desativado deste ZIP '
        'para substituir o arquivo remoto, ou exclua-o no GitHub.',
  );
  expect(
    definition,
    contains('on:\n  workflow_dispatch:\n\npermissions:\n  contents: read\n\njobs:\n'),
  );
  expect(definition, isNot(contains('\n  push:')));
  expect(definition, isNot(contains('\n  pull_request:')));
  expect(definition, isNot(contains('\n  schedule:')));
  expect(definition, contains(r'if: ${{ false }}'));
  expect(definition, contains('contents: read'));
}

void main() {
  test('workflows usam nomes estáveis para a saída de logs', () {
    expectLegacyCiDormantOrRemoved();
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
    expectLegacyCiDormantOrRemoved();
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
