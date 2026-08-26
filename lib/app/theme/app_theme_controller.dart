import 'package:flutter/material.dart';
import 'package:github_manager/core/security/secure_storage_service.dart';

class AppThemeController extends ValueNotifier<ThemeMode> {
  AppThemeController._() : super(ThemeMode.system);

  static final AppThemeController instance = AppThemeController._();

  final SecureStorageService _storage = SecureStorageService();

  Future<void> initialize() async {
    final saved = await _storage.readThemeMode();
    value = switch (saved) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setMode(ThemeMode mode) async {
    value = mode;
    await _storage.writeThemeMode(mode.name);
  }
}
