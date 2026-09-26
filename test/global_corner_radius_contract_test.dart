import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('retângulos explícitos usam raio 4; pills deliberadas ficam preservadas', () {
    final dartFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    final borderRadius = RegExp(r'BorderRadius\.circular\((\d+)\)');
    final radius = RegExp(r'Radius\.circular\((\d+)\)');

    final violations = <String>[];
    for (final file in dartFiles) {
      final content = file.readAsStringSync();
      for (final match in borderRadius.allMatches(content)) {
        final value = int.parse(match.group(1)!);
        if (value != 4 && value != 99 && value != 999) {
          violations.add('${file.path}: BorderRadius $value');
        }
      }
      for (final match in radius.allMatches(content)) {
        final value = int.parse(match.group(1)!);
        if (value != 4 && value != 99 && value != 999) {
          violations.add('${file.path}: Radius $value');
        }
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}
