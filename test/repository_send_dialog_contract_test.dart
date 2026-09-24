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

    final sendStart = source.indexOf('Future<void> _sendBuild(');
    final sendEnd = source.indexOf(
      'Future<_UploadPreparation?> _prepareUpload(',
      sendStart,
    );
    final sendBlock = source.substring(sendStart, sendEnd);

    expect(sendBlock, contains('while (true)'));
    expect(sendBlock, contains('if (confirmation.changeBranch)'));
    expect(sendBlock, contains('initialBranchName: targetBranch.name'));
    expect(sendBlock, contains('await _prepareUpload('));

    final prepareStart = source.indexOf('Future<_UploadPreparation?> _prepareUpload(');
    final prepareEnd = source.indexOf(
      'Future<RepositoryPermissionPreflightDecision?> _checkPermissionWithProgress(',
      prepareStart,
    );
    final prepareBlock = source.substring(prepareStart, prepareEnd);
    expect(prepareBlock, contains('.load(repository, branch: targetBranch.name)'));
    expect(prepareBlock, contains('_detectBranchApkWorkflow('));
    expect(prepareBlock, contains('branch: targetBranch.name'));
  });

  test('branch é escolhida antes do pre-check de sincronização', () {
    final source = File(
      'lib/features/repositories/presentation/repository_detail_screen_actions.dart',
    ).readAsStringSync();

    final start = source.indexOf('Future<void> _sendBuild(');
    final end = source.indexOf(
      'Future<_UploadPreparation?> _prepareUpload(',
      start,
    );
    final block = source.substring(start, end);
    final chooseIndex = block.indexOf('await _chooseUploadBranch(repository)');
    final preparationIndex = block.indexOf('await _prepareUpload(');

    expect(chooseIndex, greaterThanOrEqualTo(0));
    expect(preparationIndex, greaterThan(chooseIndex));
  });

  test('lista vazia de branches é tratada como repositório vazio, não falha de API', () {
    final source = File(
      'lib/features/repositories/presentation/repository_branch_selector.dart',
    ).readAsStringSync();

    expect(
      source,
      contains(
        'if (branches.isEmpty && widget.emptyBranchName?.trim().isNotEmpty == true)',
      ),
    );
    expect(source, contains('Repositório vazio • será criada no primeiro envio'));
    expect(source, contains("sha: ''"));
    expect(source, contains('repositoryIsEmpty ='));
  });

  test('seletor abre imediatamente e carrega branches dentro do diálogo', () {
    final source = File(
      'lib/features/repositories/presentation/repository_branch_selector.dart',
    ).readAsStringSync();

    final dialogIndex = source.indexOf('return showDialog<RepositoryBranch>(');
    final listIndex = source.indexOf('.listBranches(repositoryFullName)');
    expect(dialogIndex, greaterThanOrEqualTo(0));
    expect(listIndex, greaterThan(dialogIndex));
    expect(source, contains("'Outras branches (\${others.length})'"));
    expect(source, contains("'Tentar novamente'"));
  });

  test('detalhe do repositório usa cache e timeout em vez de tela branca indefinida', () {
    final actions = File(
      'lib/features/repositories/presentation/repository_detail_screen_actions.dart',
    ).readAsStringSync();
    final screen = File(
      'lib/features/repositories/presentation/repository_detail_screen.dart',
    ).readAsStringSync();

    expect(actions, contains('.cachedRepository(widget.repositoryFullName)'));
    expect(actions, contains('.timeout(const Duration(seconds: 12))'));
    expect(screen, contains('_RepositoryLoadingView('));
    expect(screen, contains('_RepositoryErrorView('));
  });
}
