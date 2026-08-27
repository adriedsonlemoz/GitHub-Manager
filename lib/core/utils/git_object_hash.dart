import 'dart:convert';

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
