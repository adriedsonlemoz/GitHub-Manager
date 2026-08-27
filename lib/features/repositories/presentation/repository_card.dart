import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:github_manager/features/repositories/domain/github_repository.dart';
import 'package:github_manager/features/repositories/presentation/repository_providers.dart';

class RepositoryCard extends ConsumerWidget {
  const RepositoryCard({
    required this.repository,
    this.onTap,
    this.onMenu,
    this.onOpenExternal,
    this.onCopyLink,
    this.onFork,
    this.readOnly = false,
    super.key,
  });

  final GitHubRepository repository;
  final VoidCallback? onTap;
  final VoidCallback? onMenu;
  final VoidCallback? onOpenExternal;
  final VoidCallback? onCopyLink;
  final VoidCallback? onFork;
  final bool readOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final info = readOnly ? null : ref.watch(repositoryProjectInfoProvider(repository));
    final projectName = info?.maybeWhen(
          data: (value) => value.projectName,
          orElse: () => repository.name,
        ) ??
        repository.name;
    final version = info?.maybeWhen(
      data: (value) => value.version,
      orElse: () => null,
    );
    final technologies = info?.maybeWhen(
          data: (value) => value.technologies,
          orElse: () => [if (repository.language != null) repository.language!],
        ) ??
        [if (repository.language != null) repository.language!];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 12),
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
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      repository.isPrivate ? Icons.lock_outline_rounded : Icons.code_rounded,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                projectName,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -.2,
                                    ),
                              ),
                            ),
                            if (readOnly)
                              Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: scheme.secondaryContainer,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'Acompanhado',
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: scheme.onSecondaryContainer,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ),
                            if (repository.isArchived)
                              const Padding(
                                padding: EdgeInsets.only(left: 6),
                                child: Icon(Icons.archive_outlined, size: 17),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          repository.fullName,
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onMenu,
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Gerenciar repositório',
                    icon: const Icon(Icons.settings_outlined),
                  ),
                ],
              ),
              if (repository.description?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 10),
                Text(
                  repository.description!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  if (version?.isNotEmpty == true)
                    _InfoPill(icon: Icons.new_releases_outlined, text: 'v$version'),
                  _InfoPill(icon: Icons.account_tree_outlined, text: repository.defaultBranch),
                  ...technologies.take(4).map(
                        (technology) => _InfoPill(icon: Icons.memory_rounded, text: technology),
                      ),
                  _InfoPill(
                    icon: repository.isPrivate ? Icons.lock_outline_rounded : Icons.public_rounded,
                    text: repository.isPrivate ? 'Privado' : 'Público',
                  ),
                  _InfoPill(icon: Icons.schedule_rounded, text: _formatDate(repository.updatedAt)),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _RepositoryActionButton(
                    onPressed: onOpenExternal,
                    icon: Icons.open_in_new_rounded,
                    label: 'GitHub',
                  ),
                  _RepositoryActionButton(
                    onPressed: onCopyLink,
                    icon: Icons.copy_rounded,
                    label: 'Copiar link',
                  ),
                  if (readOnly && onFork != null)
                    _RepositoryActionButton(
                      onPressed: onFork,
                      icon: Icons.call_split_rounded,
                      label: 'Fork',
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime? value) {
    if (value == null) {
      return '-';
    }
    final date = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)} ${two(date.hour)}:${two(date.minute)}';
  }
}

class _RepositoryActionButton extends StatelessWidget {
  const _RepositoryActionButton({
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  final VoidCallback? onPressed;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        ),
        icon: Icon(icon, size: 17),
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: .65),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              text,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      );
}
