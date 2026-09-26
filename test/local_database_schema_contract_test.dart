import 'package:flutter_test/flutter_test.dart';
import 'package:github_manager/core/persistence/local_database.dart';

void main() {
  test('schema local mantém a migração de favoritos', () {
    expect(LocalDatabase.schemaVersion, greaterThanOrEqualTo(3));
    expect(LocalDatabase.databaseFileName, 'github_manager.db');
  });

  test('há um único proprietário de banco por isolate', () {
    expect(identical(LocalDatabase.shared, LocalDatabase.shared), isTrue);
  });
}
