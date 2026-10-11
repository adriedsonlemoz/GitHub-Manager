import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('configuração local inicia desativada e é persistente', () {
    final settings = File(
      'lib/features/repositories/data/repository_description_settings.dart',
    ).readAsStringSync();

    expect(settings, contains("'settings.show_repository_descriptions'"));
    expect(settings, contains('return stored == true;'));
    expect(settings, contains('.putJson(key, enabled)'));
  });

  test('descrição completa depende da preferência e não é truncada', () {
    final card = File(
      'lib/features/repositories/presentation/repository_card.dart',
    ).readAsStringSync();
    final beginning = card.indexOf(
      'if (showDescription && description.isNotEmpty)',
    );
    expect(beginning, greaterThanOrEqualTo(0));
    final end = card.indexOf('softWrap: true,', beginning);
    expect(end, greaterThan(beginning));
    final descriptionBlock = card.substring(beginning, end);

    expect(descriptionBlock, contains('Text('));
    expect(descriptionBlock, contains('description,'));
    expect(descriptionBlock, isNot(contains('maxLines:')));
    expect(descriptionBlock, isNot(contains('TextOverflow.ellipsis')));
  });

  test('configuração reativa integra Home e Configurações com Riverpod 3', () {
    final provider = File(
      'lib/features/repositories/presentation/repository_providers.dart',
    ).readAsStringSync();
    final card = File(
      'lib/features/repositories/presentation/repository_card.dart',
    ).readAsStringSync();
    final settings = File(
      'lib/features/settings/presentation/settings_screen.dart',
    ).readAsStringSync();
    final actions = File(
      'lib/features/settings/presentation/settings_screen_actions.dart',
    ).readAsStringSync();

    expect(
      provider,
      contains('showRepositoryDescriptionsProvider = FutureProvider<bool>'),
    );
    expect(
      card,
      contains('showRepositoryDescriptionsProvider).asData?.value'),
    );
    expect(settings, contains('descriptionPreference.asData?.value'));
    expect(
      actions,
      contains('ref.invalidate(showRepositoryDescriptionsProvider)'),
    );
    expect(settings, isNot(contains('valueOrNull')));
    expect(card, isNot(contains('valueOrNull')));
  });

  test('versão da release acompanha a versão canônica do pubspec', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final manifest = File('github-manager.json').readAsStringSync();
    final changeLog = File('CHANGELOG.md').readAsStringSync();
    final current = RegExp(r'^version: ([^\n]+)$', multiLine: true)
        .firstMatch(pubspec)!
        .group(1)!;
    final name = current.split('+').first;
    final code = current.split('+').last;

    expect(manifest, contains('"versionName": "$name"'));
    expect(manifest, contains('"versionCode": $code'));
    expect(changeLog, startsWith('## $current'));
  });
}
