import 'dart:io';

import 'package:archive/archive.dart';

/// Inspeção local do APK *já baixado*, diferente da estimativa por nome.
/// Não faz parsing binário do Manifest, verificação de assinatura ou SDK mínimo.
class ApkPackageInspection {
  const ApkPackageInspection({required this.nativeAbis});
  final List<String> nativeAbis;

  static Future<ApkPackageInspection> inspect(File file) async {
    final input = InputFileStream(file.path);
    try {
      final archive = ZipDecoder().decodeStream(input, verify: false);
      try {
        final names = archive
            .where((entry) => entry.isFile)
            .map((entry) => entry.name.replaceAll('\\', '/'))
            .toSet();
        final hasManifest = names.contains('AndroidManifest.xml');
        final hasContent = names.contains('classes.dex') ||
            names.contains('resources.arsc') ||
            names.any((name) => name.startsWith('lib/') && name.endsWith('.so'));
        if (!hasManifest || !hasContent) {
          throw const FormatException(
            'O arquivo não tem a estrutura mínima de um APK Android. '
            'Pode ser um ZIP externo ou download incompleto.',
          );
        }
        final abis = <String>{};
        for (final name in names) {
          final match = RegExp(r'^lib/([^/]+)/[^/]+\.so$').firstMatch(name);
          if (match != null) abis.add(match.group(1)!);
        }
        return ApkPackageInspection(nativeAbis: (abis.toList()..sort()));
      } finally {
        archive.clearSync();
      }
    } on FormatException {
      rethrow;
    } on Exception catch (_) {
      throw const FormatException('Não foi possível ler a estrutura do APK baixado.');
    } finally {
      input.closeSync();
    }
  }
}
