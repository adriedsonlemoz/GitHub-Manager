import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('confirmZip returns ManagedUploadBuildPolicy instead of bool', () {
    final source = File(
      'lib/features/repositories/presentation/repository_detail_screen_actions.dart',
    ).readAsStringSync();

    final start = source.indexOf(
      'Future<ManagedUploadBuildPolicy?> _confirmZip(',
    );
    final end = source.indexOf(
      'Future<void> _showBuildSafetyHelp(',
      start,
    );

    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));

    final block = source.substring(start, end);
    expect(block, contains('showDialog<ManagedUploadBuildPolicy>'));
    expect(block, contains('Navigator.pop(dialogContext, buildPolicy)'));
    expect(block, isNot(contains('Navigator.pop(dialogContext, true)')));
  });
}
