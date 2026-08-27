import 'package:flutter_test/flutter_test.dart';
import 'package:github_manager/features/repositories/domain/workflow_definition_inspector.dart';

void main() {
  group('WorkflowDefinitionInspector', () {
    test('detects generic Release workflow by structure', () {
      const yaml = '''
name: Release
on:
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: flutter build apk --release
      - uses: actions/upload-artifact@v4
        with:
          path: build/app/outputs/flutter-apk/app-release.apk
''';

      final info = WorkflowDefinitionInspector.inspect(yaml);
      expect(info.declaredName, 'Release');
      expect(info.supportsDispatch, isTrue);
      expect(info.likelyBuildsApk, isTrue);
    });

    test('recognizes inline workflow_dispatch', () {
      const yaml = '''
name: Mobile
on: [push, workflow_dispatch]
jobs:
  android:
    steps:
      - run: ./gradlew assembleRelease
''';
      final info = WorkflowDefinitionInspector.inspect(yaml);
      expect(info.supportsDispatch, isTrue);
      expect(info.likelyBuildsApk, isTrue);
    });

    test('does not trust APK words outside jobs', () {
      const yaml = '''
name: Android APK docs
on:
  workflow_dispatch:
jobs:
  docs:
    steps:
      - run: echo "generate documentation"
''';
      final info = WorkflowDefinitionInspector.inspect(yaml);
      expect(info.supportsDispatch, isTrue);
      expect(info.likelyBuildsApk, isFalse);
    });

    test('workflow without dispatch is not manually runnable', () {
      const yaml = '''
name: Release
on:
  push:
    branches: [main]
jobs:
  build:
    steps:
      - run: flutter build apk --release
''';
      final info = WorkflowDefinitionInspector.inspect(yaml);
      expect(info.supportsDispatch, isFalse);
      expect(info.likelyBuildsApk, isTrue);
    });
  });
}
