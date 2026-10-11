import 'package:xml/xml.dart';

/// Lê apenas o rótulo de exibição de projetos Android cujo Manifest é XML fonte.
/// Um @string sem arquivo de recursos resolvido não é tratado como nome real.
class AndroidProjectNameResolver {
  const AndroidProjectNameResolver._();

  static String? fromManifest(String manifest, {String? stringsXml}) {
    try {
      final doc = XmlDocument.parse(manifest);
      for (final application in doc.findAllElements('application')) {
        final label = application.attributes
            .where((attribute) => attribute.name.local == 'label')
            .map((attribute) => attribute.value.trim())
            .firstOrNull;
        if (label == null || label.isEmpty) continue;
        if (!label.startsWith('@')) return _usable(label);
        if (!label.startsWith('@string/') || stringsXml == null) return null;
        final key = label.substring('@string/'.length);
        final resources = XmlDocument.parse(stringsXml);
        for (final item in resources.findAllElements('string')) {
          if (item.getAttribute('name') == key) {
            return _usable(item.innerText.trim());
          }
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  static String? _usable(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty || normalized.startsWith('@') ||
        normalized.startsWith(r'${') || normalized.startsWith(r'$')) {
      return null;
    }
    return normalized;
  }
}
