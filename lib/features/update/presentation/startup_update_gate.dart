import 'dart:async';

import 'package:flutter/material.dart';
import 'package:github_manager/core/persistence/local_database.dart';
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

      setState(() => _pendingVersion = version);
      unawaited(_markVersionAsSeen(version));
    } catch (_) {
      // A tela de novidades é auxiliar e nunca pode bloquear o startup.
    } finally {
      _checking = false;
    }
  }

  Future<void> _markVersionAsSeen(String version) async {
    try {
      await LocalDatabase.shared
          .putJson(_lastSeenVersionKey, version)
          .timeout(const Duration(seconds: 2));
    } catch (_) {
      // Falha de persistência não bloqueia a tela nem o restante do aplicativo.
    }
  }

  Future<void> _continue() async {
    if (!mounted || _pendingVersion == null) return;
    setState(() => _pendingVersion = null);
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
                await _continue();
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
