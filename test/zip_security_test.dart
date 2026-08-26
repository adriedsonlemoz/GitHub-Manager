import 'package:flutter_test/flutter_test.dart';
import 'package:github_manager/core/errors/app_exception.dart';
import 'package:github_manager/features/projects/data/local_project_service.dart';

void main() {
  group('ZIP path security', () {
    test('normalizes safe relative paths', () {
      expect(
        LocalProjectService.validateArchivePath('project\\lib/main.dart'),
        'project/lib/main.dart',
      );
    });

    test('blocks path traversal', () {
      expect(
        () => LocalProjectService.validateArchivePath('../secret.txt'),
        throwsA(isA<InvalidZipException>()),
      );
    });

    test('blocks absolute paths', () {
      expect(
        () => LocalProjectService.validateArchivePath('/etc/passwd'),
        throwsA(isA<InvalidZipException>()),
      );
    });
  });
}
