import 'package:github_manager/core/persistence/local_database.dart';

class UploadRecoverySettings {
  UploadRecoverySettings._();

  static const _automaticRecoveryKey = 'settings.upload_automatic_recovery';

  static Future<bool> isAutomaticRecoveryEnabled({LocalDatabase? database}) async {
    final db = database ?? LocalDatabase();
    final ownsDatabase = database == null;
    try {
      return await db.readJson(_automaticRecoveryKey) != false;
    } finally {
      if (ownsDatabase) await db.close();
    }
  }

  static Future<void> setAutomaticRecoveryEnabled(
    bool enabled, {
    LocalDatabase? database,
  }) async {
    final db = database ?? LocalDatabase();
    final ownsDatabase = database == null;
    try {
      await db.putJson(_automaticRecoveryKey, enabled);
    } finally {
      if (ownsDatabase) await db.close();
    }
  }
}
