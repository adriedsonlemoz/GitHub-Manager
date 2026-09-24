import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('confirmZip returns typed result and can request branch change', () {
    final source = File(
      'lib/features/repositories/presentation/repository_detail_screen_actions.dart',
    ).readAsStringSync();

    final start = source.indexOf(
      'Future<_ConfirmZipResult?> _confirmZip(',
    );
    final end = source.indexOf(
      'Future<void> _showBuildSafetyHelp(',
      start,
    );

    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));

    final block = source.substring(start, end);
    expect(block, contains('showDialog<_ConfirmZipResult>'));
    expect(block, contains("actionLabel: 'Alterar'"));
    expect(block, contains('const _ConfirmZipResult.changeBranch()'));
    expect(block, contains('_ConfirmZipResult.submit(buildPolicy)'));
    expect(block, isNot(contains('Navigator.pop(dialogContext, true)')));
  });

  test('send flow reloads branch-dependent data after changing branch', () {
    final source = File(
      'lib/features/repositories/presentation/repository_detail_screen_actions.dart',
    ).readAsStringSync();

    final start = source.indexOf('Future<void> _sendBuild(');
    final end = source.indexOf(
      'Future<RepositoryBranch?> _chooseUploadBranch(',
      start,
    );
    final block = source.substring(start, end);

    expect(block, contains('while (true)'));
    expect(block, contains('if (confirmation.changeBranch)'));
    expect(block, contains('initialBranchName: targetBranch.name'));
    expect(block, contains('.load(repository, branch: targetBranch.name)'));
    expect(block, contains('_detectBranchApkWorkflow('));
  });

  test('branch é escolhida antes do pre-check de sincronização', () {
    final source = File(
      'lib/features/repositories/presentation/repository_detail_screen_actions.dart',
    ).readAsStringSync();

    final start = source.indexOf('Future<void> _sendBuild(');
    final end = source.indexOf('Future<RepositoryBranch?> _chooseUploadBranch(', start);
    final block = source.substring(start, end);
    final chooseIndex = block.indexOf('await _chooseUploadBranch(repository)');
    final preflightIndex = block.indexOf('await ensureRepositoryPermission(');

    expect(chooseIndex, greaterThanOrEqualTo(0));
    expect(preflightIndex, greaterThan(chooseIndex));
  });

  test('lista vazia de branches é tratada como repositório vazio, não falha de API', () {
    final source = File(
      'lib/features/repositories/presentation/repository_detail_screen_actions.dart',
    ).readAsStringSync();

    expect(source, contains('final repositoryIsEmpty = branches.isEmpty;'));
    expect(source, contains('O primeiro envio inicializará a branch'));
    expect(source, contains("sha: ''"));
  });

}
