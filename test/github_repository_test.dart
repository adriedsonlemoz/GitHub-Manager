import 'package:flutter_test/flutter_test.dart';
import 'package:github_manager/features/repositories/domain/github_repository.dart';

void main() {
  test('GitHubRepository parses core REST fields', () {
    final repository = GitHubRepository.fromJson({
      'id': 42,
      'name': 'github-manager',
      'full_name': 'owner/github-manager',
      'private': true,
      'archived': false,
      'default_branch': 'main',
      'language': 'Dart',
      'updated_at': '2026-08-26T08:00:00Z',
      'html_url': 'https://github.com/owner/github-manager',
    });

    expect(repository.id, 42);
    expect(repository.isPrivate, isTrue);
    expect(repository.defaultBranch, 'main');
    expect(repository.language, 'Dart');
  });
}
