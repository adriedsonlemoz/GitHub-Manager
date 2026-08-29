import 'dart:async';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:github_manager/core/network/github_api_client.dart';
import 'package:github_manager/core/notifications/app_notification_service.dart';
import 'package:github_manager/core/persistence/local_database.dart';
import 'package:github_manager/core/security/secure_storage_service.dart';
import 'package:github_manager/features/repositories/data/repository_service.dart';
import 'package:workmanager/workmanager.dart';

const _buildMonitorTask = 'github_manager_build_monitor';
const _buildMonitorUniqueName = 'github_manager_build_monitor_periodic';
const _buildMonitorTag = 'github_manager_build_monitor_tag';
const _enabledKey = 'settings.build_notifications';
const _startedAtKey = 'notifications.build_monitor_started_at';
const _notifiedRunsKey = 'notifications.notified_run_ids';
const _watchedRepositoriesKey = 'notifications.watched_repositories';

@pragma('vm:entry-point')
void buildMonitorCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != _buildMonitorTask) {
      return true;
    }
    try {
      WidgetsFlutterBinding.ensureInitialized();
      DartPluginRegistrant.ensureInitialized();
      return await BuildMonitorService.runBackgroundCheck();
    } catch (_) {
      // Uma falha transitória não deve desativar o monitor.
      return true;
    }
  });
}

class BuildMonitorService {
  BuildMonitorService._();

  static Timer? _fastPollTimer;
  static bool _fastCheckRunning = false;

  static Future<void> initialize() async {
    await Workmanager().initialize(buildMonitorCallbackDispatcher);
    await AppNotificationService.initialize();
  }

  static Future<void> ensureDefaultEnabled() async {
    final database = LocalDatabase();
    try {
      final stored = await database.readJson(_enabledKey);
      if (stored == false) {
        await Workmanager().cancelByUniqueName(_buildMonitorUniqueName);
        _stopFastPolling();
        return;
      }

      if (stored == null) {
        await database.putJson(_enabledKey, true);
        await database.putJson(
          _startedAtKey,
          DateTime.now().millisecondsSinceEpoch,
        );
      }

      final allowed = await requestPermission();
      if (allowed) {
        await _register();
        _startFastPolling();
      } else {
        await database.putJson(_enabledKey, false);
        await Workmanager().cancelByUniqueName(_buildMonitorUniqueName);
        _stopFastPolling();
      }
    } finally {
      await database.close();
    }
  }

  static Future<bool> isEnabled() async {
    final database = LocalDatabase();
    try {
      return await database.readJson(_enabledKey) != false;
    } finally {
      await database.close();
    }
  }

  static Future<bool> setEnabled(bool enabled) async {
    final database = LocalDatabase();
    try {
      if (!enabled) {
        await database.putJson(_enabledKey, false);
        await Workmanager().cancelByUniqueName(_buildMonitorUniqueName);
        _stopFastPolling();
        return false;
      }

      final allowed = await requestPermission();
      if (!allowed) {
        await database.putJson(_enabledKey, false);
        return false;
      }

      await database.putJson(_enabledKey, true);
      await database.putJson(
        _startedAtKey,
        DateTime.now().millisecondsSinceEpoch,
      );
      await _register();
      _startFastPolling();
      return true;
    } finally {
      await database.close();
    }
  }

  static Future<bool> requestPermission() =>
      AppNotificationService.requestPermission();

  static Future<void> _register() =>
      Workmanager().registerPeriodicTask(
        _buildMonitorUniqueName,
        _buildMonitorTask,
        tag: _buildMonitorTag,
        frequency: const Duration(minutes: 15),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
      );

  static Future<void> watchRepository(String fullName) async {
    final value = fullName.trim();
    if (value.isEmpty) return;
    final database = LocalDatabase();
    try {
      final raw = await database.readJson(_watchedRepositoriesKey);
      final items = <String>[
        value,
        if (raw is List)
          ...raw.whereType<String>().where(
                (item) => item.toLowerCase() != value.toLowerCase(),
              ),
      ].take(12).toList(growable: false);
      await database.putJson(_watchedRepositoriesKey, items);
    } finally {
      await database.close();
    }
    if (await isEnabled()) {
      _startFastPolling();
      unawaited(_runFastCheck());
    }
  }

