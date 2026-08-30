import 'package:flutter_test/flutter_test.dart';
import 'package:github_manager/core/security/github_token_normalizer.dart';

void main() {
  group('normalizeGitHubToken', () {
    test('keeps a normal PAT unchanged', () {
      expect(normalizeGitHubToken('github_pat_ABC123_xyz'), 'github_pat_ABC123_xyz');
    });

    test('removes surrounding whitespace and line breaks', () {
      expect(normalizeGitHubToken('  ghp_ABC\n123  '), 'ghp_ABC123');
    });

    test('accepts Bearer and Authorization header paste', () {
      expect(normalizeGitHubToken('Bearer ghp_ABC123'), 'ghp_ABC123');
      expect(
        normalizeGitHubToken('Authorization: Bearer github_pat_ABC123'),
        'github_pat_ABC123',
      );
    });

    test('removes quotes, backticks and zero width chars', () {
      expect(normalizeGitHubToken('`ghp_ABC123`'), 'ghp_ABC123');
      expect(normalizeGitHubToken('"ghp_ABC123"'), 'ghp_ABC123');
      expect(normalizeGitHubToken('ghp_ABC\u200B123'), 'ghp_ABC123');
    });
  });
}
