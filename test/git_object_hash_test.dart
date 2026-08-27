import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:github_manager/core/utils/git_object_hash.dart';

void main() {
  test('calcula o SHA-1 de blob exatamente como o Git', () {
    final sha = GitObjectHash.blobSha(utf8.encode('hello\n'));

    expect(sha, 'ce013625030ba8dba906f756967f9e9ca394464a');
  });
}
