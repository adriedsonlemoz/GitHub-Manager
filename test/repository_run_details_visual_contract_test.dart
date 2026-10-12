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

  test('falha fica compacta e abre explicação em janela dedicada', () {
    final widgets = File(
      'lib/features/repositories/presentation/repository_run_details_widgets.dart',
    ).readAsStringSync();
    final sheet = File(
      'lib/features/repositories/presentation/repository_run_details.dart',
    ).readAsStringSync();

    expect(widgets, contains("'Ver erros'"));
    expect(widgets, contains('class _FailureDetailsDialog'));
    expect(widgets, contains("'O que aconteceu'"));
    expect(widgets, contains("'Onde aconteceu'"));
    expect(widgets, contains("'Causa identificada'"));
    expect(widgets, contains("'Possível causa'"));
    expect(widgets, contains("'Como corrigir'"));
    expect(widgets, contains("'Copiar erro'"));
    expect(widgets, contains("'Copiar diagnóstico'"));
    expect(widgets, contains("'Logs completos'"));
    expect(widgets, isNot(contains("'Detalhes do diagnóstico'")));
    expect(sheet, isNot(contains('_run.commitMessage.split')));

    final failureIndex = sheet.indexOf('_FailureSummaryCard(');
    final summaryIndex = sheet.indexOf('_RunInformationCard(run: _run, jobs: jobs)');
    expect(failureIndex, greaterThanOrEqualTo(0));
    expect(summaryIndex, greaterThan(failureIndex));
  });

  test('botão APK usa seletor vinculado à execução', () {
    final sheet = File(
      'lib/features/repositories/presentation/repository_run_details.dart',
    ).readAsStringSync();
    final controller = File(
      'lib/features/repositories/presentation/repository_run_details_controller.dart',
    ).readAsStringSync();
    final widgets = File(
      'lib/features/repositories/presentation/repository_run_details_widgets.dart',
    ).readAsStringSync();

    expect(sheet, contains('onPressed: _working ? null : _openRunApks'));
    expect(controller, contains('listArtifactsForRun'));
    expect(controller, contains('findReleaseApksForBuild'));
    expect(controller, contains('apkRecommendationRank'));
    expect(controller, contains('showSmartApkPicker<_RunApkCandidate>'));
    final picker = File(
      'lib/features/builds/presentation/smart_apk_picker.dart',
    ).readAsStringSync();
    expect(picker, contains("'APKs disponíveis'"));
    expect(picker, contains('Baixar opção sugerida'));
    expect(widgets, contains('class _RunApkCandidate'));
  });
}
