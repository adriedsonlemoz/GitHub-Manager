import 'dart:async';

import 'package:flutter/material.dart';
import 'package:github_manager/core/persistence/local_database.dart';
import 'package:github_manager/core/telemetry/app_telemetry_service.dart';
import 'package:github_manager/core/widgets/installed_version_banner.dart';
import 'package:github_manager/features/update/presentation/update_whats_new_screen.dart';

class StartupUpdateGate extends StatefulWidget {
  const StartupUpdateGate({required this.child, super.key});

  final Widget child;

  @override
  State<StartupUpdateGate> createState() => _StartupUpdateGateState();
}

class _StartupUpdateGateState extends State<StartupUpdateGate> {
  static const _lastSeenVersionKey = 'app.whats_new.last_seen_version';

  String? _pendingVersion;
  bool _checking = false;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_checkForUpdate());
    });
  }

  Future<void> _checkForUpdate() async {
    if (_checking) return;
    _checking = true;
    try {
      final version = await InstalledVersionBanner.versionLabel.timeout(
        const Duration(seconds: 3),
      );
      if (version == 'versão não identificada') return;

      final lastSeen = await LocalDatabase.shared
          .readJson(_lastSeenVersionKey)
          .timeout(const Duration(seconds: 3));
      if (!mounted || lastSeen?.toString() == version) return;

      // A versão só é marcada como vista depois que a pessoa tocar em
      // Continuar. Assim, fechar o app durante a tela não "consome" as notas.
      setState(() => _pendingVersion = version);
    } catch (error, stackTrace) {
      unawaited(
        AppTelemetryService.instance.recordError(
          source: 'startup.whats_new_check',
          error: error,
          stackTrace: stackTrace,
        ),
      );
    } finally {
      _checking = false;
    }
  }

  Future<void> _markVersionAsSeen(String version) async {
    try {
      await LocalDatabase.shared
          .putJson(_lastSeenVersionKey, version)
          .timeout(const Duration(seconds: 2));
    } catch (error, stackTrace) {
      unawaited(
        AppTelemetryService.instance.recordError(
          source: 'startup.whats_new_persist',
          error: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<void> _continue() async {
    final version = _pendingVersion;
    if (!mounted || version == null || _closing) return;
    _closing = true;
    await _markVersionAsSeen(version);
    if (mounted) setState(() => _pendingVersion = null);
    _closing = false;
  }

  @override
  Widget build(BuildContext context) {
    final version = _pendingVersion;
    return Stack(
      children: [
        Positioned.fill(child: widget.child),
        if (version != null)
          Positioned.fill(
            child: BackButtonListener(
              onBackButtonPressed: () async {
                // Não marca a versão como lida apenas por pressionar Voltar.
                // A pessoa precisa confirmar em Continuar para que a tela seja
                // exibida somente uma vez de forma confiável.
                return true;
              },
              child: UpdateWhatsNewScreen(
                versionLabel: version,
                onContinue: _continue,
              ),
            ),
          ),
      ],
    );
  }
}
