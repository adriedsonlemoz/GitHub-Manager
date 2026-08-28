part of 'repository_artifacts_screen.dart';

class _ArtifactCard extends StatelessWidget {
  const _ArtifactCard({
    required this.artifact,
    required this.readOnly,
    required this.selectionMode,
    required this.selected,
    required this.onToggleSelection,
    required this.onDownload,
    required this.onPublish,
    required this.onDelete,
  });

  final ActionArtifact artifact;
  final bool readOnly;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onToggleSelection;
  final VoidCallback? onDownload;
  final VoidCallback? onPublish;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final descriptor = _ArtifactDescriptor.fromArtifact(artifact);
    final metadata = <String>[
      _RepositoryArtifactsScreenState._formatBytes(artifact.sizeBytes),
      _RepositoryArtifactsScreenState._formatDate(artifact.createdAt),
      if (artifact.workflowRunId != null) 'Run #${artifact.workflowRunId}',
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onLongPress: readOnly ? null : onToggleSelection,
        onTap: selectionMode && !readOnly ? onToggleSelection : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (selectionMode && !readOnly)
                    SizedBox(
                      width: 42,
                      height: 42,
                      child: Checkbox(
                        value: selected,
                        onChanged: (_) => onToggleSelection(),
                      ),
                    )
                  else
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer.withValues(alpha: .72),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        descriptor.icon,
                        color: scheme.onPrimaryContainer,
                        size: 22,
                      ),
                    ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          artifact.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          metadata.join(' • '),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  if (artifact.expired)
                    const _ArtifactBadge(
                      label: 'Expirado',
                      icon: Icons.history_toggle_off_rounded,
                      danger: true,
                    ),
                ],
              ),
              const SizedBox(height: 11),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _ArtifactBadge(label: descriptor.format, icon: descriptor.formatIcon),
                  _ArtifactBadge(label: descriptor.buildType, icon: Icons.build_circle_outlined),
                  _ArtifactBadge(
                    label: descriptor.stability,
                    icon: descriptor.stabilityIcon,
                    emphasized: descriptor.isStable,
                  ),
                  if (descriptor.version != null)
                    _ArtifactBadge(
                      label: 'v${descriptor.version}',
                      icon: Icons.sell_outlined,
                    ),
                ],
              ),
              if (descriptor.note != null) ...[
                const SizedBox(height: 8),
                Text(
                  descriptor.note!,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
              if (!selectionMode) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _CompactArtifactButton(
                        onPressed: onDownload,
                        icon: artifact.expired
                            ? Icons.history_toggle_off_rounded
                            : Icons.download_rounded,
                        label: artifact.expired ? 'Expirado' : 'Baixar',
                      ),
                    ),
                    if (onPublish != null) ...[
                      const SizedBox(width: 7),
                      Expanded(
                        child: _CompactArtifactButton(
                          onPressed: onPublish,
                          icon: Icons.rocket_launch_outlined,
                          label: 'Publicar',
                          primary: true,
                        ),
                      ),
                    ],
                    if (onDelete != null) ...[
                      const SizedBox(width: 7),
                      Expanded(
                        child: _CompactArtifactButton(
                          onPressed: onDelete,
                          icon: Icons.delete_outline_rounded,
                          label: 'Excluir',
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactArtifactButton extends StatelessWidget {
  const _CompactArtifactButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    this.primary = false,
  });

  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.fade,
            softWrap: false,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ),
      ],
    );
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, 38)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 7, vertical: 7),
      ),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
    return primary
        ? FilledButton(onPressed: onPressed, style: style, child: child)
        : OutlinedButton(onPressed: onPressed, style: style, child: child);
  }
}

class _ArtifactBadge extends StatelessWidget {
  const _ArtifactBadge({
    required this.label,
    required this.icon,
    this.emphasized = false,
    this.danger = false,
  });

  final String label;
  final IconData icon;
  final bool emphasized;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = danger
        ? scheme.errorContainer
        : emphasized
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest.withValues(alpha: .66);
    final foreground = danger
        ? scheme.onErrorContainer
        : emphasized
            ? scheme.onPrimaryContainer
            : scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: foreground),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _ArtifactDescriptor {
  const _ArtifactDescriptor({
    required this.format,
    required this.formatIcon,
    required this.buildType,
    required this.stability,
    required this.stabilityIcon,
    required this.isStable,
    required this.icon,
    this.version,
    this.note,
  });

  final String format;
  final IconData formatIcon;
  final String buildType;
  final String stability;
  final IconData stabilityIcon;
  final bool isStable;
  final IconData icon;
  final String? version;
  final String? note;

  factory _ArtifactDescriptor.fromArtifact(ActionArtifact artifact) {
    final lower = artifact.name.toLowerCase();
    final version = RegExp(r'(\d+\.\d+(?:\.\d+){0,3})')
        .firstMatch(artifact.name)
        ?.group(1);
    final isBundle = lower.contains('.aab') ||
        lower.contains('appbundle') ||
        lower.contains('bundle');
    final isDebug = lower.contains('debug');
    final isProfile = lower.contains('profile');
    final isPreview = lower.contains('beta') ||
        lower.contains('alpha') ||
        RegExp(r'(^|[-_.])rc\d*($|[-_.])').hasMatch(lower) ||
        lower.contains('prerelease') ||
        lower.contains('preview');
    final isApk = artifact.likelyContainsApk || lower.contains('.apk');

    String buildType;
    String stability;
    IconData stabilityIcon;
    bool stable;
    String? note;

    if (isDebug) {
      buildType = 'Debug';
      stability = 'Teste';
      stabilityIcon = Icons.bug_report_outlined;
      stable = false;
    } else if (isProfile) {
      buildType = 'Profile';
      stability = 'Teste';
      stabilityIcon = Icons.speed_outlined;
      stable = false;
    } else if (isPreview) {
      buildType = 'Release';
      stability = 'Prévia';
      stabilityIcon = Icons.science_outlined;
      stable = false;
    } else if (isApk || isBundle) {
      buildType = 'Release';
      stability = 'Estável provável';
      stabilityIcon = Icons.verified_outlined;
      stable = true;
      note = 'Classificação inferida pelo nome do artifact; o GitHub não informa o buildType diretamente.';
    } else {
      buildType = 'Artifact';
      stability = 'Auxiliar';
      stabilityIcon = Icons.inventory_2_outlined;
      stable = false;
    }

    return _ArtifactDescriptor(
      format: isBundle ? 'AAB / Play' : isApk ? 'APK' : 'ZIP',
      formatIcon: isBundle
          ? Icons.shop_outlined
          : isApk
              ? Icons.android_rounded
              : Icons.archive_outlined,
      buildType: buildType,
      stability: stability,
      stabilityIcon: stabilityIcon,
      isStable: stable,
      icon: isBundle
          ? Icons.shop_outlined
          : isApk
              ? Icons.android_rounded
              : Icons.inventory_2_outlined,
      version: version,
      note: note,
    );
  }
}
