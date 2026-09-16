import 'package:github_manager/core/persistence/local_database.dart';

class UploadRecoverySettings {
  UploadRecoverySettings._();

  static const _automaticRecoveryKey = 'settings.upload_automatic_recovery';

  static Future<bool> isAutomaticRecoveryEnabled({
    LocalDatabase? database,
  }) async {
    final db = database ?? LocalDatabase.shared;
    final stored = await db.readJson(_automaticRecoveryKey);
    return stored != false;
  }

  static Future<void> setAutomaticRecoveryEnabled(
    bool enabled, {
    LocalDatabase? database,
  }) async {
    final db = database ?? LocalDatabase.shared;
    await db.putJson(_automaticRecoveryKey, enabled);
  }
}