  static Future<bool> runBackgroundCheck({int maxRepositories = 30}) async {
    final database = LocalDatabase();
    try {
      if (await database.readJson(_enabledKey) == false) {
        return true;
      }

      final startedRaw = await database.readJson(_startedAtKey);
      final startedAt = startedRaw is int
          ? startedRaw
          : DateTime.now().millisecondsSinceEpoch;
      if (startedRaw is! int) {
        await database.putJson(_startedAtKey, startedAt);
      }

      final notifiedRaw = await database.readJson(_notifiedRunsKey);
      final notified = <int>{
        if (notifiedRaw is List)
          ...notifiedRaw
              .whereType<num>()
              .map((value) => value.toInt()),
      };

      final secureStorage = SecureStorageService();
      if (!await secureStorage.hasGitHubToken()) {
        return true;
      }

      final client = GitHubApiClient(secureStorage);
      final repositoryService = RepositoryService(client, database);
      final repositories = await repositoryService.listRepositories();
      final watchedRaw = await database.readJson(_watchedRepositoriesKey);
      final watched = watchedRaw is List
          ? watchedRaw.whereType<String>().map((item) => item.toLowerCase()).toList()
          : const <String>[];
      final byName = {
        for (final repository in repositories)
          repository.fullName.toLowerCase(): repository,
      };
      final ordered = [
        for (final name in watched)
          if (byName[name] != null) byName[name]!,
        ...repositories.where(
          (repository) => !watched.contains(repository.fullName.toLowerCase()),
        ),
      ];

      for (final repository in ordered.take(maxRepositories)) {
        try {
          final response = await client.get<Map<String, dynamic>>(
            '/repos/${repository.fullName}/actions/runs',
            queryParameters: const {
              'per_page': 10,
              'page': 1,
            },
          );
          final rawRuns = response.data?['workflow_runs'];
          if (rawRuns is! List) {
            continue;
          }

          for (final raw in rawRuns.whereType<Map>()) {
            final run = Map<String, dynamic>.from(raw);
            final id = (run['id'] as num?)?.toInt();
            if (id == null || notified.contains(id)) {
              continue;
            }

            final createdAt = DateTime.tryParse(
              run['created_at'] as String? ?? '',
            );
            if (createdAt == null ||
                createdAt.millisecondsSinceEpoch < startedAt) {
              continue;
            }

            if (run['status'] != 'completed') {
              continue;
            }

            final conclusion = run['conclusion'] as String? ?? '';
            if (!const {
              'success',
              'failure',
              'cancelled',
              'timed_out',
              'action_required',
            }.contains(conclusion)) {
              continue;
            }

            final workflowName =
                (run['name'] as String?)?.trim().isNotEmpty == true
                    ? run['name'] as String
                    : 'Build';
            final runNumber = (run['run_number'] as num?)?.toInt();
            await _showBuildNotification(
              id: id,
              repository: repository.fullName,
              workflowName: workflowName,
              runNumber: runNumber,
              conclusion: conclusion,
            );
            notified.add(id);
          }
        } catch (_) {
          // Um repositório sem Actions/permissão não bloqueia os demais.
        }
      }

      final recent = notified.toList(growable: false);
      final trimmed =
          recent.length <= 250 ? recent : recent.sublist(recent.length - 250);
      await database.putJson(_notifiedRunsKey, trimmed);
      return true;
    } finally {
      await database.close();
    }
  }

  static Future<void> _showBuildNotification({
    required int id,
    required String repository,
    required String workflowName,
    required int? runNumber,
    required String conclusion,
  }) =>
      AppNotificationService.showBuildResult(
        id: id,
        repository: repository,
        workflowName: workflowName,
        runNumber: runNumber,
        conclusion: conclusion,
      );

  static void _startFastPolling() {
    if (_fastPollTimer != null) return;
    unawaited(_runFastCheck());
    _fastPollTimer = Timer.periodic(
      const Duration(seconds: 35),
      (_) => unawaited(_runFastCheck()),
    );
  }

  static void _stopFastPolling() {
    _fastPollTimer?.cancel();
    _fastPollTimer = null;
  }

  static Future<void> _runFastCheck() async {
    if (_fastCheckRunning) return;
    _fastCheckRunning = true;
    try {
      if (await isEnabled()) {
        await runBackgroundCheck(maxRepositories: 10);
      }
    } catch (_) {
      // O monitor periódico continua sendo o fallback em segundo plano.
    } finally {
      _fastCheckRunning = false;
    }
  }
}
