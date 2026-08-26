import 'package:flutter/material.dart';

class TechnologyBadge extends StatelessWidget {
  const TechnologyBadge({required this.name, super.key});

  final String name;

  @override
  Widget build(BuildContext context) {
    final normalized = name.trim().toLowerCase();
    final icon = switch (normalized) {
      'html' => Icons.language_rounded,
      'css' => Icons.palette_outlined,
      'javascript' || 'typescript' || 'dart' || 'java' => Icons.code_rounded,
      'kotlin' || 'android' => Icons.android_rounded,
      'flutter' => Icons.widgets_rounded,
      'shell' || 'bash' => Icons.terminal_rounded,
      'php' => Icons.web_rounded,
      'node.js' || 'node' => Icons.device_hub_rounded,
      'json' || 'xml' || 'yaml' => Icons.data_object_rounded,
      _ => Icons.code_rounded,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .7),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            name,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
