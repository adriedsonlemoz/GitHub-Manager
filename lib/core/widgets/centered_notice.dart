import 'dart:async';

import 'package:flutter/material.dart';

enum CenteredNoticeKind { success, error, info }

void showCenteredNotice(
  BuildContext context,
  String message, {
  CenteredNoticeKind? kind,
  Duration? duration,
}) {
  if (!context.mounted || message.trim().isEmpty) return;

  final normalized = message.toLowerCase();
  final resolvedKind = kind ??
      (normalized.contains('erro') ||
              normalized.contains('falh') ||
              normalized.contains('não foi possível') ||
              normalized.contains('negad') ||
              normalized.contains('expir')
          ? CenteredNoticeKind.error
          : normalized.contains('exclu') ||
                  normalized.contains('criad') ||
                  normalized.contains('salv') ||
                  normalized.contains('conclu') ||
                  normalized.contains('iniciad') ||
                  normalized.contains('copiad') ||
                  normalized.contains('publicad') ||
                  normalized.contains('adicionado')
              ? CenteredNoticeKind.success
              : CenteredNoticeKind.info);

  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  late OverlayEntry entry;
  var removed = false;

  void remove() {
    if (removed) return;
    removed = true;
    entry.remove();
  }

  final scheme = Theme.of(context).colorScheme;
  final (icon, background, foreground) = switch (resolvedKind) {
    CenteredNoticeKind.success => (
        Icons.check_circle_rounded,
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      ),
    CenteredNoticeKind.error => (
        Icons.error_rounded,
        scheme.errorContainer,
        scheme.onErrorContainer,
      ),
    CenteredNoticeKind.info => (
        Icons.info_rounded,
        scheme.surfaceContainerHighest,
        scheme.onSurface,
      ),
  };

  entry = OverlayEntry(
    builder: (overlayContext) => Positioned.fill(
      child: IgnorePointer(
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Material(
                elevation: 10,
                color: background,
                borderRadius: BorderRadius.circular(18),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 18,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, color: foreground, size: 28),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            message,
                            textAlign: TextAlign.center,
                            style: Theme.of(overlayContext)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(
                                  color: foreground,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  overlay.insert(entry);
  Timer(duration ?? const Duration(milliseconds: 2400), remove);
}
