import 'package:flutter_test/flutter_test.dart';
import 'package:github_manager/features/repositories/domain/workflow_error_location.dart';

void main() {
  test('annotation oferece origem confirmada e linha', () {
    final item = WorkflowErrorLocation.fromAnnotation({
      'path': 'test/widget_test.dart', 'start_line': 42,
    });
    expect(item?.path, 'test/widget_test.dart');
    expect(item?.line, 42);
    expect(item?.confirmed, isTrue);
    expect(item?.githubUrl('owner/repo', 'abcdef0123456789'),
        'https://github.com/owner/repo/blob/abcdef0123456789/test/widget_test.dart#L42');
  });

  test('localiza linha Dart e Kotlin, mas não resumo genérico', () {
    final dart = WorkflowErrorLocation.fromLogLine('lib/src/main.dart:34:7: Error: missing getter');
    final kotlin = WorkflowErrorLocation.fromLogLine('e: app/src/main/MainActivity.kt: (57, 2): unresolved reference');
    final python = WorkflowErrorLocation.fromLogLine('File "tools/run.py", line 9, in main');
    expect(dart?.line, 34);
    expect(kotlin?.line, 57);
    expect(python?.line, 9);
    expect(dart?.confirmed, isFalse);
    expect(WorkflowErrorLocation.fromLogLine('##[error]177 tests passed, 3 failed.'), isNull);
  });

  test('não abre links fora do repositório', () {
    const absolute = WorkflowErrorLocation(path: '/tmp/some.dart', line: 3, source: 'Linha do log');
    const traversal = WorkflowErrorLocation(path: '../private.dart', line: 2, source: 'Linha do log');
    expect(absolute.githubUrl('owner/repo', 'abcdef1'), isNull);
    expect(traversal.githubUrl('owner/repo', 'abcdef1'), isNull);
    expect(traversal.githubUrl('owner/repo', 'not-a-sha'), isNull);
  });
}
