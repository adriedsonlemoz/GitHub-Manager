import 'package:flutter_test/flutter_test.dart';
import 'package:github_manager/features/builds/domain/build_diagnostic_advice.dart';

void main() {
  test('referência Kotlin recebe orientação sem inventar import', () {
    final diagnosis = BuildDiagnosticAdvice.fromMessage(
      "ExplorerQuickAccess.kt:206:70 Unresolved reference 'ensureActive'",
    );
    expect(diagnosis.title, contains('referência'));
    expect(diagnosis.action, contains('imports'));
  });

  test('resumo numérico não produz correção inventada', () {
    final diagnosis = BuildDiagnosticAdvice.fromMessage(
      '177 tests passed, 3 failed',
    );
    expect(diagnosis.action, contains('resumo'));
  });
}
