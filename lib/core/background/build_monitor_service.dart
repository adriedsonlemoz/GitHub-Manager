import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:github_manager/core/network/github_api_client.dart';
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

  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    await Workmanager().initialize(buildMonitorCallbackDispatcher);
    await _initializeNotifications();
  }

  static Future<void> ensureDefaultEnabled() async {
    final database = LocalDatabase();
    try {
      final stored = await database.readJson(_enabledKey);
      if (stored == false) {
        await Workmanager().cancelByUniqueName(_buildMonitorUniqueName);
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
      } else {
        await database.putJson(_enabledKey, false);
        await Workmanager().cancelByUniqueName(_buildMonitorUniqueName);
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
      return true;
    } finally {
      await database.close();
    }
  }

  static Future<bool> requestPermission() async {
    await _initializeNotifications();
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final result = await android?.requestNotificationsPermission();
    return result ?? true;
  }

  static Future<void> _register() =>
      Workmanager().registerPeriodicTask(
        _buildMonitorUniqueName,
        _buildMonitorTask,
        tag: _buildMonitorTag,
        frequency: const Duration(minutes: 15),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
        constraints: Constraints(
          networkType: NetworkType.connected,
          requiresBatteryNotLow: true,
        ),
      );

  static Future<void> _initializeNotifications() async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_launcher'),
    );
    await _notifications.initialize(settings: settings);
  }

  static Future<bool> runBackgroundCheck() async {
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

      for (final repository in repositories.take(30)) {
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
  }) async {
    await _initializeNotifications();

    final (title, status) = switch (conclusion) {
      'success' => ('Build concluída ✓', 'concluída com sucesso'),
      'failure' => ('Build falhou', 'falhou'),
      'cancelled' => ('Build cancelada', 'foi cancelada'),
      'timed_out' => ('Build excedeu o tempo', 'excedeu o tempo limite'),
      _ => ('Build precisa de atenção', 'precisa de atenção'),
    };

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'github_build_status',
        'Status das builds',
        channelDescription:
            'Avisos quando uma execução do GitHub Actions termina.',
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.status,
      ),
    );

    final number = runNumber == null ? '' : ' #$runNumber';
    await _notifications.show(
      id: id & 0x7fffffff,
      title: title,
      body: '$repository • $workflowName$number $status.',
      notificationDetails: details,
      payload: repository,
    );
  }
}
