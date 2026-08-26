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
    this.readOnly = false,
    super.key,
  });

  final GitHubRepository repository;
  final VoidCallback? onTap;
  final VoidCallback? onMenu;
  final VoidCallback? onOpenExternal;
  final VoidCallback? onCopyLink;
  final bool readOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final info = ref.watch(repositoryProjectInfoProvider(repository));
    final projectName = info.maybeWhen(
      data: (value) => value.projectName,
      orElse: () => repository.name,
    );
    final version = info.maybeWhen(
      data: (value) => value.version,
      orElse: () => null,
    );
    final technologies = info.maybeWhen(
      data: (value) => value.technologies,
      orElse: () => [if (repository.language != null) repository.language!],
    );

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
                    tooltip: 'Mais opções',
                    icon: const Icon(Icons.more_horiz_rounded),
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
              Row(
                children: [
                  TextButton.icon(
                    onPressed: onOpenExternal,
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('GitHub'),
                  ),
                  const SizedBox(width: 2),
                  TextButton.icon(
                    onPressed: onCopyLink,
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Copiar link'),
                  ),
                  const Spacer(),
                  Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
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
