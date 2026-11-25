import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Cores da sinalização viária: placa azul, faixa amarela e asfalto.
class AppColors {
  const AppColors._();

  static const plate = Color(0xFF1B3FCB);
  static const plateSoft = Color(0xFFE3E9FC);
  static const lane = Color(0xFFFFC629);
  static const laneSoft = Color(0xFFFFEDB8);
  static const asphalt = Color(0xFF16255F);
  static const ink = Color(0xFF131C3D);
  static const muted = Color(0xFF56607F);
  static const line = Color(0xFFCED5E6);
  static const paper = Color(0xFFF1F4FB);
  static const go = Color(0xFF08664A);
  static const goSoft = Color(0xFFD3F1E5);
  static const stop = Color(0xFFB3261E);
  static const stopSoft = Color(0xFFFCE0DD);
}

class AppTheme {
  const AppTheme._();

  static const _font = 'Overpass';

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(seedColor: AppColors.plate).copyWith(
      primary: AppColors.plate,
      onPrimary: Colors.white,
      primaryContainer: AppColors.plateSoft,
      onPrimaryContainer: AppColors.asphalt,
      secondary: AppColors.lane,
      onSecondary: AppColors.ink,
      secondaryContainer: AppColors.lane,
      onSecondaryContainer: AppColors.ink,
      surface: AppColors.paper,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.muted,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: Colors.white,
      surfaceContainerHigh: Colors.white,
      surfaceContainerHighest: const Color(0xFFDCE3F4),
      outline: const Color(0xFF8A94B2),
      outlineVariant: AppColors.line,
      error: AppColors.stop,
      errorContainer: AppColors.stopSoft,
      onErrorContainer: AppColors.stop,
    );

    final base = ThemeData(colorScheme: scheme, fontFamily: _font).textTheme;
    TextStyle? w(TextStyle? style, FontWeight weight, [double? size]) =>
        style?.copyWith(fontWeight: weight, fontSize: size, letterSpacing: 0);
    final text = base
        .copyWith(
          displaySmall: w(
            base.displaySmall,
            FontWeight.w800,
            38,
          )?.copyWith(height: 1.05, letterSpacing: -0.5),
          headlineMedium: w(
            base.headlineMedium,
            FontWeight.w800,
            28,
          )?.copyWith(height: 1.1),
          headlineSmall: w(base.headlineSmall, FontWeight.w800, 24),
          titleLarge: w(base.titleLarge, FontWeight.w800, 21),
          titleMedium: w(base.titleMedium, FontWeight.w700, 17),
          titleSmall: w(base.titleSmall, FontWeight.w700, 15),
          bodyLarge: w(base.bodyLarge, FontWeight.w400, 16),
          bodyMedium: w(base.bodyMedium, FontWeight.w400, 15),
          bodySmall: w(base.bodySmall, FontWeight.w400, 13.5),
          labelLarge: w(base.labelLarge, FontWeight.w700, 14.5),
          labelMedium: w(base.labelMedium, FontWeight.w600, 12.5),
        )
        .apply(bodyColor: AppColors.ink, displayColor: AppColors.ink);

    OutlineInputBorder field(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color, width: width),
        );
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );

    return ThemeData(
      colorScheme: scheme,
      fontFamily: _font,
      textTheme: text,
      scaffoldBackgroundColor: AppColors.paper,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.plate,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: text.titleLarge?.copyWith(color: Colors.white),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        hintStyle: text.bodyLarge?.copyWith(color: AppColors.muted),
        prefixIconColor: AppColors.muted,
        border: field(AppColors.line),
        enabledBorder: field(AppColors.line),
        focusedBorder: field(AppColors.plate, 2),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          textStyle: text.titleMedium,
          shape: buttonShape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          foregroundColor: AppColors.plate,
          side: const BorderSide(color: AppColors.plate, width: 1.5),
          textStyle: text.titleMedium,
          shape: buttonShape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(textStyle: text.labelLarge),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: AppColors.lane,
        showCheckmark: false,
        side: const BorderSide(color: AppColors.line),
        labelStyle: text.labelLarge?.copyWith(color: AppColors.ink),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: AppColors.lane,
          selectedForegroundColor: AppColors.ink,
          side: const BorderSide(color: AppColors.line),
          textStyle: text.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        elevation: 0,
        height: 70,
        indicatorColor: AppColors.lane,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.ink
                : AppColors.muted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.labelMedium?.copyWith(
            color: states.contains(WidgetState.selected)
                ? AppColors.ink
                : AppColors.muted,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        titleTextStyle: text.titleLarge,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.plate,
        titleTextStyle: text.titleSmall,
        subtitleTextStyle: text.bodySmall?.copyWith(color: AppColors.muted),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.line),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: text.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  /// Ação principal da tela, na cor da faixa.
  static ButtonStyle get laneButton => FilledButton.styleFrom(
    backgroundColor: AppColors.lane,
    foregroundColor: AppColors.ink,
  );
}
