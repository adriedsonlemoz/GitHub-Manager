import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:github_manager/core/persistence/local_database.dart';

/// Preferência local para o modo de visualização do aplicativo inteiro.
///
/// Começa em modo imersivo para preservar a experiência das versões anteriores.
/// Android/Flutter podem ignorar o modo imersivo em SDKs recentes.
class SystemUiSettings extends ValueNotifier<bool> {
  SystemUiSettings._() : super(true);

  static final SystemUiSettings instance = SystemUiSettings._();

  static const preferenceKey = 'settings.fullscreen_enabled';

  /// O valor `false` desativa a tela inteira; sem registro, segue habilitada.
  static bool enabledFromStored(Object? stored) => stored != false;

  Future<void> initialize() async {
    final saved = await LocalDatabase.shared.readJson(preferenceKey);
    final enabled = enabledFromStored(saved);
    // Reaplica a preferência persistida depois do primeiro frame Flutter.
    await _apply(enabled);
    value = enabled;
  }

  /// Atualiza o Android e salva a escolha. Se a gravação falhar, restaura
  /// visualmente a escolha anterior em vez de exibir um estado falso na UI.
  Future<void> setEnabled(bool enabled) async {
    if (enabled == value) return;
    final previous = value;
    await _apply(enabled);
    try {
      await LocalDatabase.shared.putJson(preferenceKey, enabled);
      value = enabled;
    } catch (_) {
      try {
        await _apply(previous);
      } catch (_) {
        // Preserva a falha original de persistência para a interface.
      }
      rethrow;
    }
  }

  /// Reafirma o modo ao voltar do segundo plano, inclusive com FlutterEngine
  /// reutilizado depois de downloads e uploads em primeiro plano.
  Future<void> reapply() => _apply(value);

  static Future<void> _apply(bool enabled) =>
      SystemChrome.setEnabledSystemUIMode(
        enabled ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
      );
}
