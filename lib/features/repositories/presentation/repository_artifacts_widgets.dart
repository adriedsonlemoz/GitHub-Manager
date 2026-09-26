part of 'repository_artifacts_screen.dart';

class _ArtifactCard extends StatelessWidget {
  const _ArtifactCard({
    required this.artifact,
    required this.publishedRelease,
    required this.readOnly,
    required this.selectionMode,
    required this.selected,
    required this.onToggleSelection,
    required this.onDownload,
    required this.onPublish,
    required this.onDelete,
  });

  final ActionArtifact artifact;
  final ReleaseAsset? publishedRelease;
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
        borderRadius: BorderRadius.circular(4),
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
                        borderRadius: BorderRadius.circular(4),
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
                        if (descriptor.version != null)
                          Wrap(
                            spacing: 7,
                            runSpacing: 5,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'Versão',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              _ArtifactBadge(
                                label: descriptor.version!,
                                icon: Icons.sell_outlined,
                                emphasized: true,
                              ),
                            ],
                          )
                        else
                          Text(
                            artifact.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        const SizedBox(height: 5),
                        Text(
                          metadata.join(' • '),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  const _ArtifactBadge(
                    label: 'Artifact',
                    icon: Icons.inventory_2_outlined,
                    emphasized: true,
                  ),
                  _ArtifactBadge(
                    label: descriptor.format,
                    icon: descriptor.formatIcon,
                  ),
                  if (descriptor.variant != null)
                    _ArtifactBadge(
                      label: descriptor.variant!,
                      icon: Icons.memory_rounded,
                    ),
                  if (descriptor.status != null)
                    _ArtifactBadge(
                      label: descriptor.status!,
                      icon: descriptor.statusIcon,
                      danger: artifact.expired,
                    ),
                  if (publishedRelease != null)
                    const _ArtifactBadge(
                      label: 'Publicado',
                      icon: Icons.cloud_done_outlined,
                      emphasized: true,
                    ),
                ],
              ),
              if (!selectionMode) ...[
                const SizedBox(height: 11),
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
    required this.icon,
    required this.statusIcon,
    this.version,
    this.variant,
    this.status,
  });

  final String format;
  final IconData formatIcon;
  final IconData icon;
  final IconData statusIcon;
  final String? version;
  final String? variant;
  final String? status;

  factory _ArtifactDescriptor.fromArtifact(ActionArtifact artifact) {
    final lower = artifact.name.toLowerCase();
    final version = _RepositoryArtifactsScreenState._versionFromName(
      artifact.name,
    );
    final isBundle = lower.contains('.aab') ||
        lower.contains('appbundle') ||
        lower.contains('bundle');
    final isApk = artifact.likelyContainsApk || lower.contains('.apk');
    final isDebug = lower.contains('debug');
    final isProfile = lower.contains('profile');
    final isPreview = lower.contains('beta') ||
        lower.contains('alpha') ||
        RegExp(r'(^|[-_.])rc\d*($|[-_.])').hasMatch(lower) ||
        lower.contains('prerelease') ||
        lower.contains('preview');

    String? variant;
    if (lower.contains('universal') ||
        lower.contains('fat-apk') ||
        lower.contains('-all.')) {
      variant = 'Universal';
    } else if (lower.contains('arm64-v8a') ||
        lower.contains('arm64') ||
        lower.contains('aarch64')) {
      variant = 'ARM64';
    } else if (lower.contains('armeabi-v7a') ||
        lower.contains('armv7') ||
        lower.contains('v7a')) {
      variant = 'ARMv7';
    } else if (lower.contains('x86_64')) {
      variant = 'x86_64';
    } else if (RegExp(r'(^|[-_.])x86($|[-_.])').hasMatch(lower)) {
      variant = 'x86';
    } else if (lower.contains('performance')) {
      variant = 'Performance';
    }

    String? status;
    IconData statusIcon = Icons.info_outline_rounded;
    if (artifact.expired) {
      status = 'Expirado';
      statusIcon = Icons.history_toggle_off_rounded;
    } else if (isDebug) {
      status = 'Debug';
      statusIcon = Icons.bug_report_outlined;
    } else if (isProfile) {
      status = 'Profile';
      statusIcon = Icons.speed_outlined;
    } else if (isPreview) {
      status = 'Prévia';
      statusIcon = Icons.science_outlined;
    }

    return _ArtifactDescriptor(
      format: isBundle ? 'AAB / Play' : isApk ? 'APK' : 'ZIP',
      formatIcon: isBundle
          ? Icons.shop_outlined
          : isApk
              ? Icons.android_rounded
              : Icons.archive_outlined,
      icon: isBundle
          ? Icons.shop_outlined
          : isApk
              ? Icons.android_rounded
              : Icons.inventory_2_outlined,
      version: version,
      variant: variant,
      status: status,
      statusIcon: statusIcon,
    );
  }
}

