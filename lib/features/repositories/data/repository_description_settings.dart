import 'package:github_manager/core/persistence/local_database.dart';

/// Preferência local para exibir descrições completas dos repositórios na Home.
class RepositoryDescriptionSettings {
  RepositoryDescriptionSettings._();

  static const key = 'settings.show_repository_descriptions';

  static Future<bool> isEnabled({LocalDatabase? database}) async {
    final stored = await (database ?? LocalDatabase.shared).readJson(key);
    return stored == true;
  }

  static Future<void> setEnabled(bool enabled, {LocalDatabase? database}) async {
    await (database ?? LocalDatabase.shared).putJson(key, enabled);
  }
}
