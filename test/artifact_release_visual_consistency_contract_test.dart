import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Release e Artifact usam a mesma hierarquia visual de versão e ações', () {
    final widgets = File(
      'lib/features/repositories/presentation/repository_artifacts_widgets.dart',
    ).readAsStringSync();
    final screen = File(
      'lib/features/repositories/presentation/repository_artifacts_screen.dart',
    ).readAsStringSync();

    expect(RegExp("'Versão'").allMatches(widgets).length, greaterThanOrEqualTo(2));
    expect(widgets, contains("label: 'Artifact'"));
    expect(widgets, contains("label: 'Release'"));
    expect(widgets, contains("'Baixar'"));
    expect(widgets, contains("label: 'Publicar'"));
    expect(widgets, contains("label: 'Excluir'"));
    expect(widgets, contains("label: 'Publicado'"));
    expect(widgets, isNot(contains('Classificação inferida pelo nome do artifact')));
    expect(widgets, isNot(contains("stability = 'Estável provável'")));
    expect(screen, contains('publishedRelease: publishedRelease'));
    expect(screen, contains('publishedRelease == null'));
  });

  test('parser visual ignora versionCode e sufixos do nome do APK', () {
    final screen = File(
      'lib/features/repositories/presentation/repository_artifacts_screen.dart',
    ).readAsStringSync();

    expect(
      screen,
      contains('(?:-(?:alpha|beta|preview|pre|rc|dev)'),
    );
    expect(
      screen,
      isNot(contains("(?:[-+][A-Za-z0-9._-]+)?'")),
    );
  });
}