class _ArtifactsOverview extends StatelessWidget {
  const _ArtifactsOverview({
    required this.releases,
    required this.artifacts,
    required this.filterLabel,
  });

  final int releases;
  final int artifacts;
  final String filterLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .55)),
      ),
      child: Row(
        children: [
          Icon(Icons.android_rounded, size: 18, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$releases Release(s) • $artifacts Artifact(s)',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            filterLabel,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _ArtifactsSectionHeader extends StatelessWidget {
  const _ArtifactsSectionHeader({
    required this.icon,
    required this.title,
    required this.count,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final int count;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(3, 4, 3, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 19, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$title ($count)',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReleaseAssetGroupCard extends StatelessWidget {
  const _ReleaseAssetGroupCard({
    required this.group,
    required this.onDownload,
    this.onManage,
  });

  final ReleaseAssetGroup group;
  final VoidCallback onDownload;
  final VoidCallback? onManage;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final preferred = group.preferredAsset;
    final fallbackTitle = group.releaseName.trim().isNotEmpty
        ? group.releaseName.trim()
        : preferred.name;
    final version = group.version?.trim();
    final metadata = <String>[
      if (group.hasMultipleAssets)
        '${group.assets.length} opções'
      else
        _RepositoryArtifactsScreenState._formatBytes(preferred.sizeBytes),
      _RepositoryArtifactsScreenState._formatDate(group.publishedAt),
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onDownload,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer.withValues(alpha: .72),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(
                      group.hasApk
                          ? Icons.android_rounded
                          : Icons.insert_drive_file_outlined,
                      color: scheme.onPrimaryContainer,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (version?.isNotEmpty == true)
                          Wrap(
                            spacing: 7,
                            runSpacing: 5,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'Versão',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              _ArtifactBadge(
                                label: version!,
                                icon: Icons.sell_outlined,
                                emphasized: true,
                              ),
                            ],
                          )
                        else
                          Text(
                            fallbackTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        const SizedBox(height: 5),
                        Text(
                          metadata.join(' • '),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  const _ArtifactBadge(
                    label: 'Release',
                    icon: Icons.new_releases_outlined,
                    emphasized: true,
                  ),
                  _ArtifactBadge(
                    label: group.hasApk ? 'APK' : 'Arquivo',
                    icon: group.hasApk
                        ? Icons.android_rounded
                        : Icons.insert_drive_file_outlined,
                  ),
                  if (group.hasMultipleAssets)
                    _ArtifactBadge(
                      label: '${group.assets.length} opções',
                      icon: Icons.layers_outlined,
                    ),
                ],
              ),
              const SizedBox(height: 11),
              Row(
                children: [
                  Expanded(
                    child: _CompactArtifactButton(
                      onPressed: onDownload,
                      icon: Icons.download_rounded,
                      label: group.hasMultipleAssets ? 'Escolher' : 'Baixar',
                      primary: true,
                    ),
                  ),
                  if (onManage != null) ...[
                    const SizedBox(width: 7),
                    Expanded(
                      child: _CompactArtifactButton(
                        onPressed: onManage,
                        icon: Icons.delete_outline_rounded,
                        label: 'Excluir',
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArtifactsInlineNotice extends StatelessWidget {
  const _ArtifactsInlineNotice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: scheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }
}

class _ArtifactsEmptyState extends StatelessWidget {
  const _ArtifactsEmptyState({required this.filtered});

  final bool filtered;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 70, 18, 24),
      child: Column(
        children: [
          Icon(
            filtered ? Icons.search_off_rounded : Icons.inventory_2_outlined,
            size: 42,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            filtered
                ? 'Nenhum arquivo corresponde à busca ou filtro.'
                : 'Nenhum APK, Release ou Artifact disponível neste repositório.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
