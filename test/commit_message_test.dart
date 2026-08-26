import 'package:flutter_test/flutter_test.dart';
import 'package:github_manager/core/utils/commit_message.dart';

void main() {
  test('automatic commit message includes seconds and GitHub Manager identity', () {
    final message = automaticCommitMessage('Atualização');

    expect(
      message,
      matches(
        RegExp(
          r'^Atualização • GitHub Manager • \d{2}/\d{2}/\d{4} \d{2}:\d{2}:\d{2}$',
        ),
      ),
    );
  });
}
