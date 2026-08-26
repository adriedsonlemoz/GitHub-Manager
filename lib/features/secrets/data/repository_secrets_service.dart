import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:github_manager/core/network/github_api_client.dart';
import 'package:github_manager/features/secrets/domain/repository_secret.dart';
import 'package:pinenacl/x25519.dart' show PublicKey, SealedBox;
import 'package:xml/xml.dart';

class RepositorySecretsService {
  RepositorySecretsService(this._client);

  final GitHubApiClient _client;

  Future<List<RepositorySecret>> listSecrets(String repositoryFullName) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/repos/$repositoryFullName/actions/secrets',
      queryParameters: {'per_page': 100},
    );
    final raw = response.data?['secrets'];
    if (raw is! List) {
      return const [];
    }
    final items = raw
        .whereType<Map>()
        .map((json) => RepositorySecret.fromJson(Map<String, dynamic>.from(json)))
        .toList(growable: false);
    items.sort((a, b) => a.name.compareTo(b.name));
    return items;
  }

  Future<void> putSecret({
    required String repositoryFullName,
    required String name,
    required String value,
  }) async {
    final key = await _getPublicKey(repositoryFullName);
    await _putEncrypted(
      repositoryFullName: repositoryFullName,
      name: _normalizeName(name),
      value: value,
      publicKey: key.$1,
      keyId: key.$2,
    );
  }

  Future<int> putMany({
    required String repositoryFullName,
    required Map<String, String> values,
  }) async {
    final key = await _getPublicKey(repositoryFullName);
    var count = 0;
    for (final entry in values.entries) {
      await _putEncrypted(
        repositoryFullName: repositoryFullName,
        name: _normalizeName(entry.key),
        value: entry.value,
        publicKey: key.$1,
        keyId: key.$2,
      );
      count++;
    }
    return count;
  }

  Future<void> deleteSecret({
    required String repositoryFullName,
    required String name,
  }) => _client.delete<void>(
        '/repos/$repositoryFullName/actions/secrets/${Uri.encodeComponent(name)}',
      );

  Future<PlatformFile?> pickImportFile() => FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['txt', 'env', 'json', 'xml'],
      );

  Future<Map<String, String>> parseImportFile(PlatformFile file) async {
    final bytes = await file.readAsBytes();
    final text = utf8.decode(bytes, allowMalformed: false);
    final lower = file.name.toLowerCase();
    if (lower.endsWith('.json')) {
      return parseJson(text);
    }
    if (lower.endsWith('.xml')) {
      return parseXml(text);
    }
    return parseText(text);
  }

  static Map<String, String> parseText(String text) {
    final values = <String, String>{};
    for (final rawLine in const LineSplitter().convert(text)) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#') || line.startsWith('//')) {
        continue;
      }
      final normalized = line.startsWith('export ') ? line.substring(7).trim() : line;
      final separator = normalized.indexOf('=');
      if (separator <= 0) {
        continue;
      }
      final name = _normalizeName(normalized.substring(0, separator));
      var value = normalized.substring(separator + 1).trim();
      if (value.length >= 2 &&
          ((value.startsWith('"') && value.endsWith('"')) ||
              (value.startsWith("'") && value.endsWith("'")))) {
        value = value.substring(1, value.length - 1);
      }
      values[name] = value;
    }
    return values;
  }

  static Map<String, String> parseJson(String text) {
    final decoded = jsonDecode(text);
    final values = <String, String>{};
    if (decoded is Map) {
      for (final entry in decoded.entries) {
        final value = entry.value;
        if (value is String || value is num || value is bool) {
          values[_normalizeName(entry.key.toString())] = value.toString();
        }
      }
    } else if (decoded is List) {
      for (final item in decoded.whereType<Map>()) {
        final name = item['name']?.toString();
        final value = item['value']?.toString();
        if (name != null && value != null) {
          values[_normalizeName(name)] = value;
        }
      }
    }
    return values;
  }

  static Map<String, String> parseXml(String text) {
    final document = XmlDocument.parse(text);
    final values = <String, String>{};
    for (final node in document.descendants.whereType<XmlElement>()) {
      if (node.name.local.toLowerCase() == 'secret') {
        final name = node.getAttribute('name') ?? node.getElement('name')?.innerText;
        final value = node.getAttribute('value') ?? node.getElement('value')?.innerText ?? node.innerText;
        if (name != null && name.trim().isNotEmpty) {
          values[_normalizeName(name)] = value;
        }
      }
    }
    if (values.isEmpty && document.rootElement.children.whereType<XmlElement>().isNotEmpty) {
      for (final element in document.rootElement.children.whereType<XmlElement>()) {
        if (element.children.whereType<XmlElement>().isEmpty) {
          values[_normalizeName(element.name.local)] = element.innerText;
        }
      }
    }
    return values;
  }

  Future<(Uint8List, String)> _getPublicKey(String repositoryFullName) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/repos/$repositoryFullName/actions/secrets/public-key',
    );
    final key = response.data?['key'] as String? ?? '';
    final keyId = response.data?['key_id'] as String? ?? '';
    if (key.isEmpty || keyId.isEmpty) {
      throw const FormatException('Chave pública de Secrets indisponível.');
    }
    return (base64.decode(key), keyId);
  }

  Future<void> _putEncrypted({
    required String repositoryFullName,
    required String name,
    required String value,
    required Uint8List publicKey,
    required String keyId,
  }) async {
    final sealed = SealedBox(PublicKey(publicKey));
    final encrypted = sealed.encrypt(Uint8List.fromList(utf8.encode(value)));
    await _client.put<void>(
      '/repos/$repositoryFullName/actions/secrets/${Uri.encodeComponent(name)}',
      data: {
        'encrypted_value': base64.encode(encrypted),
        'key_id': keyId,
      },
    );
  }

  static String _normalizeName(String raw) {
    final name = raw.trim().toUpperCase();
    if (!RegExp(r'^[A-Z_][A-Z0-9_]*$').hasMatch(name) || name.startsWith('GITHUB_')) {
      throw FormatException('Nome de Secret inválido: $raw');
    }
    return name;
  }
}
