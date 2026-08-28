part of 'repository_secrets_screen.dart';

class _SecretQuickAction extends StatelessWidget {
  const _SecretQuickAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, 40)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 4, vertical: 7),
      ),
      visualDensity: VisualDensity.compact,
      textStyle: WidgetStatePropertyAll(
        Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
      ),
    );

    return filled
        ? FilledButton.tonalIcon(
            onPressed: onPressed,
            style: style,
            icon: Icon(icon, size: 16),
            label: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
            ),
          )
        : OutlinedButton.icon(
            onPressed: onPressed,
            style: style,
            icon: Icon(icon, size: 16),
            label: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
            ),
          );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.plan});

  final SecretImportPlan plan;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            Text('${plan.createCount} criar'),
            Text('${plan.updateCount} substituir'),
            Text('${plan.existingCount} existentes'),
            Text('${plan.finalCount}/100 após salvar'),
          ],
        ),
      );
}
