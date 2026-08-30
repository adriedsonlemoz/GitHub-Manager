import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

class GitObjectHash {
  const GitObjectHash._();

  static String blobSha(List<int> bytes) {
    final sink = _DigestSink();
    final converter = sha1.startChunkedConversion(sink);
    converter.add(utf8.encode('blob ${bytes.length}\u0000'));
    converter.add(bytes);
    converter.close();
    return sink.value.toString();
  }

  static Future<String> blobShaFile(File file) async {
    final length = await file.length();
    final sink = _DigestSink();
    final converter = sha1.startChunkedConversion(sink);
    converter.add(utf8.encode('blob $length\u0000'));
    await for (final chunk in file.openRead()) {
      converter.add(chunk);
    }
    converter.close();
    return sink.value.toString();
  }
}

class _DigestSink implements Sink<Digest> {
  Digest? _value;

  Digest get value => _value!;

  @override
  void add(Digest data) {
    _value = data;
  }

  @override
  void close() {}
}
