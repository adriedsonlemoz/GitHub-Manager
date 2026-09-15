import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class InstalledVersionBanner extends StatelessWidget {
  const InstalledVersionBanner({super.key, this.compact = false});

  final bool compact;

  static final Future<String> _version = _loadVersion();

  static Future<String> get versionLabel => _version;

  static Future<String> _loadVersion() async {
    try {
      final raw = await rootBundle.loadString('github-manager.json');
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final version = decoded['version']?.toString().trim();
        final android = decoded['android'];
        final code = android is Map ? android['versionCode']?.toString().trim() : null;
        if (version?.isNotEmpty == true) {
          return code?.isNotEmpty == true ? '$version+$code' : version!;
        }
      }
    } catch (_) {
      // O banner continua útil mesmo sem metadados carregados.
    }
    return 'versão não identificada';
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
        future: _version,
        builder: (context, snapshot) {
          final label = snapshot.data ?? 'carregando';
          final scheme = Theme.of(context).colorScheme;
          return Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 10 : 14,
              vertical: compact ? 7 : 9,
            ),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(compact ? 10 : 12),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: .55),
              ),
            ),
            child: Text(
              'GITHUB MANAGER • $label',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: scheme.onSurface,
                fontWeight: FontWeight.w900,
                fontSize: compact ? 12 : 13,
                letterSpacing: 0.25,
              ),
            ),
          );
        },
      );
}
