import 'package:github_manager/core/persistence/local_database.dart';

/// A limpeza nunca alcança fontes, Secrets, arquivos parciais ou pastas fora
/// de Downloads/GitHub/<projeto>. O padrão preserva o arquivo anterior até
/// que o novo seja publicado com sucesso.
enum DownloadCleanupMode { afterSuccess, beforeStart, disabled }

class DownloadCleanupSettings {
  DownloadCleanupSettings._();

  static const key = 'settings.download_cleanup_mode';

  static Future<DownloadCleanupMode> read({LocalDatabase? database}) async {
    final value = await (database ?? LocalDatabase.shared).readJson(key);
    return DownloadCleanupMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => DownloadCleanupMode.afterSuccess,
    );
  }

  static Future<void> write(
    DownloadCleanupMode mode, {
    LocalDatabase? database,
  }) => (database ?? LocalDatabase.shared).putJson(key, mode.name);

  static String label(DownloadCleanupMode mode) => switch (mode) {
        DownloadCleanupMode.afterSuccess => 'Após concluir o download',
        DownloadCleanupMode.beforeStart => 'Antes de iniciar o download',
        DownloadCleanupMode.disabled => 'Desativada',
      };

  static String description(DownloadCleanupMode mode) => switch (mode) {
        DownloadCleanupMode.afterSuccess =>
          'Mantém o anterior até o novo arquivo ser salvo e validado.',
        DownloadCleanupMode.beforeStart =>
          'Remove arquivos anteriores antes de transferir. Uma falha pode deixar a pasta vazia.',
        DownloadCleanupMode.disabled =>
          'Conserva todos os arquivos; a limpeza será manual.',
      };
}
