import 'package:flutter_test/flutter_test.dart';
import 'package:github_manager/core/persistence/local_database.dart';

void main() {
  test('schema local mantém a migração de favoritos', () {
    expect(LocalDatabase.schemaVersion, greaterThanOrEqualTo(2));
    expect(LocalDatabase.databaseFileName, 'github_manager.db');
  });
}
