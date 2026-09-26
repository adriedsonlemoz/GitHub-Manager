enum ApkArchitecture { arm64, armv7, x86_64, x86, universal, unknown }

class ApkVariantInfo {
  const ApkVariantInfo({
    required this.architecture,
    required this.label,
    required this.shortLabel,
    required this.description,
    this.abi,
  });

  final ApkArchitecture architecture;
  final String label;
  final String shortLabel;
  final String description;
  final String? abi;

  bool get isUniversal => architecture == ApkArchitecture.universal;
  bool get isSpecific => abi != null;

  factory ApkVariantInfo.fromName(String rawName) {
    final lower = rawName.toLowerCase();
    if (lower.contains('universal') ||
        lower.contains('fat-apk') ||
        lower.contains('-all.')) {
      return const ApkVariantInfo(
        architecture: ApkArchitecture.universal,
        label: 'Universal',
        shortLabel: 'Universal',
        description: 'Funciona em várias arquiteturas e costuma ocupar mais espaço.',
      );
    }
    if (lower.contains('arm64-v8a') ||
        lower.contains('arm64') ||
        lower.contains('aarch64')) {
      return const ApkVariantInfo(
        architecture: ApkArchitecture.arm64,
        label: 'ARM64 (arm64-v8a)',
        shortLabel: 'ARM64',
        description: 'Android ARM de 64 bits, comum em celulares atuais.',
        abi: 'arm64-v8a',
      );
    }
    if (lower.contains('armeabi-v7a') ||
        lower.contains('armv7') ||
        lower.contains('v7a') ||
        lower.contains('arm32')) {
      return const ApkVariantInfo(
        architecture: ApkArchitecture.armv7,
        label: 'ARM 32 bits (armeabi-v7a)',
        shortLabel: 'ARMv7',
        description: 'Android ARM de 32 bits, usado principalmente em aparelhos antigos.',
        abi: 'armeabi-v7a',
      );
    }
    if (lower.contains('x86_64')) {
      return const ApkVariantInfo(
        architecture: ApkArchitecture.x86_64,
        label: 'x86_64',
        shortLabel: 'x86_64',
        description: 'Arquitetura x86 de 64 bits, mais comum em emuladores e poucos dispositivos.',
        abi: 'x86_64',
      );
    }
    if (RegExp(r'(^|[-_.])x86($|[-_.])').hasMatch(lower)) {
      return const ApkVariantInfo(
        architecture: ApkArchitecture.x86,
        label: 'x86',
        shortLabel: 'x86',
        description: 'Arquitetura x86 de 32 bits, normalmente usada em ambientes específicos.',
        abi: 'x86',
      );
    }
    return const ApkVariantInfo(
      architecture: ApkArchitecture.unknown,
      label: 'Arquitetura não informada',
      shortLabel: 'APK',
      description: 'O nome do arquivo não informa a arquitetura do APK.',
    );
  }

  bool isCompatibleWith(Iterable<String> supportedAbis) {
    if (isUniversal || architecture == ApkArchitecture.unknown) return true;
    final normalized = supportedAbis.map((value) => value.trim().toLowerCase());
    return normalized.contains(abi!.toLowerCase());
  }
}

int apkRecommendationRank(String name, List<String> supportedAbis) {
  final info = ApkVariantInfo.fromName(name);
  final normalized = supportedAbis
      .map((value) => value.trim().toLowerCase())
      .where((value) => value.isNotEmpty)
      .toList(growable: false);
  if (info.isSpecific) {
    final index = normalized.indexOf(info.abi!.toLowerCase());
    if (index >= 0) return index;
    return 100;
  }
  if (info.isUniversal) return normalized.isEmpty ? 0 : 50;
  return 60;
}

bool apkNameIsCompatible(String name, List<String> supportedAbis) =>
    ApkVariantInfo.fromName(name).isCompatibleWith(supportedAbis);
