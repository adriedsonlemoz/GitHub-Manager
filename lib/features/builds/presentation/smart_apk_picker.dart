import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:github_manager/core/platform/platform_actions.dart';
import 'package:github_manager/features/builds/domain/apk_variant.dart';
import 'package:github_manager/features/builds/domain/build_manifest.dart';

/// Adaptador visual: o serviço responsável pelo download continua sendo o
/// chamador. Nenhuma seleção baixa ou instala um arquivo silenciosamente.
class SmartApkOption<T> {
  const SmartApkOption({
    required this.value,
    required this.name,
    required this.bytes,
    required this.source,
    this.exactRun = false,
    this.declaredAbi,
  });

  final T value;
  final String name;
  final int bytes;
  final String source;
  /// Artifacts são vinculados ao ID da execução; Releases não necessariamente.
  final bool exactRun;
  /// Arquitetura declarada no manifest do workflow, não no nome.
  final String? declaredAbi;
}

/// Uma recomendação só é exibida quando a arquitetura foi reconhecida pelo
/// nome E o Android informou as ABIs. Não é uma inspeção do APK.
int? smartApkRecommendedIndex<T>(
  List<SmartApkOption<T>> options,
  List<String> supportedAbis,
) {
  if (supportedAbis.isEmpty) return null;
  var best = 100;
  int? index;
  for (var i = 0; i < options.length; i++) {
    final variant = ApkVariantInfo.fromName(options[i].name);
    final abi = options[i].declaredAbi?.toLowerCase().trim();
    final normalizedSupported = supportedAbis.map((value) => value.toLowerCase()).toList();
    final rank = abi == 'universal'
        ? 50
        : abi != null
            ? normalizedSupported.indexOf(abi) >= 0
                ? normalizedSupported.indexOf(abi)
                : 100
            : apkRecommendationRank(options[i].name, supportedAbis);
    if (variant.architecture == ApkArchitecture.unknown &&
        abi != 'universal' && (abi == null || !normalizedSupported.contains(abi))) {
      continue;
    }
    if (rank < best || (rank == best && index != null &&
        options[i].exactRun && !options[index].exactRun)) {
      best = rank;
      index = i;
    }
  }
  return index;
}

Future<T?> showSmartApkPicker<T>({
  required BuildContext context,
  required List<SmartApkOption<T>> options,
  required String project,
  required int runNumber,
  String? version,
  AndroidDeviceInfo? deviceInfo,
  BuildManifest? manifest,
}) {
  return showModalBottomSheet<T>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => _SmartApkPicker<T>(
      options: options,
      project: project,
      runNumber: runNumber,
      version: version,
      deviceInfo: deviceInfo,
      manifest: manifest,
    ),
  );
}

class _SmartApkPicker<T> extends StatelessWidget {
  const _SmartApkPicker({
    required this.options,
    required this.project,
    required this.runNumber,
    required this.version,
    required this.deviceInfo,
    required this.manifest,
  });

  final List<SmartApkOption<T>> options;
  final String project;
  final int runNumber;
  final String? version;
  final AndroidDeviceInfo? deviceInfo;
  final BuildManifest? manifest;

