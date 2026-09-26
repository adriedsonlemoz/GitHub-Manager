import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('detalhes da execução priorizam resumo e escondem metadados técnicos', () {
    final widgets = File(
      'lib/features/repositories/presentation/repository_run_details_widgets.dart',
    ).readAsStringSync();

    expect(widgets, contains("'Resumo'"));
    expect(widgets, contains('class _RunSummaryTile'));
    expect(widgets, contains("'Evento'"));
    expect(widgets, contains("'Branch'"));
    expect(widgets, contains("'Duração'"));
    expect(widgets, contains("'Etapas'"));
    expect(widgets, contains("'Detalhes técnicos'"));
    expect(widgets, contains("'Execução, commit, horários e workflow'"));
    expect(widgets, isNot(contains("'Informações da execução'")));
  });

  test('resultado de APK e diagnóstico de falha usam hierarquia compacta', () {
    final widgets = File(
      'lib/features/repositories/presentation/repository_run_details_widgets.dart',
    ).readAsStringSync();
    final sheet = File(
      'lib/features/repositories/presentation/repository_run_details.dart',
    ).readAsStringSync();

    expect(widgets, contains("'APK não gerado'"));
    expect(widgets, contains("'Falha identificada'"));
    expect(widgets, contains("'Detalhes do diagnóstico'"));
    expect(widgets, contains("'Job, horários e contexto do log'"));
    expect(sheet, isNot(contains('_run.commitMessage.split')));

    final failureIndex = sheet.indexOf('_FailureSummaryCard(');
    final summaryIndex = sheet.indexOf('_RunInformationCard(run: _run, jobs: jobs)');
    expect(failureIndex, greaterThanOrEqualTo(0));
    expect(summaryIndex, greaterThan(failureIndex));
  });
}
