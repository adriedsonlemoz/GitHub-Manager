import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const _seed = Color(0xFF5B5CF6);

  static ThemeData light() => _base(
        ColorScheme.fromSeed(
          seedColor: _seed,
          brightness: Brightness.light,
          surface: const Color(0xFFF9FAFC),
        ),
      );

  static ThemeData dark() => _base(
        const ColorScheme.dark(
          primary: Color(0xFF7069FF),
          onPrimary: Colors.white,
          primaryContainer: Color(0xFF262B78),
          onPrimaryContainer: Color(0xFFE7E7FF),
          secondary: Color(0xFF8D88FF),
          onSecondary: Colors.white,
          secondaryContainer: Color(0xFF202847),
          onSecondaryContainer: Color(0xFFE6E9F8),
          tertiary: Color(0xFF58DDA5),
          onTertiary: Color(0xFF072118),
          error: Color(0xFFFF6B78),
          onError: Colors.white,
          errorContainer: Color(0xFF4A1E28),
          onErrorContainer: Color(0xFFFFD9DD),
          surface: Color(0xFF08101C),
          onSurface: Color(0xFFF4F6FB),
          onSurfaceVariant: Color(0xFFA9B2C5),
          outline: Color(0xFF344158),
          outlineVariant: Color(0xFF253149),
          shadow: Colors.black,
          scrim: Colors.black,
          inverseSurface: Color(0xFFE8EBF2),
          onInverseSurface: Color(0xFF111827),
          inversePrimary: Color(0xFF4F46E5),
          surfaceTint: Colors.transparent,
        ),
      );

  static ThemeData _base(ColorScheme scheme) {
    final dark = scheme.brightness == Brightness.dark;
    final background = dark ? const Color(0xFF050B14) : const Color(0xFFF5F7FB);
    final panel = dark ? const Color(0xFF0B1422) : Colors.white;
    final field = dark ? const Color(0xFF0C1626) : const Color(0xFFF0F3F8);
    final border = dark ? const Color(0xFF27344B) : const Color(0xFFDDE3EC);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.45,
        ),
        iconTheme: IconThemeData(color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: panel,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: border),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: border.withValues(alpha: .8),
        space: 1,
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: field,
        contentPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 15),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: .78)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.primary, width: 1.35),
        ),
      ),
      searchBarTheme: SearchBarThemeData(
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: WidgetStatePropertyAll(field),
        side: WidgetStatePropertyAll(BorderSide(color: border)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 15),
        ),
        textStyle: WidgetStatePropertyAll(
          TextStyle(color: scheme.onSurface, fontSize: 16),
        ),
        hintStyle: WidgetStatePropertyAll(
          TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: .78)),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(19)),
        ),
      ),
      chipTheme: ChipThemeData(
        side: BorderSide(color: border),
        backgroundColor: field,
        selectedColor: dark ? const Color(0xFF3334C8) : scheme.primaryContainer,
        checkmarkColor: Colors.white,
        labelStyle: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w700),
        secondaryLabelStyle: TextStyle(color: dark ? Colors.white : scheme.onPrimaryContainer),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: scheme.onSurfaceVariant,
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: panel,
        indicatorColor: dark ? const Color(0xFF2C3070) : scheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
          );
        }),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: panel,
        selectedItemColor: scheme.primary,
        unselectedItemColor: scheme.onSurfaceVariant,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 0,
        backgroundColor: scheme.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark ? const Color(0xFF151F30) : const Color(0xFF202735),
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: dark ? const Color(0xFF111A2A) : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
          side: BorderSide(color: border),
        ),
      ),
    );
  }
}