  static String sizeLabel(int bytes) {
    if (bytes <= 0) return 'Tamanho não informado';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final supported = deviceInfo?.supportedAbis ?? const <String>[];
    final bestIndex = smartApkRecommendedIndex(options, supported);
    final preferred = bestIndex == null ? null : options[bestIndex];
    final others = [
      for (var i = 0; i < options.length; i++)
        if (i != bestIndex) options[i],
    ];
    return FractionallySizedBox(
      heightFactor: .82,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Escolher APK', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(project, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 3),
            Text('${manifest != null ? 'Versão ${manifest!.versionName}+${manifest!.versionCode} (workflow)' : version == null || version!.isEmpty ? 'Versão não identificada' : 'Versão $version (estimada)'} ${runNumber > 0 ? '  •  execução GitHub #$runNumber' : ''}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            if (manifest != null) ...[
              const SizedBox(height: 4),
              Text('Pacote: ${manifest!.applicationId} • metadados da execução verificados pelo ID e commit',
                style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: [
                  Card.filled(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(13),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Icon(Icons.phone_android_rounded, color: scheme.primary),
                            const SizedBox(width: 8),
                            Expanded(child: Text(deviceInfo == null
                                ? 'Arquitetura do aparelho indisponível'
                                : 'Seu aparelho: ${deviceInfo!.primaryAbi}',
                              style: const TextStyle(fontWeight: FontWeight.w700))),
                          ]),
                          const SizedBox(height: 5),
                          Text('Arquitetura: estimativa pelo nome do arquivo${manifest == null ? '' : ', com metadados do workflow disponíveis'}. Instalação somente após validação pelo Android.',
                            style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ),
                  if (preferred != null) ...[
                    const SizedBox(height: 15),
                    Row(children: [
                      Icon(Icons.check_circle_outline, color: scheme.primary, size: 20),
                      const SizedBox(width: 7),
                      const Expanded(child: Text('Sugestão para este aparelho (estimada)', style: TextStyle(fontWeight: FontWeight.w800))),
                    ]),
                    const SizedBox(height: 8),
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(preferred.declaredAbi != null &&
                                ApkVariantInfo.fromName(preferred.name).architecture == ApkArchitecture.unknown
                                ? 'ABI declarada: ${preferred.declaredAbi}'
                                : ApkVariantInfo.fromName(preferred.name).label,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 3),
                            Text('${sizeLabel(preferred.bytes)}  •  ${preferred.source}',
                              style: Theme.of(context).textTheme.bodySmall),
                            if (!preferred.exactRun)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text('Release: vínculo com esta execução não confirmado.',
                                  style: TextStyle(color: scheme.onSurfaceVariant)),
                              ),
                            const SizedBox(height: 11),
                            SizedBox(width: double.infinity, child: FilledButton.icon(
                              onPressed: () => Navigator.pop(context, preferred.value),
                              icon: const Icon(Icons.download_rounded),
                              label: const Text('Baixar opção sugerida'),
                            )),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(preferred == null ? 'APKs disponíveis' : 'Outras opções',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  if (others.isEmpty)
                    const Text('Nenhuma outra opção disponível.')
                  else
                    ...others.map((option) {
                      final variant = ApkVariantInfo.fromName(option.name);
                      final supportedKnown = supported.isNotEmpty;
                      final incompatible = supportedKnown && variant.isSpecific &&
                          !variant.isCompatibleWith(supported);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 7),
                        child: ListTile(
                          dense: true,
                          leading: Icon(incompatible ? Icons.warning_amber_rounded : Icons.android_rounded,
                            color: incompatible ? scheme.error : scheme.primary),
                          title: Text(variant.shortLabel, style: const TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: Text('${sizeLabel(option.bytes)} • ${option.source}${incompatible ? '\nABI não suportada pelo aparelho' : ''}',
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => Navigator.pop(context, option.value),
                        ),
                      );
                    }),
                  const SizedBox(height: 4),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('Detalhes técnicos'),
                    children: [
                      for (final option in options)
                        ListTile(
                          title: Text(option.name, style: Theme.of(context).textTheme.bodySmall),
                          subtitle: Text('${option.source} • ${sizeLabel(option.bytes)} • ${option.exactRun ? 'artifact desta execução' : 'vínculo da Release por commit/tag'}${option.declaredAbi == null ? '' : ' • ABI declarada: ${option.declaredAbi}'}${manifest?.apks.any((apk) => apk.fileName == option.name) == true ? ' • SHA-256 declarado no workflow (não verificado no download)' : ''}'),
                          trailing: IconButton(
                            tooltip: 'Copiar nome original',
                            icon: const Icon(Icons.copy_rounded),
                            onPressed: () => Clipboard.setData(ClipboardData(text: option.name)),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Align(alignment: Alignment.centerRight, child: TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('Cancelar'),
            )),
          ],
        ),
      ),
    );
  }
}
