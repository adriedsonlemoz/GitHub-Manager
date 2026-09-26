import 'package:flutter_test/flutter_test.dart';
import 'package:github_manager/features/builds/domain/apk_variant.dart';

void main() {
  test('detecta arquiteturas Android pelo nome do APK', () {
    expect(
      ApkVariantInfo.fromName('app-arm64-v8a.apk').architecture,
      ApkArchitecture.arm64,
    );
    expect(
      ApkVariantInfo.fromName('app-armeabi-v7a.apk').architecture,
      ApkArchitecture.armv7,
    );
    expect(
      ApkVariantInfo.fromName('app-x86_64.apk').architecture,
      ApkArchitecture.x86_64,
    );
    expect(
      ApkVariantInfo.fromName('app-universal.apk').architecture,
      ApkArchitecture.universal,
    );
  });

  test('APK específico da ABI principal vence Universal', () {
    const supported = ['arm64-v8a', 'armeabi-v7a'];
    expect(apkRecommendationRank('app-arm64-v8a.apk', supported), 0);
    expect(
      apkRecommendationRank('app-universal.apk', supported),
      greaterThan(apkRecommendationRank('app-arm64-v8a.apk', supported)),
    );
  });

  test('ABI secundária continua compatível e x86 é incompatível em ARM', () {
    const supported = ['arm64-v8a', 'armeabi-v7a'];
    expect(apkNameIsCompatible('app-armeabi-v7a.apk', supported), isTrue);
    expect(apkNameIsCompatible('app-x86_64.apk', supported), isFalse);
    expect(apkNameIsCompatible('app-universal.apk', supported), isTrue);
  });
}
