import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('atalhos secundarios ficam no cabeçalho e lista principal permanece compacta', () {
    final screen = File(
      'lib/features/repositories/presentation/repository_detail_screen.dart',
    ).readAsStringSync();
    final widgets = File(
      'lib/features/repositories/presentation/repository_detail_widgets.dart',
    ).readAsStringSync();

    expect(widgets, contains("tooltip: 'APKs e artifacts'"));
    expect(widgets, contains("tooltip: 'Commits'"));
    expect(widgets, contains("tooltip: 'Diagnóstico do token'"));
    expect(widgets, contains("tooltip: 'Issues / Bugs'"));

    expect(screen, isNot(contains("title: 'APKs e artifacts'")));
    expect(screen, isNot(contains("title: 'Commits'")));
    expect(screen, isNot(contains("title: 'Diagnóstico do token'")));
    expect(screen, isNot(contains("title: 'Issues / Bugs'")));

    final orderedTitles = [
      "title: 'Arquivos'",
      "title: 'Builds'",
      "title: 'Central de envios'",
      "title: 'README'",
      "title: 'Secrets'",
    ];
    var previous = -1;
    for (final title in orderedTitles) {
      final index = screen.indexOf(title);
      expect(index, greaterThan(previous));
      previous = index;
    }
  });

  test('card de Release usa excluir explícito e não exibe tag redundante', () {
    final source = File(
      'lib/features/repositories/presentation/repository_artifacts_widgets.dart',
    ).readAsStringSync();

    expect(source, contains("label: 'Excluir'"));
    expect(source, contains('Icons.delete_outline_rounded'));
    expect(source, contains("label: version!"));
    expect(source, isNot(contains("'Release \${group.tagName}'")));
    expect(source, isNot(contains('Icons.more_vert_rounded')));
  });

  test('seletor de branch possui ação Continuar explícita', () {
    final source = File(
      'lib/features/repositories/presentation/repository_branch_selector.dart',
    ).readAsStringSync();

    expect(source, contains("ValueKey('repository_branch_continue')"));
    expect(source, contains("child: const Text('Continuar')"));
    expect(source, isNot(contains('const Icon(Icons.check_circle_rounded)')));
  });
}
