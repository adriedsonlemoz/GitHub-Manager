import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('detalhes da execução possuem os dois ícones no mesmo conjunto de parts', () {
    final root = File(
      'lib/features/repositories/presentation/repository_actions_screen.dart',
    ).readAsStringSync();
    final sheet = File(
      'lib/features/repositories/presentation/repository_run_details.dart',
    ).readAsStringSync();
    final widgets = File(
      'lib/features/repositories/presentation/repository_run_details_widgets.dart',
    ).readAsStringSync();

    expect(root, contains("part 'repository_run_details.dart';"));
    expect(root, contains("part 'repository_run_details_widgets.dart';"));
    expect(sheet, contains('_RunStatusIcon(run: _run)'));
    expect(sheet, contains('_JobIcon(job: job)'));
    expect(widgets, contains('class _RunStatusIcon extends StatelessWidget'));
    expect(widgets, contains('class _JobIcon extends StatelessWidget'));
    expect(widgets, contains('required this.run'));
    expect(widgets, contains('required this.job'));
  });

  test('indicadores distinguem andamento, sucesso, falha e cancelamento', () {
    final widgets = File(
      'lib/features/repositories/presentation/repository_run_details_widgets.dart',
    ).readAsStringSync();
    expect(widgets, contains('if (run.isRunning)'));
    expect(widgets, contains("if (job.status != 'completed')"));
    for (final state in ['success', 'failure', 'cancelled', 'skipped']) {
      expect(RegExp("case '$state':").allMatches(widgets).length, 2);
    }
    expect(widgets, contains('_RepositoryActionsScreenState._statusLabel(run)'));
    expect(widgets, contains('_RepositoryActionsScreenState._jobStatus(job)'));
  });
}
