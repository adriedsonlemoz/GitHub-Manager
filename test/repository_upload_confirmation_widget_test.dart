import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:github_manager/features/repositories/presentation/repository_detail_screen.dart';
import 'package:github_manager/features/uploads/domain/managed_upload.dart';

void main() {
  testWidgets('confirmação de envio retorna ManagedUploadBuildPolicy', (
    tester,
  ) async {
    ManagedUploadBuildPolicy? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                result = await showDialog<ManagedUploadBuildPolicy>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Conferir envio'),
                    actions: [
                      FilledButton(
                        key: const Key('confirm-upload-policy'),
                        onPressed: () => completeUploadPolicyDialog(
                          dialogContext,
                          ManagedUploadBuildPolicy.automatic,
                        ),
                        child: const Text('Enviar versão'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-upload-policy')));
    await tester.pumpAndSettle();

    expect(result, ManagedUploadBuildPolicy.automatic);
  });

  test('confirmação de envio real não devolve bool ao Navigator', () {
    final source = File(
      'lib/features/repositories/presentation/repository_detail_screen_actions.dart',
    ).readAsStringSync();
    final start = source.indexOf(
      'Future<ManagedUploadBuildPolicy?> _confirmZip',
    );
    final end = source.indexOf(
      'Future<void> _showBuildSafetyHelp',
      start,
    );

    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final confirmationSource = source.substring(start, end);
    expect(
      confirmationSource,
      isNot(contains('Navigator.pop(dialogContext, true)')),
    );
    expect(
      RegExp(r'completeUploadPolicyDialog\(dialogContext, buildPolicy\)')
          .allMatches(confirmationSource)
          .length,
      2,
    );
  });
}
