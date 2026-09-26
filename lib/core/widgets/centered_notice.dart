import 'dart:async';

import 'package:flutter/material.dart';

enum CenteredNoticeKind { success, error, info }

/// Feedback global de ações.
///
/// O nome foi mantido para evitar quebrar chamadas existentes, mas o aviso não
/// é mais centralizado: usa um SnackBar flutuante e compacto, evitando cobrir o
/// conteúdo principal da tela.
void showCenteredNotice(
  BuildContext context,
  String message, {
  CenteredNoticeKind? kind,
  Duration? duration,
}) {
  if (!context.mounted || message.trim().isEmpty) return;

  final resolvedKind = kind ?? _inferKind(message);
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger != null) {
    final scheme = Theme.of(context).colorScheme;
    final visuals = _noticeVisuals(scheme, resolvedKind);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: duration ?? const Duration(milliseconds: 2200),
          margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          backgroundColor: visuals.background,
          elevation: 5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          content: Row(
            children: [
              Icon(visuals.icon, color: visuals.foreground, size: 21),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  message,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: visuals.foreground,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
        ),
      );
    return;
  }

  // Fallback para contextos muito específicos sem ScaffoldMessenger.
  _showBottomOverlay(context, message, resolvedKind, duration);
}

CenteredNoticeKind _inferKind(String message) {
  final normalized = message.toLowerCase();
  if (normalized.contains('erro') ||
      normalized.contains('falh') ||
      normalized.contains('não foi possível') ||
      normalized.contains('negad') ||
      normalized.contains('expir')) {
    return CenteredNoticeKind.error;
  }
  if (normalized.contains('exclu') ||
      normalized.contains('criad') ||
      normalized.contains('salv') ||
      normalized.contains('conclu') ||
      normalized.contains('iniciad') ||
      normalized.contains('copiad') ||
      normalized.contains('publicad') ||
      normalized.contains('adicionado')) {
    return CenteredNoticeKind.success;
  }
  return CenteredNoticeKind.info;
}

({IconData icon, Color background, Color foreground}) _noticeVisuals(
  ColorScheme scheme,
  CenteredNoticeKind kind,
) =>
    switch (kind) {
      CenteredNoticeKind.success => (
          icon: Icons.check_circle_rounded,
          background: scheme.primaryContainer,
          foreground: scheme.onPrimaryContainer,
        ),
      CenteredNoticeKind.error => (
          icon: Icons.error_rounded,
          background: scheme.errorContainer,
          foreground: scheme.onErrorContainer,
        ),
      CenteredNoticeKind.info => (
          icon: Icons.info_rounded,
          background: scheme.surfaceContainerHighest,
          foreground: scheme.onSurface,
        ),
    };

void _showBottomOverlay(
  BuildContext context,
  String message,
  CenteredNoticeKind kind,
  Duration? duration,
) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  final scheme = Theme.of(context).colorScheme;
  final visuals = _noticeVisuals(scheme, kind);
  late OverlayEntry entry;
  var removed = false;

  void remove() {
    if (removed) return;
    removed = true;
    entry.remove();
  }

  entry = OverlayEntry(
    builder: (overlayContext) => Positioned(
      left: 14,
      right: 14,
      bottom: MediaQuery.paddingOf(overlayContext).bottom + 18,
      child: IgnorePointer(
        child: Material(
          elevation: 5,
          color: visuals.background,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Icon(visuals.icon, color: visuals.foreground, size: 21),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    message,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(overlayContext).textTheme.bodyMedium?.copyWith(
                          color: visuals.foreground,
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
  );
  overlay.insert(entry);
  Timer(duration ?? const Duration(milliseconds: 2200), remove);
}
