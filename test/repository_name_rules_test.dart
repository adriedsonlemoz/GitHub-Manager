import 'package:flutter_test/flutter_test.dart';
import 'package:github_manager/features/repositories/domain/repository_name_rules.dart';

void main() {
  group('RepositoryNameRules', () {
    test('aceita nomes válidos do GitHub', () {
      for (final value in ['meu-app', 'app_v2', 'app.android', 'Repo123']) {
        expect(RepositoryNameRules.validate(value), isNull, reason: value);
      }
    });

    test('rejeita espaços, barras e caracteres inválidos', () {
      expect(RepositoryNameRules.validate('meu repo'), isNotNull);
      expect(RepositoryNameRules.validate('owner/repo'), isNotNull);
      expect(RepositoryNameRules.validate('repo@novo'), isNotNull);
    });

    test('limita a 100 caracteres', () {
      expect(RepositoryNameRules.validate(List.filled(100, 'a').join()), isNull);
      expect(RepositoryNameRules.validate(List.filled(101, 'a').join()), isNotNull);
    });

    test('detecta alteração depois de normalizar espaços externos', () {
      expect(RepositoryNameRules.isChanged('repo', ' repo '), isFalse);
      expect(RepositoryNameRules.isChanged('repo', 'Repo'), isTrue);
    });
  });
}
